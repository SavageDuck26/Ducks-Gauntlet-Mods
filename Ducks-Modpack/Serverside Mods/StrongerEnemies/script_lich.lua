local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Adds new abilities to the Lich"
local MOD_NAME, log_message = Mods.init_mod()

-- Every Lich ability can top itself with a storm bomb. Which abilities may do it, and how often,
-- is one row each in the mod UI (StrongerEnemies.ABILITY_OPTIONS.lich).
local function cast_storm_bomb(source, fallback_unit)
    local caster_unit = source.caster_unit or fallback_unit

    -- Multiplayer safety: the caster can be gone by the time the callback runs.
    if not caster_unit or not Unit.alive(caster_unit) then
        return
    end

    if not EntityAux.owned(caster_unit) then
        return
    end

    -- The engine's aim math can spin forever on a NaN direction, and a caster with no finite position
    -- is one way to feed it one. No position, no cast.
    if not StrongerEnemies.is_finite_position(Unit.world_position(caster_unit, 0)) then
        StrongerEnemies.trace_skip("storm_bomb", caster_unit, "caster position not finite")

        return
    end

    -- The command is queued, so the boxed target must be copied out now; an unboxed engine vector
    -- is a recycled scratch buffer and reads back as nonsense when the ability finally runs.
    local target_pos = StrongerEnemies.event_target_position(source)

    local command = TempTableFactory:get_map(
        "ability_name", "storm_bomb",
        "settings_path", "equipment/wizard/weapon03",
        "target_position", target_pos
    )

    EntityAux.queue_command_master(caster_unit, "ability", "execute_ability", command)
end

local function try_storm_bomb(ability_id, source, fallback_unit)
    if StrongerEnemies.roll_ability("lich", ability_id) then
        cast_storm_bomb(source, fallback_unit)
    end
end

Mods.hook:set_object(_G, "require", function (orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/lich/lich" and result and _G.is_host_ducks_mods then
        -- Raise skeletons' on_enter is replaced as a whole, the same way the settings file leaves it.
        if result.abilities.raise_skeletons then
            result.abilities.raise_skeletons.on_enter = {
                custom_callback = function (ability_component, unit, ability)
                    try_storm_bomb("raise_skeletons", ability, unit)
                end,
            }
        end

        -- Event callbacks keep whatever the settings already pointed at (direct or inherited) and
        -- add the storm bomb roll after it.
        local function hook_event(ability_name, event_index, ability_id)
            local ability = result.abilities[ability_name]

            if not ability or not ability.events then
                return
            end

            local event = ability.events[event_index]

            if not event then
                return
            end

            local original = event.on_enter_custom
            local inherit = event.inherit_from

            event.on_enter_custom = function (ability_event_handler, event_data)
                if original then
                    pcall(original, ability_event_handler, event_data)
                elseif inherit and result.abilities[inherit] and result.abilities[inherit].on_enter_custom then
                    pcall(result.abilities[inherit].on_enter_custom, ability_event_handler, event_data)
                end

                try_storm_bomb(ability_id, event_data)
            end
        end

        hook_event("shadowbeam", 2, "shadowbeam")
        hook_event("shadowbeam_left_to_right", 2, "shadowbeam_left_to_right")
        hook_event("shadowbeam_right_to_left", 2, "shadowbeam_right_to_left")
        hook_event("shadowdive_appear", 1, "shadowdive_appear")

        -- Whole-ability callbacks (ghost swarm, the on-spawn skeleton raise) use on_enter directly.
        local function hook_ability_on_enter(ability_name, ability_id)
            local ability = result.abilities[ability_name]

            if not ability then
                return
            end

            ability.on_enter = ability.on_enter or {}

            local original = ability.on_enter.custom_callback

            ability.on_enter.custom_callback = function (component, unit, ability_inst)
                if original then
                    pcall(original, component, unit, ability_inst)
                end

                try_storm_bomb(ability_id, ability_inst, unit)
            end
        end

        hook_ability_on_enter("ghost_swarm", "ghost_swarm")
        hook_ability_on_enter("on_spawn_raise_skeletons", "on_spawn_raise_skeletons")
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)
