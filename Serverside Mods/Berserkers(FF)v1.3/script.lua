-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.3
-- Purpose: Makes some enemies stronger.
-- =================================================================================================

local MOD_NAME = "Berserkers"

Berserkers = Berserkers or {}

-- Mark as loaded so DucksUI can save settings
Berserkers.loaded = true

-- Saveable settings
Berserkers.CONFIG = Berserkers.CONFIG or {
    enabled = true,
    juggernaut_chance = 0.05,
    berserker_chance = 0.05,
    enemies = {},
}

-- Timing settings
Berserkers.juggernaut_status_time = 40
Berserkers.juggernaut_delay = 1
Berserkers.berserker_stage_1_delay = 4
Berserkers.berserker_stage_2_delay = 15

-- Enemy list (shared for both modes)
Berserkers.enemy_list = {
    { id = "mummy_giant",        name = "Mummy Giant",        biome = "crypt" },
    { id = "mummy_priest",       name = "Mummy Priest",       biome = "crypt" },
    { id = "skeleton_defender",  name = "Skeleton Defender",  biome = "crypt" },
    { id = "skeleton_warrior",   name = "Skeleton Warrior",   biome = "crypt" },
    { id = "skeleton_commander", name = "Skeleton Commander", biome = "crypt" },
    { id = "necromancer",        name = "Necromancer",        biome = "crypt" },
    { id = "grunt_shaman",       name = "Grunt Shaman",       biome = "caves" },
    { id = "orc_juggernaut",     name = "Orc Juggernaut",     biome = "caves" },
    { id = "spider_warrior",     name = "Spider Warrior",     biome = "caves" },
    { id = "cultist_sorcerer",   name = "Cultist Sorcerer",   biome = "lava" },
    { id = "demon_ranged",       name = "Demon Gargoyle",     biome = "lava" },
    { id = "cultist_armor",      name = "Cultist Armor",      biome = "lava" },
}

-- Per-enemy config (defaults all enabled)
for _, enemy in ipairs(Berserkers.enemy_list) do
    Berserkers.CONFIG.enemies[enemy.id] = Berserkers.CONFIG.enemies[enemy.id] or { juggernaut = true, berserker = true }
end

-- Build lookup set
local enemy_set = {}
for _, enemy in ipairs(Berserkers.enemy_list) do
    enemy_set[enemy.id] = true
end

-- Status effects
local juggernaut_status = {
    poisoned = { damage_per_interval = 0, duration = Berserkers.juggernaut_status_time, interval = 1 },
    regen = { duration = Berserkers.juggernaut_status_time, health_per_second = 0.12, interval = 1 },
}
local berserker_stage_1_status = {
    slowed = { duration = Berserkers.berserker_stage_2_delay - 2, speed_modifier = 0.3 },
}
local berserker_stage_2_status = {
    slowed = { duration = 1500, speed_modifier = 0.5 },
}

-- Activation functions
local activate_juggernaut_mode, activate_berserker_stage_1, activate_berserker_stage_2

activate_juggernaut_mode = function(unit, force)
    if not Berserkers.CONFIG.enabled then return end
    if not force and math.random() >= Berserkers.CONFIG.juggernaut_chance then return end
    
    Game.scheduler:delay_action(Berserkers.juggernaut_delay, function()
        if EntityAux.is_alive_entity(unit) then
            EntityAux.call_master(unit, "status_receiver", "add_status_effect", juggernaut_status)
        end
    end)
end

activate_berserker_stage_2 = function(unit)
    Game.scheduler:delay_action(Berserkers.berserker_stage_2_delay, function()
        if EntityAux.is_alive_entity(unit) then
            EntityAux.call_master(unit, "status_receiver", "add_status_effect", berserker_stage_2_status)
            Game.scheduler:delay_action(Berserkers.berserker_stage_2_delay, function()
                if EntityAux.is_alive_entity(unit) then
                    activate_juggernaut_mode(unit, true)
                end
            end)
        end
    end)
end

activate_berserker_stage_1 = function(unit)
    if math.random() >= Berserkers.CONFIG.berserker_chance then return end
    
    Game.scheduler:delay_action(Berserkers.berserker_stage_1_delay, function()
        if EntityAux.is_alive_entity(unit) then
            EntityAux.call_master(unit, "status_receiver", "add_status_effect", berserker_stage_1_status)
            activate_berserker_stage_2(unit)
        end
    end)
end

-- Main effect application
local function apply_effects(unit, owned)
    if not Berserkers.CONFIG.enabled or not owned then return end
    
    local unit_path = Unit.get_data(unit, "unit_path")
    if not unit_path then return end
    
    local unit_name = string.match(unit_path, "([^/]+)$") or unit_path
    if not enemy_set[unit_name] then return end
    
    local config = Berserkers.CONFIG.enemies[unit_name]
    if not config then return end
    
    if config.berserker then
        activate_berserker_stage_1(unit)
    end
    if config.juggernaut then
        activate_juggernaut_mode(unit, false)
    end
end

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "foundation/lua/entity/entity_spawner" then
        Mods.hook:set(MOD_NAME, "EntitySpawner.trigger_on_entity_registered", function(orig, self, unit, owned)
            orig(self, unit, owned)

            apply_effects(unit, owned) -- Apply Non-Destructively
    
        end)
    end

    return result
end)

