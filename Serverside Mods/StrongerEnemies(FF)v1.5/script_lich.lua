-- =================================================================================================
-- Author: SavageDuck26
-- =================================================================================================

local MOD_NAME = "StrongerLich"

local STORM_BOMB_CHANCE = 0.12
local STORM_BOMB_FORCE = 1

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/lich/lich" and result and _G.is_host_ducks_mods then
        if result.abilities.raise_skeletons then
            result.abilities.raise_skeletons.on_enter = {
                custom_callback = function (ability_component, unit, ability)
                    if math.random() > STORM_BOMB_CHANCE then
                        return
                    end

                    if not StrongerEnemies.enabled then
                        return
                    end

                    local caster_unit = ability.caster_unit or unit
                    
                    -- Multiplayer safety: validate caster exists and is alive
                    if not caster_unit or not Unit.alive(caster_unit) then
                        return
                    end

                    if EntityAux.owned(caster_unit) then
                        local target_pos = (ability.target_position_box and Vector3Aux.unbox(ability.target_position_box)) or ability.target_position
                        local command = TempTableFactory:get_map(
                            "ability_name", "storm_bomb",
                            "settings_path", "equipment/wizard/weapon03",
                            "target_position", target_pos
                        )

                        EntityAux.queue_command_master(caster_unit, "ability", "execute_ability", command)
                    end
                end,
            }
        end

        if result.abilities.shadowbeam and result.abilities.shadowbeam.events then
            local ev = result.abilities.shadowbeam.events[2]

            if ev then
                local original = ev.on_enter_custom
                local inherit = ev.inherit_from

                ev.on_enter_custom = function(ability_event_handler, event)
                    if original then
                        pcall(original, ability_event_handler, event)
                    else
                        if inherit and result.abilities[inherit] and result.abilities[inherit].on_enter_custom then
                            pcall(result.abilities[inherit].on_enter_custom, ability_event_handler, event)
                        end
                    end

                    if math.random() < STORM_BOMB_CHANCE then
                        if not StrongerEnemies.enabled then
                            return
                        end

                        local caster_unit = event.caster_unit
                        
                        -- Multiplayer safety: validate caster exists and is alive
                        if not caster_unit or not Unit.alive(caster_unit) then
                            return
                        end

                        if EntityAux.owned(caster_unit) then
                            local target_pos = (event.target_position_box and Vector3Aux.unbox(event.target_position_box)) or event.target_position

                            local command = TempTableFactory:get_map(
                                "ability_name", "storm_bomb",
                                "settings_path", "equipment/wizard/weapon03",
                                "target_position", target_pos
                            )

                            EntityAux.queue_command_master(caster_unit, "ability", "execute_ability", command)
                        end
                    end
                end
            end
        end

        if result.abilities.shadowbeam_left_to_right and result.abilities.shadowbeam_left_to_right.events then
            local ev = result.abilities.shadowbeam_left_to_right.events[2]

            if ev then
                local original = ev.on_enter_custom
                local inherit = ev.inherit_from

                ev.on_enter_custom = function(ability_event_handler, event)
                    if original then
                        pcall(original, ability_event_handler, event)
                    else
                        if inherit and result.abilities[inherit] and result.abilities[inherit].on_enter_custom then
                            pcall(result.abilities[inherit].on_enter_custom, ability_event_handler, event)
                        end
                    end

                    if math.random() < STORM_BOMB_CHANCE then
                        if not StrongerEnemies.enabled then
                            return
                        end

                        local caster_unit = event.caster_unit
                        
                        -- Multiplayer safety: validate caster exists and is alive
                        if not caster_unit or not Unit.alive(caster_unit) then
                            return
                        end

                        if EntityAux.owned(caster_unit) then
                            local target_pos = (event.target_position_box and Vector3Aux.unbox(event.target_position_box)) or event.target_position

                            local command = TempTableFactory:get_map(
                                "ability_name", "storm_bomb",
                                "settings_path", "equipment/wizard/weapon03",
                                "target_position", target_pos
                            )

                            EntityAux.queue_command_master(caster_unit, "ability", "execute_ability", command)
                        end
                    end
                end
            end
        end

        if result.abilities.shadowbeam_right_to_left and result.abilities.shadowbeam_right_to_left.events then
            local ev = result.abilities.shadowbeam_right_to_left.events[2]

            if ev then
                local original = ev.on_enter_custom
                local inherit = ev.inherit_from

                ev.on_enter_custom = function(ability_event_handler, event)
                    if original then
                        pcall(original, ability_event_handler, event)
                    else
                        if inherit and result.abilities[inherit] and result.abilities[inherit].on_enter_custom then
                            pcall(result.abilities[inherit].on_enter_custom, ability_event_handler, event)
                        end
                    end

                    if math.random() < STORM_BOMB_CHANCE then
                        if not StrongerEnemies.enabled then
                            return
                        end

                        local caster_unit = event.caster_unit
                        
                        -- Multiplayer safety: validate caster exists and is alive
                        if not caster_unit or not Unit.alive(caster_unit) then
                            return
                        end

                        if EntityAux.owned(caster_unit) then
                            local target_pos = (event.target_position_box and Vector3Aux.unbox(event.target_position_box)) or event.target_position

                            local command = TempTableFactory:get_map(
                                "ability_name", "storm_bomb",
                                "settings_path", "equipment/wizard/weapon03",
                                "target_position", target_pos
                            )

                            EntityAux.queue_command_master(caster_unit, "ability", "execute_ability", command)
                        end
                    end
                end
            end
        end

        if result.abilities.shadowdive_appear and result.abilities.shadowdive_appear.events then
            local ev = result.abilities.shadowdive_appear.events[1]

            if ev then
                local original = ev.on_enter_custom
                local inherit = ev.inherit_from

                ev.on_enter_custom = function(ability_event_handler, event)
                    if original then
                        pcall(original, ability_event_handler, event)
                    else
                        if inherit and result.abilities[inherit] and result.abilities[inherit].on_enter_custom then
                            pcall(result.abilities[inherit].on_enter_custom, ability_event_handler, event)
                        end
                    end

                    if math.random() < STORM_BOMB_FORCE then
                        local caster_unit = event.caster_unit
                        
                        -- Multiplayer safety: validate caster exists and is alive
                        if not caster_unit or not Unit.alive(caster_unit) then
                            return
                        end

                        if EntityAux.owned(caster_unit) then
                            local target_pos = (event.target_position_box and Vector3Aux.unbox(event.target_position_box)) or event.target_position

                            local command = TempTableFactory:get_map(
                                "ability_name", "storm_bomb",
                                "settings_path", "equipment/wizard/weapon03",
                                "target_position", target_pos
                            )

                            EntityAux.queue_command_master(caster_unit, "ability", "execute_ability", command)
                        end
                    end
                end
            end
        end

        if result.abilities.ghost_swarm then
            result.abilities.ghost_swarm.on_enter = result.abilities.ghost_swarm.on_enter or {}
            local original = result.abilities.ghost_swarm.on_enter.custom_callback

            result.abilities.ghost_swarm.on_enter.custom_callback = function(component, unit, ability_inst)
                if original then
                    pcall(original, component, unit, ability_inst)
                end

                if math.random() > STORM_BOMB_CHANCE then
                    return
                end

                if not StrongerEnemies.enabled then
                    return
                end

                local caster_unit = ability_inst.caster_unit or unit
                
                -- Multiplayer safety: validate caster exists and is alive
                if not caster_unit or not Unit.alive(caster_unit) then
                    return
                end

                if EntityAux.owned(caster_unit) then
                    local target_pos = (ability_inst.target_position_box and Vector3Aux.unbox(ability_inst.target_position_box)) or ability_inst.target_position

                    local command = TempTableFactory:get_map(
                        "ability_name", "storm_bomb",
                        "settings_path", "equipment/wizard/weapon03",
                        "target_position", target_pos
                    )

                    EntityAux.queue_command_master(caster_unit, "ability", "execute_ability", command)
                end
            end
        end

        if result.abilities.on_spawn_raise_skeletons then
            result.abilities.on_spawn_raise_skeletons.on_enter = result.abilities.on_spawn_raise_skeletons.on_enter or {}
            local original = result.abilities.on_spawn_raise_skeletons.on_enter.custom_callback

            result.abilities.on_spawn_raise_skeletons.on_enter.custom_callback = function(component, unit, ability_inst)
                if original then
                    pcall(original, component, unit, ability_inst)
                end

                if ability_inst.caster_unit then
                    if math.random() > STORM_BOMB_CHANCE then
                        return
                    end

                    if not StrongerEnemies.enabled then
                        return
                    end
                end

                local caster_unit = ability_inst.caster_unit or unit

                if EntityAux.owned(caster_unit) then
                    local target_pos = (ability_inst.target_position_box and Vector3Aux.unbox(ability_inst.target_position_box)) or ability_inst.target_position

                    local command = TempTableFactory:get_map(
                        "ability_name", "storm_bomb",
                        "settings_path", "equipment/wizard/weapon03",
                        "target_position", target_pos
                    )

                    EntityAux.queue_command_master(caster_unit, "ability", "execute_ability", command)
                end
            end
        end
    end

    return result
end)