-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.8
-- Purpose: Makes enemies spawn traps on death.
-- =================================================================================================

local MOD_NAME = "GraveTrappers"

GraveTrappers = GraveTrappers or {}

GraveTrappers.loaded = true

-- Saveable settings
GraveTrappers.CONFIG = GraveTrappers.CONFIG or {
    enabled = true,
    confusion_duration = 4,
    affect_enemies = false,
    enemies = {
        skeleton_defender = { trap = "spikeplate", chance = 0.04 },
        mummy_giant = { trap = "spikeplate", chance = 0.04 },
        mummy_priest = { trap = "spikeplate", chance = 0.04 },
        skeleton_commander = { trap = "spikeplate", chance = 0.04 },
        grunt_shaman = { trap = "spinner", chance = 0.04 },
        orc_juggernaut = { trap = "spinner", chance = 0.50 },
        spider_warrior = { trap = "spinner", chance = 0.50 },
        cultist_sorcerer = { trap = "lavacolumn", chance = 0.12 },
        demon_ranged = { trap = "lavacolumn", chance = 0.50 },
    },
    drop_chances = {
        Off = 0.00,
        Small = 0.02,
        Medium = 0.04,
        Large = 0.12,
        Half = 0.50,
        Force = 1.00,
    },
}

-- Function to get trap path and chance for an enemy from config
local function get_enemy_config(enemy_id)
    if not GraveTrappers.CONFIG.enemies or not GraveTrappers.CONFIG.enemies[enemy_id] then
        return nil, nil
    end
    
    local config = GraveTrappers.CONFIG.enemies[enemy_id]
    local trap_path = GraveTrappers.get_trap_path and GraveTrappers.get_trap_path(config.trap, get_enemy_biome(enemy_id))
    
    -- Handle both numeric chance values (from slider) and string chance values (legacy)
    local chance_value
    if type(config.chance) == "number" then
        chance_value = config.chance
    elseif type(config.chance) == "string" then
        chance_value = GraveTrappers.CONFIG.drop_chances[config.chance] or 0.04
    else
        chance_value = 0.04
    end
    
    return trap_path, chance_value
end

-- Helper function to determine enemy biome
function get_enemy_biome(enemy_id)
    local biomes = {
        skeleton_defender = "crypt",
        mummy_giant = "crypt",
        mummy_priest = "crypt",
        skeleton_commander = "crypt",
        grunt_shaman = "caves",
        orc_juggernaut = "caves",
        spider_warrior = "caves",
        cultist_sorcerer = "lava",
        demon_ranged = "lava",
    }
    return biomes[enemy_id] or "caves"
end

-- Helper function to check if a unit is a keybearer
local function is_keybearer(unit)
    -- Method 1: Check dropper component state for key drops
    if EntityAux and EntityAux._context_master_raw then
        local dropper_context = EntityAux._context_master_raw(unit, "dropper")
        if dropper_context and dropper_context.state and dropper_context.state.drop then
            local drop_path = dropper_context.state.drop
            if type(drop_path) == "string" and string.find(drop_path, "keys") then
                return true
            end
        end
    end
    
    -- Method 2: Check spawned entity tags using Unit.get_data directly
    local index = 0
    while true do
        local tag = Unit.get_data(unit, "spawned_entity_tags", index)
        if not tag then
            break
        end
        if tag == "keybearer" then
            return true
        end
        index = index + 1
    end
    
    return false
