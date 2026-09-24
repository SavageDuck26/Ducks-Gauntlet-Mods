
local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "1.8.0"
local MOD_DESCRIPTION = "Mixes all factions in Endless"

local MOD_NAME, log_message = Mods.init_mod(nil, "mods/Alliances/Alliances.lua")
local is_crypt_boss_floor = false

Alliances = Alliances or {}
Alliances.loaded = true

-- Weighted list of alliance units (1 is normal spawns, 5 is the hard falloff for rare spawns, past 5-6 is very very rare.)
-- Shared with script_AlliancesUI.lua and the source of the config defaults. The ids are the save
-- keys in mod_settings.json, so do not rename existing ones.
Alliances.unit_list = {
    {id = "mummy_bloated", weight = 3},
    {id = "mummy_risen", weight = 1},
    {id = "mummy_giant", weight = 2},
    {id = "mummy_priest", weight = 2},
    {id = "skeleton_soldier", weight = 1},
    {id = "skeleton_defender", weight = 2},
    {id = "skeleton_warrior", weight = 3},
    {id = "skeleton_commander", weight = 3},
    {id = "necromancer", weight = 4},
    {id = "lich", weight = 6},
    {id = "ghost", weight = 3},
    -- ====================================
    {id = "lake_dweller", weight = 1},
    {id = "grunt_scavenger", weight = 1},
    {id = "grunt_shaman", weight = 3},
    {id = "orc_melee", weight = 2},
    {id = "orc_juggernaut", weight = 3},
    {id = "spider_hatchling", weight = 1},
    {id = "spider_warrior", weight = 3},
    {id = "spider_queen", weight = 6},
    -- ====================================
    {id = "cultist_novice", weight = 1},
    {id = "cultist_zealot", weight = 2},
    {id = "cultist_sorcerer", weight = 3},
    {id = "demon_melee", weight = 1},
    {id = "demon_ranged", weight = 4},
    {id = "cultist_armor", weight = 5},
    {id = "demon_heavy", weight = 6},
    -- ====================================
    {id = "portal_crypt", weight = 7}, -- Please for the love of god don't lower this weight below 5 :D
    {id = "boss_morak_sword", weight = 7},
    {id = "boss_mummy", weight = 5},
    {id = "boss_orox", weight = 7},
}

-- "mummy_bloated" -> "Mummy Bloated", so the config UI has something readable to show.
for _, unit in ipairs(Alliances.unit_list) do
    unit.label = (unit.id:gsub("_", " "):gsub("(%a)([%w]*)", function(first, rest) return first:upper() .. rest end))
end

-- Saveable settings (defaults are the values this mod shipped with).
Alliances.CONFIG = Alliances.CONFIG or {}
Alliances.CONFIG.enabled = Alliances.CONFIG.enabled ~= false
Alliances.CONFIG.unit_enabled = Alliances.CONFIG.unit_enabled or {}
Alliances.CONFIG.unit_weights = Alliances.CONFIG.unit_weights or {}

for _, unit in ipairs(Alliances.unit_list) do
    if Alliances.CONFIG.unit_enabled[unit.id] == nil then
        Alliances.CONFIG.unit_enabled[unit.id] = true
    end

    if Alliances.CONFIG.unit_weights[unit.id] == nil then
        Alliances.CONFIG.unit_weights[unit.id] = unit.weight
    end
end

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
local function schedule_despawn(unit)
    Game.scheduler:delay_action(UNIT_LIFETIME, function ()
        if EntityAux.owned(unit) then
            local despawner = FlowCallbacks.state_game.despawner
            if despawner then
                -- IIRC, this is the only safe despawner for bosses.
                despawner:force_despawn(unit)
            end
        end
    end)
end

-- Per-floor caps for the units that would otherwise flood a floor. Counts are
-- cleared in the EndlessServer.get_floor hook below (where the old Orox flag was).
local ALLIANCE_LIMITS = {
    boss_orox = 1,
    boss_mummy = 3,
    demon_heavy = 8,
    spider_queen = 8,
    lich = 12,
}
-- Units that hit their per-floor cap are replaced with this one instead, so a single kind of enemy
-- cannot flood a floor. If it is unchecked in the config the spawn is left vanilla instead.
local CAP_FALLBACK_UNIT = "portal_crypt"
local floor_spawn_counts = {}

