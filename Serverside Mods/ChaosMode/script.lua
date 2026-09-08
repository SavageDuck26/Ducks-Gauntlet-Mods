
local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "4.2.0"
local MOD_DESCRIPTION = "Chaos and Hell modes, configurable difficulty modes"


local MOD_NAME, log_message = Mods.init_mod()
ChaosMode = ChaosMode or {}
ChaosMode.loaded = true

-- Saveable settings
ChaosMode.CONFIG = ChaosMode.CONFIG or {
    mode = "chaos",
    prevent_backtrack_spawns = true,
    knossos_proximity_cull = true,
}

ChaosMode.chaos_multiplier = ChaosMode.chaos_multiplier or 5000
ChaosMode.hell_multiplier_1 = ChaosMode.hell_multiplier_1 or 15000
ChaosMode.hell_multiplier_2 = ChaosMode.hell_multiplier_2 or 15000
ChaosMode.limbo_multiplier = ChaosMode.limbo_multiplier or 25000

-- single global credit multiplier per mode controls spawn budget; exact
-- ratios are preserved by using the constant value instead of the base
-- table entries.

ChaosMode.prevent_backtrack_spawns = ChaosMode.CONFIG.prevent_backtrack_spawns
ChaosMode.disable_entity_culling = ChaosMode.disable_entity_culling == nil and true or ChaosMode.disable_entity_culling

-- filters bypass settings: limbo gets base value, each step down reduces by step
ChaosMode.filter_bypass_base = ChaosMode.filter_bypass_base or 0.80          -- limbo default
ChaosMode.filter_bypass_step = ChaosMode.filter_bypass_step or 0.30       -- decrement per mode below limbo
-- global reduction applied to every mode (e.g. 0.5 halves the probabilities)
ChaosMode.filter_bypass_global = ChaosMode.filter_bypass_global or 0.20

ChaosMode.completed_encounters = ChaosMode.completed_encounters or {}
ChaosMode.player_furthest_y = ChaosMode.player_furthest_y or false

ChaosMode.mode_names = ChaosMode.mode_names or {
    normal = "Normal",
    chaos = "ChaosMode",
    hell = "Welcome To Hell",
    limbo = "Limbo"
}

_G.endlessshop_config = _G.endlessshop_config or {}
_G.endlessshop_config.dead_broke = _G.endlessshop_config.dead_broke or false

local original_encounter_settings = nil

-- =================================================================================================
-- Knossos proximity culling: only allow spawning in nodes connected to player
-- =================================================================================================
local cached_allowed_nodes = nil
local cached_player_nodes = {}

