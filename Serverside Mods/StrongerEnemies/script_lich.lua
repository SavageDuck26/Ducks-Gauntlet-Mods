
local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Adds new abilities to the Lich"
local MOD_NAME, log_message = Mods.init_mod()

-- The bomb's spiral projectiles keep flying to max_time (270 frames = 9s) after the throw, so the
-- whole cast is capped at roughly 4 seconds.
local STORM_BOMB_CAP = 3

-- Chance the Lich throws a storm bomb on top of a cast; overridable from the mod UI.
local function storm_bomb_chance()
    return StrongerEnemies.get_chance("lich", "storm_bomb_chance", 0.12)
end

-- Chance the Lich drops a storm bomb when it dives in (normal mode, not nightmare).
local function shadowdive_bomb_chance()
    return StrongerEnemies.get_chance("lich", "shadowdive_bomb_chance", 1.00)
end

local function cast_storm_bomb(caster_unit, command)
    EntityAux.queue_command_master(caster_unit, "ability", "execute_ability", command)
    StrongerEnemies.end_ability_after(caster_unit, "storm_bomb", STORM_BOMB_CAP)
end

Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/lich/lich" and result and _G.is_host_ducks_mods then
        if result.abilities.raise_skeletons then
            result.abilities.raise_skeletons.on_enter = {
                custom_callback = function (ability_component, unit, ability)
                    if not StrongerEnemies.is_enabled("lich") or math.random() > storm_bomb_chance() then
                        return
                    end

                    if not StrongerEnemies.is_nightmare() then
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

                        cast_storm_bomb(caster_unit, command)
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

                    if StrongerEnemies.is_enabled("lich") and math.random() < storm_bomb_chance() then
                        if not StrongerEnemies.is_nightmare() then
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

                            cast_storm_bomb(caster_unit, command)
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

                    if StrongerEnemies.is_enabled("lich") and math.random() < storm_bomb_chance() then
                        if not StrongerEnemies.is_nightmare() then
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

                            cast_storm_bomb(caster_unit, command)
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

                    if StrongerEnemies.is_enabled("lich") and math.random() < storm_bomb_chance() then
                        if not StrongerEnemies.is_nightmare() then
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

                            cast_storm_bomb(caster_unit, command)
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

                    if StrongerEnemies.is_enabled("lich") and math.random() < shadowdive_bomb_chance() then
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

                            cast_storm_bomb(caster_unit, command)
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

                if not StrongerEnemies.is_enabled("lich") or math.random() > storm_bomb_chance() then
                    return
                end

                if not StrongerEnemies.is_nightmare() then
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

                    cast_storm_bomb(caster_unit, command)
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
                    if not StrongerEnemies.is_enabled("lich") or math.random() > storm_bomb_chance() then
                        return
                    end

                    if not StrongerEnemies.is_nightmare() then
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

                    cast_storm_bomb(caster_unit, command)
                end
            end
        end
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)