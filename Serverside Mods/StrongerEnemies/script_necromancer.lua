-- =================================================================================================
-- Author: SavageDuck26
-- =================================================================================================

local MOD_NAME = "StrongerNecromancer"

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/necromancer/necromancer" and result and _G.is_host_ducks_mods then

        if result.abilities.ice_field.events[2] then
            result.abilities.ice_field.events[2].on_exit_custom = function (ability_event_handler, event)

                if math.random() > 0.50 then
                    return
                end
                local caster_unit = event.caster_unit
                -- Multiplayer safety: validate caster exists and is alive
                if not caster_unit or not Unit.alive(caster_unit) then
                    return
                end
                if EntityAux.owned(caster_unit) then
                    local target_pos = event.target_position_box or Vector3Aux.unbox(event.target_position_box)
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
                
                if math.random() > 0.20 then
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
end)