local function rebuild_allowed_spawn_nodes()
    if not DungeonManager or not DungeonManager.targets then
        return nil
    end

    local allowed = {}
    local MAX_HOPS = 1 -- player node -> corridor -> adjacent room

    for unit, info in pairs(DungeonManager.targets) do
        if info and info.node then
            -- BFS from player node up to MAX_HOPS
            local queue = { { node = info.node, depth = 0 } }
            local visited = { [info.node] = true }
            local head = 1

            while head <= #queue do
                local current = queue[head]
                head = head + 1
                allowed[current.node] = true

                if current.depth < MAX_HOPS and current.node.neighbors then
                    for _, neighbor_info in ipairs(current.node.neighbors) do
                        if neighbor_info.node and not visited[neighbor_info.node] then
                            visited[neighbor_info.node] = true
                            queue[#queue + 1] = { node = neighbor_info.node, depth = current.depth + 1 }
                        end
                    end
                end
            end
        end
    end

    if not next(allowed) then
        return nil
    end

    return allowed
end

local function get_allowed_spawn_nodes()
    if not DungeonManager or not DungeonManager.targets then
        return nil
    end

    -- Check if any player changed node since last rebuild
    local changed = false

    for unit, info in pairs(DungeonManager.targets) do
        if info and info.node then
            if cached_player_nodes[unit] ~= info.node then
                changed = true
                break
            end
        end
    end

    if not changed and cached_allowed_nodes then
        -- Also check for removed players
        for unit, _ in pairs(cached_player_nodes) do
            if not DungeonManager.targets[unit] then
                changed = true
                break
            end
        end
    end

    if not changed and cached_allowed_nodes then
        return cached_allowed_nodes
    end

    -- Rebuild player node snapshot
    cached_player_nodes = {}
    for unit, info in pairs(DungeonManager.targets) do
        if info and info.node then
            cached_player_nodes[unit] = info.node
        end
    end

    cached_allowed_nodes = rebuild_allowed_spawn_nodes()
    return cached_allowed_nodes
end

local function is_node_near_players(node)
    if not ChaosMode.CONFIG.knossos_proximity_cull then
        return true
    end
    if not node then
        return true
    end
    -- Only cull when Knossos branching is active
    if not Knossos or not Knossos.CONFIG or not Knossos.CONFIG.enabled then
        return true
    end

    local allowed = get_allowed_spawn_nodes()
    if not allowed then
        return true
    end

    return allowed[node] == true
end

local function is_backtrack_spawn_position(position)
    if not ChaosMode.CONFIG.prevent_backtrack_spawns then
        return false
    end
    
    if not PartyManager or not PartyManager.get_team_position then
        return false
    end
    
    local team_pos = PartyManager:get_team_position()
    if not team_pos then
        return false
    end
    
    local current_furthest_y = ChaosMode.player_furthest_y
    if not current_furthest_y or current_furthest_y == false or team_pos.y > current_furthest_y then
        ChaosMode.player_furthest_y = team_pos.y
        current_furthest_y = team_pos.y
    end
    
    local backtrack_threshold = 15
    if current_furthest_y and current_furthest_y ~= false and position.y < (current_furthest_y - backtrack_threshold) then
        return true
    end
    
    local completed_encounters = ChaosMode.completed_encounters or {}
    if DungeonManager and DungeonManager.nodes then
        local spawn_node = DungeonManager:get_node_at(position, false)
        if spawn_node then
            for completed_node, _ in pairs(completed_encounters) do
                if completed_node and completed_node.world_bounds then
                    local completed_center_y = completed_node.world_bounds.cy
                    if position.y < completed_center_y - 5 then
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

local function bypass_chance()
    if not ChaosMode or ChaosMode.CONFIG.mode == "normal" then
        return 0
    end
    local order = { normal=0, chaos=1, hell=2, limbo=3 }
    local rank = order[ChaosMode.CONFIG.mode] or 0
    -- value for limbo (rank 3) is base, each step down subtracts step
    local chance = ChaosMode.filter_bypass_base - (3 - rank) * ChaosMode.filter_bypass_step
    chance = chance * (ChaosMode.filter_bypass_global or 1)
    return math.max(0, chance)
end

Mods.hook:set_object(_G, "require", function(orig, path, ...)
    if path == "lua/settings/encounter_settings" then
        local result = orig(path, ...)
        
        if not original_encounter_settings and result then
            original_encounter_settings = {}
            for k, v in pairs(result) do
                if type(v) == "table" then
                    original_encounter_settings[k] = {}
                    for i, val in pairs(v) do
                        if type(val) == "table" then
                            original_encounter_settings[k][i] = {}
                            for j, subval in pairs(val) do
                                original_encounter_settings[k][i][j] = subval
                            end
                        else
                            original_encounter_settings[k][i] = val
                        end
                    end
                else
                    original_encounter_settings[k] = v
                end
            end
        end
        
        if not ChaosMode or ChaosMode.CONFIG.mode == "normal" then
            return original_encounter_settings
        end

        -- any non‑normal mode is handled by spawning hooks; we don't touch
        -- the credit tables here.
        
        -- credits multipliers are applied in the ProceduralSpawningManager hooks
        -- below; altering the tables directly caused the ratios to vanish.
        -- (the old code replaced every entry with a flat number.)

        if result[4] then
            for env_name, env in pairs(result[4]) do
                for _, group_list in pairs(env.floor_type_to_groups) do
                    for _, group in ipairs(group_list) do
                        if group.enemy_infos then
                            for _, enemy_info in ipairs(group.enemy_infos) do
                                if enemy_info.unit_path == "spawner_ghost" and enemy_info.max then
                                    for k in pairs(enemy_info.max) do
                                        enemy_info.max[k] = 1 -- Set max for spawner_ghost to 1 in all groups
                                    end
                                end
                            end
                        end
                        
                        if group.is_spawner and not group.can_spawn_in_corridors then
                            local allow = true
                            if env_name == "d01_caves" then
                                if group.enemy_infos then
                                    for _, enemy_info in ipairs(group.enemy_infos) do
                                        if enemy_info.unit_path and string.find(enemy_info.unit_path, "_t1") then
                                            allow = false -- Exclude tier 1 spawners in caves
                                            break
                                        end
                                    end
                                end
                            end
                            if allow then
                                group.can_spawn_in_corridors = true -- Actual Chaos
                            end
                        end
                    end
                end
            end
        end
        
        return result
    end
    
    local result = orig(path, ...)
    -- =================================================================================================
    if path == "lua/managers/encounter_manager" then
        Mods.hook:set_object_path("EncounterManager", "stop_encounter", function(orig, self, node, ...)
            if node then
                local completed = ChaosMode.completed_encounters
                if completed then
                    completed[node] = true
                end
            end
            
            return orig(self, node, ...)
        end, MOD_NAME .. ".EncounterManager.stop_encounter", MOD_NAME)
    end
    -- =================================================================================================
    if path == "lua/managers/procedural_spawning_manager" then
        
        Mods.hook:set_object_path("ProceduralSpawningManager", "clear", function(orig, self, ...)
            ChaosMode.completed_encounters = {}
            ChaosMode.player_furthest_y = false
            cached_allowed_nodes = nil
            cached_player_nodes = {}
            
            return orig(self, ...)
        end, MOD_NAME .. ".ProceduralSpawningManager.clear", MOD_NAME)

        Mods.hook:set_object_path("ProceduralSpawningManager", "create_spawn_points", function(orig, self, node, create_for_encounters, spawn_death, ...)
            if not create_for_encounters and not spawn_death then
                if ChaosMode and ChaosMode.CONFIG.mode ~= "normal" then
                    -- Knossos proximity culling
                    if not is_node_near_players(node) then
                        return
                    end
                    
                    -- Backtrack prevention
                    if ChaosMode.CONFIG.prevent_backtrack_spawns then
                        if node and node.world_bounds then
                            local node_center = Vector3(node.world_bounds.cx, node.world_bounds.cy, 0)
                            
                            if is_backtrack_spawn_position(node_center) then
                                return
                            end
                        end
                    end
                end
            end
            
            return orig(self, node, create_for_encounters, spawn_death, ...)
        end, MOD_NAME .. ".ProceduralSpawningManager.create_spawn_points", MOD_NAME)

        Mods.hook:set_object_path("ProceduralSpawningManager", "spawn_at_point", function(orig, self, spawn_point, setup_info, ...)
            if ChaosMode and ChaosMode.CONFIG.mode ~= "normal" then
                if spawn_point and spawn_point.position then
                    local position = Vector3Aux.unbox(spawn_point.position)
                    
                    -- Knossos proximity culling
                    if ChaosMode.CONFIG.knossos_proximity_cull then
                        local spawn_node = DungeonManager:get_node_at(position, false)
                        if spawn_node and not is_node_near_players(spawn_node) then
                            return
                        end
                    end
                    
                    -- Backtrack prevention
                    if ChaosMode.CONFIG.prevent_backtrack_spawns then
                        if is_backtrack_spawn_position(position) then
                            return
                        end
                    end
                end
            end
            
            return orig(self, spawn_point, setup_info, ...)
        end, MOD_NAME .. ".ProceduralSpawningManager.spawn_at_point", MOD_NAME)

        Mods.hook:set_object_path("ProceduralSpawningManager", "get_encounter_credits", function(orig, self, ...)
            local credits = orig(self, ...)
            if ChaosMode and ChaosMode.CONFIG.mode ~= "normal" then
                -- ignore the original budget and give every encounter the flat
                -- chaos/hell/limbo multiplier. this replicates the pre‑ratio fix
                -- behaviour while still letting the group selection use the same
                -- relative weights.
                local mode = ChaosMode.CONFIG.mode
                local mult = 1
                if mode == "chaos" then
                    mult = ChaosMode.chaos_multiplier or 5000
                elseif mode == "hell" then
                    mult = ChaosMode.hell_multiplier_1 or 15000
                elseif mode == "limbo" then
                    mult = ChaosMode.limbo_multiplier or 25000
                end
                credits = mult
            end
            return credits
        end, MOD_NAME .. ".ProceduralSpawningManager.get_encounter_credits", MOD_NAME)

        Mods.hook:set_object_path("ProceduralSpawningManager", "get_corridor_credits", function(orig, self, ...)
            local credits = orig(self, ...)
            if ChaosMode and ChaosMode.CONFIG.mode ~= "normal" then
                local mode = ChaosMode.CONFIG.mode
                local mult = 1
                if mode == "chaos" then
                    mult = ChaosMode.chaos_multiplier or 5000
                elseif mode == "hell" then
                    mult = ChaosMode.hell_multiplier_2 or 15000
                elseif mode == "limbo" then
                    mult = ChaosMode.limbo_multiplier or 25000
                end
                credits = mult
            end
            return credits
        end, MOD_NAME .. ".ProceduralSpawningManager.get_corridor_credits", MOD_NAME)

        -- disable stand/frustum checks probabilistically according to above
        Mods.hook:set_object_path("QueryManager", "can_stand_here", function(orig, self, position, radius, ...)
            if math.random() <= bypass_chance() then
                return true
            end
            return orig(self, position, radius, ...)
        end, MOD_NAME .. ".QueryManager.can_stand_here", MOD_NAME)
        Mods.hook:set_object_path("CameraManager", "is_position_inside_frustum", function(orig, self, position, ...)
            if math.random() <= bypass_chance() then
                return false, 10
            end
            return orig(self, position, ...)
        end, MOD_NAME .. ".CameraManager.is_position_inside_frustum", MOD_NAME)
    end
    
    return result
end, MOD_NAME .. ".require", MOD_NAME)
