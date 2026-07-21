-- =================================================================================================
-- Author: SavageDuck26
-- =================================================================================================

local MOD_NAME = "StrongerSpiderQueen"

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/spider_queen/spider_queen" and result and _G.is_host_ducks_mods then

        if result.abilities.spin_web.events[1] then
            result.abilities.spin_web.events[1].on_enter_custom = function (ability_event_handler, event)
                local caster_unit = event.caster_unit
                
                -- Multiplayer safety: validate caster exists and is alive
                if not caster_unit or not Unit.alive(caster_unit) then
                    return
                end

                local target_pos = event.target_position_box or Vector3Aux.unbox(event.target_position_box)

                if EntityAux.owned(caster_unit) then
                    local command = TempTableFactory:get_map(
                        "ability_name", "gas_projectile",
                        "settings_path", "gameobjects/spawners/spawner_poison_launcher",
                        "target_position", target_pos
                    )
                    EntityAux.queue_command_master(caster_unit, "ability", "execute_ability", command)
                end
            end
        end

        if result.abilities.lay_eggs.events[1] then
            result.abilities.lay_eggs.events[1].on_enter_custom = function (ability_event_handler, event)
                local caster_unit = event.caster_unit
                
                -- Multiplayer safety: validate caster exists and is alive
                if not caster_unit or not Unit.alive(caster_unit) then
                    return
                end

                local target_pos = event.target_position_box or Vector3Aux.unbox(event.target_position_box)

                if EntityAux.owned(caster_unit) then
                    local command = TempTableFactory:get_map(
                        "ability_name", "gas_projectile",
                        "settings_path", "gameobjects/spawners/spawner_poison_launcher",
                        "target_position", target_pos
                    )
                    EntityAux.queue_command_master(caster_unit, "ability", "execute_ability", command)
                end
            end
        end
    end

    return result
end)