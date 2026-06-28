-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.7
-- Purpose: Mixes factions in endless
-- =================================================================================================

local MOD_NAME = "Alliances"

local is_crypt_boss_floor = false

-- Weighted list of alliance units (1 is normal spawns, 5 is the hard falloff for rare spawns, past 5-6 is very very rare.)
local alliance_units = {
    {name = "mummy_bloated", weight = 3},
    {name = "mummy_risen", weight = 1},
    {name = "mummy_giant", weight = 2},
    {name = "mummy_priest", weight = 2},
    {name = "skeleton_soldier", weight = 1},
    {name = "skeleton_defender", weight = 2},
    {name = "skeleton_warrior", weight = 3},
    {name = "skeleton_commander", weight = 3},
    {name = "necromancer", weight = 4},
    {name = "lich", weight = 6},
    {name = "ghost", weight = 2},
    -- ====================================
    {name = "lake_dweller", weight = 1},
    {name = "grunt_scavenger", weight = 1},
    {name = "grunt_shaman", weight = 3},
    {name = "orc_melee", weight = 2},
    {name = "orc_juggernaut", weight = 3},
    {name = "spider_hatchling", weight = 1},
    {name = "spider_warrior", weight = 3},
    {name = "spider_queen", weight = 6},
    -- ====================================
    {name = "cultist_novice", weight = 1},
    {name = "cultist_zealot", weight = 2},
    {name = "cultist_sorcerer", weight = 3},
    {name = "demon_melee", weight = 1},
    {name = "demon_ranged", weight = 4},
    {name = "cultist_armor", weight = 5},
    {name = "demon_heavy", weight = 6},
    -- ====================================
    {name = "portal_crypt", weight = 7}, -- Please for the love of god don't lower this weight below 5 :D
    {name = "boss_morak_sword", weight = 7},
    {name = "boss_mummy", weight = 5},
    {name = "boss_orox", weight = 7},
}

local should_replace_units = {
    "mummy_bloated",
    "mummy_risen",
    "mummy_giant",
    "mummy_priest",
    "skeleton_soldier",
    "skeleton_defender",
    "skeleton_warrior",
    "skeleton_commander",
    "necromancer",
    "lich",
    "ghost",
    -- Env
    "lake_dweller",
    "grunt_scavenger",
    "grunt_scavenger_buffed",
    "grunt_shaman",
    "orc_melee",
    "orc_juggernaut",
    "spider_hatchling",
    "spider_warrior",
    "spider_queen",
    -- Env
    "cultist_novice",
    "cultist_zealot",
    "cultist_sorcerer",
    "demon_melee",
    "demon_ranged",
    "cultist_armor",
    "cultist_armor_corpse",
    "demon_heavy",
}

local DESPAWN_UNITS = {
    "boss_morak_sword",
    "boss_mummy",
}
local UNIT_LIFETIME = 25
local function schedule_despawn(unit, unit_path)
    Game.scheduler:delay_action(UNIT_LIFETIME, function ()
        if EntityAux.owned(unit) then
            local despawner = FlowCallbacks.state_game.despawner
            if despawner then
                despawner:force_despawn(unit)
            end
        end
    end)
end

local orox_spawned = false
local alliances_modify_unit_path = function(original_path)
    if not original_path then
        return original_path
    end

    local should_replace = false
    for _, unit_data in ipairs(should_replace_units) do
        if string.find(original_path, unit_data) then
            should_replace = true
            break
        end
    end

    if not should_replace then
        return original_path
    end

    -- Determine if we're on the crypt boss floor (use lobby flag if set, otherwise check runtime)
    local boss_floor = is_crypt_boss_floor or (FlowCallbacks.state_game and FlowCallbacks.state_game.floor == "crypt_floor_10")

    -- If the original is already the boss and we're on boss floor, preserve it
    if boss_floor and string.find(original_path, "boss_mummy") then
        return original_path
    end

    local weighted_pool = {}
    for _, unit_data in ipairs(alliance_units) do
        -- Exclude boss_mummy from replacements when on the boss floor
        if not (boss_floor and unit_data.name == "boss_mummy") then
            local entries = math.max(1, math.floor(250 / (unit_data.weight * unit_data.weight)))
            for i = 1, entries do
                table.insert(weighted_pool, unit_data.name)
            end
        end
    end

    if #weighted_pool == 0 then
        return original_path
    end

    local random_choice = weighted_pool[math.random(1, #weighted_pool)]

    if random_choice == "boss_orox" then
        if orox_spawned then
            random_choice = "portal_crypt"
        end
        orox_spawned = true
    else
        -- Nothing
    end
    return random_choice
end

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)
    
    if path == "lua/menu/lobby_logic" then
        Mods.hook:set(MOD_NAME, "LobbyLogic.from_server_lobby_start_countdown", function (orig, self, server_peer_id, countdown_time, floor_id)
            orig(self, server_peer_id, countdown_time, floor_id)
            if floor_id == "crypt_floor_10" then
                is_crypt_boss_floor = true
            else
                is_crypt_boss_floor = false
            end
        end)
    end

    if path == "foundation/lua/entity/entity_spawner" then
        Mods.hook:set(MOD_NAME, "EntitySpawner.spawn_entity", function (orig, self, unit_path, position, rotation, parent_go_id, setup_info)
            local modified_path = alliances_modify_unit_path(unit_path)

            -- Let original implementation do everything it needs (this preserves spawn_info)
            local unit, go_id = orig(self, modified_path, position, rotation, parent_go_id, setup_info)

            -- Optional: schedule despawn if needed
            for _, despawn_name in ipairs(DESPAWN_UNITS) do
                if string.find(modified_path, despawn_name) then
                    schedule_despawn(unit, modified_path)
                    break
                end
            end

            return unit, go_id
        end)
    end

    if path == "lua/managers/entity_culling_manager" then
        Mods.hook:set(MOD_NAME, "EntityCullingManager.cull_unit", function(orig, self, unit)
            if not self.not_culled_units[unit] then 
                -- Stops crashes when unregistered units that do not have data to cull when offscreen.
                return
            end
            orig(self, unit)
        end)
    end

    if path == "lua/managers/endless_server" then
        Mods.hook:set(MOD_NAME, "EndlessServer.get_floor", function(orig, floor_index)
            orox_spawned = false

            return orig(floor_index)
        end)
    end

    return result
end)
