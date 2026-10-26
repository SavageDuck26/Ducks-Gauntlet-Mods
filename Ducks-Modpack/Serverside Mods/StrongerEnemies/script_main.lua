
local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "1.6.4"
local MOD_DESCRIPTION = "Add abilities to enemies."

local MOD_NAME, log_message = Mods.init_mod()

StrongerEnemies = StrongerEnemies or {}
StrongerEnemies.loaded = true

-- Saveable settings (persisted by the DucksUI menu through mod_settings.json).
StrongerEnemies.CONFIG = StrongerEnemies.CONFIG or {
    enabled = true,
    nightmare_mode = false,
    lich = {
        enabled = true,
        shadowdive_bomb_chance = 1.00,
        storm_bomb_chance = 0.12,
    },
    necromancer = {
        enabled = true,
        winter_orb_chance = 0.50,
        shield_chance = 0.20,
    },
    mummy_bloated = {
        enabled = true,
        acid_bomber_chance = 0.10,
        ice_bomber_chance = 0.10,
        fire_bomber_chance = 0.10,
    },
    demon_heavy = {
        enabled = true,
        super_nova_orb_chance = 1.00,
        confusing_glare_shield_chance = 1.00,
        demon_egg_orb_chance = 1.00,
        super_nova_hover_chance = 1.00,
        super_nova_mortar_chance = 1.00,
    },
    spider_queen = {
        enabled = true,
        spin_web_chance = 1.00,
        lay_eggs_chance = 1.00,
    },
}

-- Gates one enemy's extra abilities: the master toggle and that enemy's own toggle must both be on.
StrongerEnemies.is_enabled = function (enemy)
    local config = StrongerEnemies.CONFIG

    if not config or config.enabled == false then
        return false
    end

    local entry = config[enemy]

    if entry and entry.enabled == false then
        return false
    end

    return true
end

-- Reads a chance slider for an enemy, falling back to the shipped default when unset.
StrongerEnemies.get_chance = function (enemy, key, default)
    local entry = StrongerEnemies.CONFIG and StrongerEnemies.CONFIG[enemy]

    if entry and entry[key] ~= nil then
        return entry[key]
    end

    return default
end

-- Nightmare mode gates the nastiest additions (extra storm bombs, mortar barrages).
StrongerEnemies.is_nightmare = function ()
    local config = StrongerEnemies.CONFIG

    return config ~= nil and config.nightmare_mode == true
end

-- =================================================================================================
-- Ability ids
--
-- An ability instance is identified by a 3-bit ability_id packed into all of its event and hit ids
-- (goid | ability_id | event_index | hit -- lua/components/ability_aux.lua), and events are matched
-- back by that id, so two live abilities on one unit that share an id alias each other's events.
-- The engine hands ids out from a wrapping counter and never checks the live set.
-- =================================================================================================

local function ability_id_count()
    if AbilityAux == nil then
        return nil
    end

    return 2 ^ AbilityAux.BITS_ABILITY
end

local function mark_ability_ids(state, in_use)
    local abilities = state and state.active_abilities

    if not abilities then
        return false
    end

    for i = 1, #abilities do
        local ability_id = abilities[i].ability_id

        if ability_id ~= nil then
            in_use[ability_id] = true
        end
    end

    return true
end

-- Lowest id no live ability holds, nil when all 8 are taken or the live set cannot be read.
StrongerEnemies.find_free_ability_id = function (unit, state)
    local id_count = ability_id_count()

    if not id_count or not unit then
        return nil
    end

    local in_use = {}
    local known = mark_ability_ids(state, in_use)

    -- Master and slave share one ability_event_handler, so the id must be free in both lists.
    known = mark_ability_ids(EntityAux.state_master(unit, "ability"), in_use) or known
    known = mark_ability_ids(EntityAux.state(unit, "ability"), in_use) or known

    if not known then
        return nil
    end

    for ability_id = 0, id_count - 1 do
        if not in_use[ability_id] then
            return ability_id
        end
    end
end

-- Gate for a cast made by hand from another mod file.
StrongerEnemies.can_execute_ability = function (unit)
    return StrongerEnemies.find_free_ability_id(unit) ~= nil
end

