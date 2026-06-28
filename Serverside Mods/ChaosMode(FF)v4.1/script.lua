-- =================================================================================================
-- Author: SavageDuck26
-- Version: 4.1
-- Purpose: Chaos & Hell modes - configurable difficulty modes
-- =================================================================================================

local MOD_NAME = "ChaosMode"

ChaosMode = ChaosMode or {}
ChaosMode.loaded = true

-- Saveable settings
ChaosMode.CONFIG = ChaosMode.CONFIG or {
    mode = "chaos",
    prevent_backtrack_spawns = true,
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
ChaosMode.filter_bypass_base = ChaosMode.filter_bypass_base or 1          -- limbo default
ChaosMode.filter_bypass_step = ChaosMode.filter_bypass_step or 0.40       -- decrement per mode below limbo
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

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
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
        Mods.hook:set(MOD_NAME, "EncounterManager.stop_encounter", function(orig, self, node, ...)
            if node then
                local completed = ChaosMode.completed_encounters
                if completed then
                    completed[node] = true
                end
            end
            
            return orig(self, node, ...)
        end)
    end
    -- =================================================================================================
    if path == "lua/managers/procedural_spawning_manager" then
        
        Mods.hook:set(MOD_NAME, "ProceduralSpawningManager.clear", function(orig, self, ...)
            ChaosMode.completed_encounters = {}
            ChaosMode.player_furthest_y = false
            
            return orig(self, ...)
        end)

        Mods.hook:set(MOD_NAME, "ProceduralSpawningManager.create_spawn_points", function(orig, self, node, create_for_encounters, spawn_death, ...)
            if not create_for_encounters and not spawn_death then
                if ChaosMode and ChaosMode.CONFIG.prevent_backtrack_spawns and ChaosMode.CONFIG.mode ~= "normal" then
                    if node and node.world_bounds then
                        local node_center = Vector3(node.world_bounds.cx, node.world_bounds.cy, 0)
                        
                        if is_backtrack_spawn_position(node_center) then
                            return
                        end
                    end
                end
            end
            
            return orig(self, node, create_for_encounters, spawn_death, ...)
        end)

        Mods.hook:set(MOD_NAME, "ProceduralSpawningManager.spawn_at_point", function(orig, self, spawn_point, setup_info, ...)
            if ChaosMode and ChaosMode.CONFIG.prevent_backtrack_spawns and ChaosMode.CONFIG.mode ~= "normal" then
                if spawn_point and spawn_point.position then
                    local position = Vector3Aux.unbox(spawn_point.position)
                    
                    if is_backtrack_spawn_position(position) then
                        return
                    end
                end
            end
            
            return orig(self, spawn_point, setup_info, ...)
        end)

        Mods.hook:set(MOD_NAME, "ProceduralSpawningManager.get_encounter_credits", function(orig, self, ...)
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
        end)

        Mods.hook:set(MOD_NAME, "ProceduralSpawningManager.get_corridor_credits", function(orig, self, ...)
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
        end)

        -- disable stand/frustum checks probabilistically according to above
        Mods.hook:set(MOD_NAME, "QueryManager.can_stand_here", function(orig, self, position, radius, ...)
            if math.random() <= bypass_chance() then
                return true
            end
            return orig(self, position, radius, ...)
        end)
        Mods.hook:set(MOD_NAME, "CameraManager.is_position_inside_frustum", function(orig, self, position, ...)
            if math.random() <= bypass_chance() then
                return false, 10
            end
            return orig(self, position, ...)
        end)
    end
    
    return result
end)
