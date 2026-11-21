local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Adds new abilities to the Necromancer enemy"

local MOD_NAME, log_message = Mods.init_mod()

-- Ice field casts Orb of Winter and the ice beam cast raises a Lightning Shield. Both are one row
-- each in the mod UI (StrongerEnemies.ABILITY_OPTIONS.necromancer).
Mods.hook:set_object(_G, "require", function (orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/necromancer/necromancer" and result and _G.is_host_ducks_mods then
        if result.abilities.ice_field.events[2] then
            result.abilities.ice_field.events[2].on_exit_custom = function (ability_event_handler, event)
                if not StrongerEnemies.roll_ability("necromancer", "ice_field") then
                    return
                end

                local caster_unit = event.caster_unit

                -- Multiplayer safety: validate caster exists and is alive
                if not caster_unit or not Unit.alive(caster_unit) then
                    return
                end

                if EntityAux.owned(caster_unit) then
                    -- The engine's aim math can spin forever on a NaN direction; a caster with no
                    -- finite position is one way to feed it one.
                    if not StrongerEnemies.is_finite_position(Unit.world_position(caster_unit, 0)) then
                        StrongerEnemies.trace_skip("orb_of_winter_hover", caster_unit,
                            "caster position not finite")

                        return
                    end

                    -- The command is queued, so the boxed target must be copied out now; an unboxed
                    -- engine vector is a recycled scratch buffer and reads back as nonsense later.
                    local target_pos = StrongerEnemies.event_target_position(event)

                    local command = TempTableFactory:get_map(
                        "ability_name", "orb_of_winter_hover",
                        "settings_path", "equipment/wizard/weapon01",
                        "target_position", target_pos
                    )

                    EntityAux.queue_command_master(caster_unit, "ability", "execute_ability", command)
                end
            end
        end

        if result.abilities.ice_beam.events[2] then
            local original_beam_on_exit = result.abilities.ice_beam.events[2].on_exit_custom or CommonEventsAux.beam_on_exit

            result.abilities.ice_beam.events[2].on_exit_custom = function (ability_event_handler, event)
                if original_beam_on_exit then
                    original_beam_on_exit(ability_event_handler, event)
                end

                if not StrongerEnemies.roll_ability("necromancer", "ice_beam") then
                    return
                end

                local caster_unit = event.caster_unit

                -- Multiplayer safety: validate caster exists and is alive
                if not caster_unit or not Unit.alive(caster_unit) then
                    return
                end

                if EntityAux.owned(caster_unit) then
                    local command = TempTableFactory:get_map(
                        "ability_name", "lightning_shield",
                        "settings_path", "equipment/wizard/weapon01"
                    )

                    EntityAux.queue_command_master(caster_unit, "ability", "execute_ability", command)
                end
            end
        end
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)