-- Rebuilt on config change, never per spawn: rebuilding them per spawn meant thousands of
-- table.insert calls (250 / weight^2 entries per unit) for every monster the game spawned.
local weighted_pool = {}
local weighted_pool_without_crypt_boss = {}

local function build_weighted_pool(pool, exclude_crypt_boss)
    for _, unit in ipairs(Alliances.unit_list) do
        local enabled = Alliances.CONFIG.unit_enabled[unit.id] ~= false
        if enabled and not (exclude_crypt_boss and unit.id == "boss_mummy") then
            local weight = Alliances.CONFIG.unit_weights[unit.id] or unit.weight
            local entries = math.max(1, math.floor(250 / (weight * weight)))
            for i = 1, entries do
                pool[#pool + 1] = unit.id
            end
        end
    end
end

-- Called at load, by the config UI and by DucksUI (Alliances.load_config) after settings change.
-- Tables are swapped rather than cleared: table.clear does not exist yet while mods are loaded
-- (the game patches it in later), and this must work at load time too.
Alliances.rebuild_pools = function()
    weighted_pool = {}
    weighted_pool_without_crypt_boss = {}

    build_weighted_pool(weighted_pool, false)
    build_weighted_pool(weighted_pool_without_crypt_boss, true)
end

Alliances.load_config = function()
    Alliances.rebuild_pools()
end

Alliances.rebuild_pools()

local alliances_modify_unit_path = function(original_path)
    if not original_path or not Alliances.CONFIG.enabled then
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

    local pool = boss_floor and weighted_pool_without_crypt_boss or weighted_pool

    if #pool == 0 then
        -- Every unit can be unchecked in the config; leave the spawn vanilla rather than fail.
        return original_path
    end

    local random_choice = pool[math.random(1, #pool)]
    local cap = ALLIANCE_LIMITS[random_choice]

    if cap then
        local spawned = floor_spawn_counts[random_choice] or 0

        if spawned >= cap then
            if Alliances.CONFIG.unit_enabled[CAP_FALLBACK_UNIT] == false then
                return original_path
            end

            random_choice = CAP_FALLBACK_UNIT
        else
            floor_spawn_counts[random_choice] = spawned + 1
        end
    end

    return random_choice
end

Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)
    
    if path == "lua/menu/lobby_logic" then
        Mods.hook:set_object_path("LobbyLogic", "from_server_lobby_start_countdown", function(orig, self, server_peer_id, countdown_time, floor_id)
            orig(self, server_peer_id, countdown_time, floor_id)
            if floor_id == "crypt_floor_10" then
                is_crypt_boss_floor = true
            else
                is_crypt_boss_floor = false
            end
        end, MOD_NAME .. ".LobbyLogic.from_server_lobby_start_countdown", MOD_NAME)
    end

    if path == "foundation/lua/entity/entity_spawner" then
        Mods.hook:set_object_path("EntitySpawner", "spawn_entity", function(orig, self, unit_path, position, rotation, parent_go_id, setup_info)
            local modified_path = alliances_modify_unit_path(unit_path)

            -- Let original implementation do everything it needs (this preserves spawn_info)
            local unit, go_id = orig(self, modified_path, position, rotation, parent_go_id, setup_info)

            -- Only clean up units this mod put on the floor: a vanilla boss (mod switched off, or
            -- the crypt boss floor passthrough) must never be despawned by us.
            if modified_path ~= unit_path then
                for _, despawn_name in ipairs(DESPAWN_UNITS) do
                    if string.find(modified_path, despawn_name) then
                        schedule_despawn(unit)
                        break
                    end
                end
            end

            return unit, go_id
        end, MOD_NAME .. ".EntitySpawner.spawn_entity", MOD_NAME)
    end

    if path == "lua/managers/entity_culling_manager" then
        Mods.hook:set_object_path("EntityCullingManager", "cull_unit", function(orig, self, unit)
            if not self.not_culled_units[unit] then 
                -- Stops crashes when unregistered units that do not have data to cull when offscreen.
                return
            end
            orig(self, unit)
        end, MOD_NAME .. ".EntityCullingManager.cull_unit", MOD_NAME)
    end

    if path == "lua/managers/endless_server" then
        Mods.hook:set_object_path("EndlessServer", "get_floor", function(orig, floor_index)
            floor_spawn_counts = {}

            return orig(floor_index)
        end, MOD_NAME .. ".EndlessServer.get_floor", MOD_NAME)
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)