-- Abilities the mod stacks, keyed "<settings_path>.<ability_name>". A guarded cast is dropped when
-- every id is taken, since running it would alias a live ability. Other mod files may add entries.
StrongerEnemies.guarded_abilities = StrongerEnemies.guarded_abilities or {
    ["equipment/wizard/weapon02.sinister_orb"] = true,
    ["equipment/wizard/weapon02.sinister_orb_hover"] = true,
}

StrongerEnemies.is_guarded_ability = function (settings_path, ability_name)
    if not settings_path or not ability_name then
        return false
    end

    return StrongerEnemies.guarded_abilities[settings_path .. "." .. ability_name] == true
end

-- Route the id to the next free slot instead of letting the wrapping counter land on a live ability.
Mods.hook:set_object_path("AbilityAux", "generate_ability_id", function(orig, unit, state)
    local free_id = StrongerEnemies.find_free_ability_id(unit, state)

    if free_id == nil then
        return orig(unit, state)
    end

    if state then
        -- Keep the counter aligned so the engine's own ability chains keep rotating.
        state.ability_id_counter = (free_id + 1) % ability_id_count()
    end

    return free_id
end, MOD_NAME .. ".ability_id_alloc", MOD_NAME)

-- The engine's append path (on_event_complete chains such as sinister_orb -> sinister_orb_hover)
-- never carries caster_unit, so the ability runs with caster_unit == nil and
-- AbilityComponent.update_active_abilities advances it with unscaled GAME_DT. Its own events do get
-- caster_unit and are scaled by that unit's animation_speed (AbilityAux.scale_delta_time), so off a
-- caster whose animation_speed is not 1 an ability's schedule drifts from its events and its effect
-- expires before the last ones fire. The execute path already falls back to the casting unit, so
-- mirror it.
Mods.hook:set_object_path("AbilityComponent", "append_ability", function(orig, self, unit, context, ability, ...)
    if ability and ability.caster_unit == nil then
        local caster_unit = ability.owner_unit

        if caster_unit == nil or not Unit.alive(caster_unit) then
            caster_unit = unit
        end

        ability.caster_unit = caster_unit
    end

    return orig(self, unit, context, ability, ...)
end, MOD_NAME .. ".append_caster", MOD_NAME)

-- Owned units run every cast through AbilityComponent.command_master, engine-driven chains
-- included, so dropping a guarded cast here covers them all.
Mods.hook:set_object_path("AbilityComponent", "command_master", function(orig, self, unit, context, command_name, data)
    local ability_name = type(data) == "table" and data.ability_name

    if ability_name then
        local settings_path = data.settings_path or Unit.get_data(unit, "settings_path")

        if StrongerEnemies.is_guarded_ability(settings_path, ability_name) and not StrongerEnemies.can_execute_ability(unit) then
            log_message("WARN", "Dropped " .. ability_name .. ": all ability ids are in use")

            return
        end
    end

    return orig(self, unit, context, command_name, data)
end, MOD_NAME .. ".ability_id_guard", MOD_NAME)

-- =================================================================================================
-- Orb statuses
--
-- weapon02's sinister_orb carries burning = true, which is right for the wizard but not for the
-- monsters the mod hands the same orb to: a fire orb thrown by an enemy should not set players on
-- fire. AbilityEventHandler.execute_event builds the event from a deep clone of the settings, so
-- dropping the status there only affects that one cast and leaves the wizard's orb alone.
--
-- The bloated mummy's fire bomber is the exception: its death blast is that same burst, and it is
-- meant to burn what it catches.
-- =================================================================================================
Mods.hook:set_object_path("AbilityEventHandler", "execute_event", function (orig, self, event_data, parent_ability, ...)
    local event = orig(self, event_data, parent_ability, ...)

    if not event then
        return event
    end

    local ability_name = event.ability_name

    if ability_name ~= "sinister_orb" and ability_name ~= "sinister_orb_hover" then
        return event
    end

    local caster_unit = event.caster_unit

    if not caster_unit or EntityAux.has_component_master(caster_unit, "avatar") then
        return event
    end

    event.settings.status_effects = nil

    if Unit.get_data(caster_unit, "is_fire_bomber") then
        event.settings.status_effects = {
            burning = true,
        }
    end

    return event
end, MOD_NAME .. ".orb_statuses", MOD_NAME)