end
-- ============================================================
local DESPAWN_UNITS = {
    "gameobjects/traps/trap_spinner_4c_1blades",
}
local UNIT_LIFETIME = 30
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
-- ============================================================
local function set_on_death_result_to_drop_grid(result, drop_spec, chance, max_i, max_j, spacing)
    if not result then return end

    local drop
    local actual_chance
    if type(drop_spec) == "string" then
        drop = drop_spec
        actual_chance = chance
    elseif type(drop_spec) == "table" then
        drop = drop_spec[math.random(#drop_spec)]
        actual_chance = chance
    end

    if drop then
        result.on_death_authorative = function (unit, is_local_hit, hit, component)
            local entity_spawner = FlowCallbacks.state_game.entity_spawner
            local position = Unit.world_position(unit, 0)
            local rotation = Quaternion.from_yaw_pitch_roll(0, 0, 0)
            
            -- If keybearer, drop the key and skip trap spawning
            if is_keybearer(unit) then
                local key_unit = entity_spawner:spawn_entity("gameobjects/keys/small", position, rotation, nil)
                NetworkUnitSynchronizer:add(key_unit)
                return
            end

            if math.random() <= actual_chance then
                for i = -max_i, max_i, 1 do
                    for j = -max_j, max_j, 1 do
                        local offset = Vector3(i * spacing, j * spacing, 0)
                        local spawn_pos = position + offset
                        local dropped_unit = entity_spawner:spawn_entity(drop, spawn_pos, rotation, nil)
                        NetworkUnitSynchronizer:add(dropped_unit)
                    end
                end
            end
        end
    end
end

local function set_on_death_result_to_drop(result, drop_spec, chance)
    if not result then return end

    local drop
    local actual_chance
    if type(drop_spec) == "string" then
        drop = drop_spec
        actual_chance = chance
    elseif type(drop_spec) == "table" then
        drop = drop_spec[math.random(#drop_spec)]
        actual_chance = chance
    end

    if drop then
        result.on_death_authorative = function (unit, is_local_hit, hit, component)
            local entity_spawner = FlowCallbacks.state_game.entity_spawner
            local position = Unit.world_position(unit, 0)
            local rotation = Quaternion.from_yaw_pitch_roll(0, 0, 0)
            
            -- If keybearer, drop the key and skip trap spawning
            if is_keybearer(unit) then
                local key_unit = entity_spawner:spawn_entity("gameobjects/keys/small", position, rotation, nil)
                NetworkUnitSynchronizer:add(key_unit)
                return
            end

            if math.random() <= actual_chance then
                local dropped_unit = entity_spawner:spawn_entity(drop, position, rotation, nil)
                NetworkUnitSynchronizer:add(dropped_unit)

                if drop == "gameobjects/traps/trap_spinner_4c_1blades" then
                    if EntityAux.owned(dropped_unit) then
                        schedule_despawn(dropped_unit, drop)
                    end
                end                
            end
        end
    end
end

-- ============================================================
Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if not GraveTrappers.CONFIG.enabled then
        return result
    end

    if path == "gameobjects/carry/elemental_shockwave" and result then
        local LIFETIME = 0

        -- Shockwave confusion settings must apply on ALL clients that have this mod,
        -- not just the host. The base game broadcasts the explode ability to all clients
        -- via rpc_execute_ability. Each client independently runs the sphere physics query
        -- and detects hits on their own avatar (authoritative because they own it).
        -- call_master_hit on the status_receiver reads hit.settings.status_effects to
        -- apply status effects. By adding status_effects here (before the host guard),
        -- all GraveTrappers users get confusion from the shockwave explosion.
        -- NOTE: Players without GraveTrappers will NOT get confused — this is a
        -- fundamental engine limitation (each client reconstructs hit settings from its
        -- own local require cache, so the settings must be modified on every client).
        local confusion_duration = GraveTrappers.CONFIG.confusion_duration or 4

        result.abilities.explode.events[1].status_effects = {
            confused = {
                duration = confusion_duration,
            },
        }

        result.on_entity_registered = function (unit)
            if EntityAux.owned(unit) then

                Game.scheduler:delay_action(LIFETIME, function ()
                    if not unit or not Unit.alive(unit) then
                        return
                    end
                    
                    -- Multiplayer safety: protected position call
                    local success, position = pcall(Unit.world_position, unit, 0)
                    if not success or not position then
                        return
                    end
                    
                    local success2, forward = pcall(UnitAux.unit_forward, unit)
                    local direction = success2 and forward or Vector3(0, 1, 0)
                    
                    EntityAux.call_interface(unit, "i_hit_receiver", "hit", {
                        damage_amount = 99999,
                        settings = {
                            hit_react = "push",
                        },
                        modifiers = {},
                        direction = Vector3Aux.box_temp(-direction),
                        position = Vector3Aux.box_temp(position),
                        random_seed = math.random() * 1000,
                    })
                end)
            end
        end
    end

    if not _G.is_host_ducks_mods then
        return result
    end

    -- Small Enemies
    if path == "characters/skeleton_defender/skeleton_defender" and result then
        local trap_path, chance = get_enemy_config("skeleton_defender")
        if trap_path and chance then
            set_on_death_result_to_drop(result, {trap_path}, chance)
        end
    end
    -- =========================================================================================================
    -- Medium Enemies
    if path == "characters/mummy_giant/mummy_giant" and result then
        local trap_path, chance = get_enemy_config("mummy_giant")
        if trap_path and chance then
            set_on_death_result_to_drop(result, {trap_path}, chance)
        end
    end

    if path == "characters/mummy_priest/mummy_priest" and result then
        local trap_path, chance = get_enemy_config("mummy_priest")
        if trap_path and chance then
            set_on_death_result_to_drop(result, {trap_path}, chance)
        end
    end

    if path == "characters/skeleton_commander/skeleton_commander" and result then
        local trap_path, chance = get_enemy_config("skeleton_commander")
        if trap_path and chance then
            set_on_death_result_to_drop(result, {trap_path}, chance)
        end
    end

    if path == "characters/grunt_shaman/grunt_shaman" and result then
        local trap_path, chance = get_enemy_config("grunt_shaman")
        if trap_path and chance then
            set_on_death_result_to_drop(result, {trap_path}, chance)
        end
    end

    if path == "characters/orc_juggernaut/orc_juggernaut" and result then
        local trap_path, chance = get_enemy_config("orc_juggernaut")
        if trap_path and chance then
            set_on_death_result_to_drop(result, {trap_path}, chance)
        end
    end

    if path == "characters/spider_warrior/spider_warrior" and result then
        local trap_path, chance = get_enemy_config("spider_warrior")
        if trap_path and chance then
            set_on_death_result_to_drop(result, {trap_path}, chance)
        end
    end

    if path == "characters/cultist_sorcerer/cultist_sorcerer" and result then
        local trap_path, chance = get_enemy_config("cultist_sorcerer")
        if trap_path and chance then
            set_on_death_result_to_drop(result, {trap_path}, chance)
        end
    end

    if path == "characters/demon_ranged/demon_ranged" and result then
        local trap_path, chance = get_enemy_config("demon_ranged")
        if trap_path and chance then
            set_on_death_result_to_drop(result, {trap_path}, chance)
        end
    end
    -- =========================================================================================================
    -- Boss Enemies
    if path == "characters/lich/lich" and result then
        set_on_death_result_to_drop(result, {"gameobjects/carry/elemental_ice"}, GraveTrappers.CONFIG.drop_chances.Force)
    end

    if path == "characters/necromancer/necromancer" and result then
        set_on_death_result_to_drop(result, {"gameobjects/carry/elemental_ice"}, GraveTrappers.CONFIG.drop_chances.Force)
    end

    if path == "characters/spider_queen/spider_queen" and result then
        set_on_death_result_to_drop(result, {"gameobjects/carry/elemental_poison"}, GraveTrappers.CONFIG.drop_chances.Force)
    end

    if path == "characters/cultist_armor/cultist_armor" and result then
        set_on_death_result_to_drop(result, {"gameobjects/carry/elemental_shockwave"}, GraveTrappers.CONFIG.drop_chances.Force)
    end

    if path == "characters/demon_heavy/demon_heavy" and result then
        set_on_death_result_to_drop_grid(result, {"gameobjects/traps/lavacolumn"}, GraveTrappers.CONFIG.drop_chances.Force, 0.5, 0.5, 3.0)
    end
    -- =========================================================================================================
    if path == "gameobjects/spawners/spawner_beam" and result then
        set_on_death_result_to_drop(result, {"gameobjects/carry/elemental_shockwave"}, GraveTrappers.CONFIG.drop_chances.Force)
    end

    if path == "gameobjects/spawners/spawner_exploding" and result then
        set_on_death_result_to_drop(result, {"gameobjects/carry/elemental_shockwave"}, GraveTrappers.CONFIG.drop_chances.Force)
    end

    if path == "gameobjects/spawners/spawner_freeze_nova" and result then
        set_on_death_result_to_drop(result, {"gameobjects/carry/elemental_ice"}, GraveTrappers.CONFIG.drop_chances.Force)
    end

    if path == "gameobjects/spawners/spawner_mortar" and result then
        set_on_death_result_to_drop(result, {"gameobjects/carry/elemental_shockwave"}, GraveTrappers.CONFIG.drop_chances.Force)
    end

    if path == "gameobjects/spawners/spawner_poison_launcher" and result then
        set_on_death_result_to_drop(result, {"gameobjects/carry/elemental_poison"}, GraveTrappers.CONFIG.drop_chances.Force)
    end

    if path == "gameobjects/spawners/spawner_twister" and result then
        set_on_death_result_to_drop(result, {"gameobjects/carry/elemental_shockwave"}, GraveTrappers.CONFIG.drop_chances.Force)
    end

    if path == "gameobjects/spawners/spawner_ghost" and result then
        set_on_death_result_to_drop(result, {"gameobjects/carry/elemental_ice"}, GraveTrappers.CONFIG.drop_chances.Force)
    end
    -- =========================================================================================================
    if path == "gameobjects/carry/elemental_ice" and result then
        local LIFETIME = 0.1

        result.on_entity_registered = function (unit)
            if EntityAux.owned(unit) then

                Game.scheduler:delay_action(LIFETIME, function ()
                    if not unit or not Unit.alive(unit) then
                        return
                    end
                    
                    -- Multiplayer safety: protected position call
                    local success, position = pcall(Unit.world_position, unit, 0)
                    if not success or not position then
                        return
                    end
                    
                    local success2, forward = pcall(UnitAux.unit_forward, unit)
                    local direction = success2 and forward or Vector3(0, 1, 0)
                    
                    EntityAux.call_interface(unit, "i_hit_receiver", "hit", {
                        damage_amount = 99999,
                        settings = {
                            hit_react = "push",
                        },
                        modifiers = {},
                        direction = Vector3Aux.box_temp(-direction),
                        position = Vector3Aux.box_temp(position),
                        random_seed = math.random() * 1000,
                    })
                end)
            end
        end
    end
    if path == "gameobjects/carry/elemental_poison" and result then
        local LIFETIME = 0
        
        result.on_entity_registered = function (unit)
            if EntityAux.owned(unit) then

                Game.scheduler:delay_action(LIFETIME, function ()
                    if not unit or not Unit.alive(unit) then
                        return
                    end
                    
                    -- Multiplayer safety: protected position call
                    local success, position = pcall(Unit.world_position, unit, 0)
                    if not success or not position then
                        return
                    end
                    
                    local success2, forward = pcall(UnitAux.unit_forward, unit)
                    local direction = success2 and forward or Vector3(0, 1, 0)
                    
                    EntityAux.call_interface(unit, "i_hit_receiver", "hit", {
                        damage_amount = 99999,
                        settings = {
                            hit_react = "push",
                        },
                        modifiers = {},
                        direction = Vector3Aux.box_temp(-direction),
                        position = Vector3Aux.box_temp(position),
                        random_seed = math.random() * 1000,
                    })
                end)
            end
        end
    end
    -- Poison gas cloud - this is what actually does the damage/effects
    if path == "gameobjects/carry/elemental_poison_gascloud" and result then
        local affect_enemies = GraveTrappers.CONFIG.affect_enemies or false
        
        if affect_enemies and result.abilities and result.abilities.gas and result.abilities.gas.events then
            result.abilities.gas.events[1].friendly_fire = true
        else
            result.abilities.gas.events[1].friendly_fire = false
        end
    end
    -- =========================================================================================================
    return result
end)

local safe_working_traps_crypt = {
    "gameobjects/traps/spikeplate_1c_1c",
    "gameobjects/traps/pressureplate_1c_1c", -- Not a trap but works
    "gameobjects/traps/trap_floor_spears_1c_1c",
}

local safe_working_traps_caves = {
    "gameobjects/traps/trap_spinner_4c_1blades",
    "gameobjects/traps/spikeplate_1c_1c",
}

local safe_working_traps_lava = {
    "gameobjects/traps/trap_floor_spears_1c_1c",
    "gameobjects/traps/trap_lava_floor_blades_4c",
    "gameobjects/traps/lavacolumn",
}

local all_traps = {
	"gameobjects/traps/lavacolumn",
	"gameobjects/traps/pressureplate_1c_1c",
	"gameobjects/traps/spikeplate_1c_1c",
	"gameobjects/traps/trap_floor_spears_1c_1c",
	"gameobjects/traps/trap_lava_floor_blades_4c",
	"gameobjects/traps/trap_pendulum",
	"gameobjects/traps/trap_spear",
	"gameobjects/traps/trap_spinner_4c_1blades",
	"gameobjects/traps/trap_spinner_4c_1blades_triggered",
}