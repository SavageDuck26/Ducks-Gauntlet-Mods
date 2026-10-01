
local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "1.6.0"
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

-- =================================================================================================
-- Ending an ability early
--
-- Mirrors AbilityComponent._handle_interrupt_command for one chosen ability instead of the current
-- one: interrupt it, drop it from the state's active list and run its exit callbacks. That ends the
-- events it spawned, but AbilityEventAux.is_event_done ignores interruption for projectiles, so those
-- are marked done here as well.
-- =================================================================================================

local function ability_is(ability, ability_name, settings_path)
    local static_ability = ability.static_ability

    if static_ability == nil or static_ability.ability_name ~= ability_name then
        return false
    end

    return settings_path == nil or static_ability.settings_path == settings_path
end

-- AbilityEventAux.is_event_done only consults the query for a projectile, so interrupting the parent
-- ability does not stop one: marking the event done is what makes
-- AbilityEventHandler.remove_done_events despawn its effect unit and destroy the query.
local function event_is(event, unit, ability_name, settings_path)
    if event.ability_name ~= ability_name then
        return false
    end

    if settings_path ~= nil and event.settings_path ~= settings_path then
        return false
    end

    return event.caster_unit == unit or event.owner_unit == unit
end

local function end_ability_events(unit, ability_name, settings_path)
    local active_events = EntityAux.get_component("ability").ability_event_handler.active_events

    for i = 1, #active_events do
        local event = active_events[i]

        if event_is(event, unit, ability_name, settings_path) then
            event.done = true
        end
    end
end

-- Cutting one of the mod's casts short (storm bomb, the fire orb) leaves the visuals its flow
-- events started (ability_bomb_fire, ability_orb_fire, ...) playing on the caster. They are not
-- entities, so nothing despawns them and the effect stays on screen. Firing the unit's
-- stop_effects flow event tells its flow graph to tear those effects down.
StrongerEnemies.clear_flow_effects = function (unit)
    if unit and Unit.alive(unit) then
        Unit.flow_event(unit, "stop_effects")
    end
end

-- Owned units run their abilities on the master state.
local function find_active_ability(unit, ability_name, settings_path)
    local state = EntityAux.state_master(unit, "ability")
    local abilities = state and state.active_abilities

    if not abilities then
        return nil
    end

    for i = 1, #abilities do
        if ability_is(abilities[i], ability_name, settings_path) then
            return abilities[i], state
        end
    end
end

-- Returns false when the ability already finished on its own.
local function end_ability_instance(unit, ability, state)
    local abilities = state.active_abilities

    for i = 1, #abilities do
        if abilities[i] == ability then
            ability.interrupted = true

            table.remove(abilities, i)

            -- Only the ability that owned the busy timer may release it, otherwise the unit would
            -- start the next cast while another ability is still running.
            if state.current_ability == ability then
                state.current_ability = nil
                state.busy_time = nil
                state.is_busy = nil
            end

            EntityAux.get_component("ability"):on_ability_exit(unit, EntityAux._context_master_raw(unit, "ability"), ability)

            return true
        end
    end

    return false
end

-- Ends every running instance of ability_name on unit, plus the events they spawned. Returns how
-- many instances were ended.
-- Pass settings_path when the same ability name exists in more than one weapon.
StrongerEnemies.end_ability = function (unit, ability_name, settings_path)
    local ended = 0

    while true do
        local ability, state = find_active_ability(unit, ability_name, settings_path)

        if not ability or not end_ability_instance(unit, ability, state) then
            break
        end

        ended = ended + 1
    end

    end_ability_events(unit, ability_name, settings_path)
    StrongerEnemies.clear_flow_effects(unit)

    return ended
end

-- Caps an ability at `seconds`: it is ended when the timer fires, together with its events. Resolved
-- then rather than now, because an ability as short as storm_bomb (30 frames) is long gone and what
-- is still running is the projectile it fired. Returns true when it was running at call time.
-- Example: StrongerEnemies.end_ability_after(caster_unit, "storm_bomb", 4)
StrongerEnemies.end_ability_after = function (unit, ability_name, seconds, settings_path)
    local was_running = find_active_ability(unit, ability_name, settings_path) ~= nil

    AddUtility.delay_action(seconds, function ()
        StrongerEnemies.end_ability(unit, ability_name, settings_path)
    end)

    return was_running
end
