-- =================================================================================================
-- Author: SavageDuck26
-- =================================================================================================

local MOD_NAME = "StrongerDemonHeavy"

local EYE_SORC_TARGET_RANGE = 45

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/demon_heavy/demon_heavy" and result and _G.is_host_ducks_mods then

        if result.abilities.super_nova_start.on_complete then
            result.abilities.super_nova_start.on_complete.custom_callback = function (ability_component, unit, ability)
                if not EntityAux.owned(unit) or not Unit.alive(unit) then
                    return
                end

                local command = TempTableFactory:get_map(
                    "ability_name", "sinister_orb",
                    "settings_path", "equipment/wizard/weapon02"
                )
                EntityAux.queue_command_master(unit, "ability", "execute_ability", command)

                if StrongerEnemies.enabled then
                    local command = TempTableFactory:get_map(
                        "ability_name", "sinister_orb_hover",
                        "settings_path", "equipment/wizard/weapon02"
                    )
                    EntityAux.queue_command_master(unit, "ability", "execute_ability", command)
                end
            end
        end

        if result.abilities.super_nova_event_data then
            result.abilities.super_nova_event_data.on_enter_custom = function (ability_event_handler, event)
                local owner = event.owner_unit

                if StrongerEnemies.enabled then
                    if not EntityAux.owned(owner) then
                        return
                    end

                    local angle = event.settings and event.settings.angle
                    local distance = event.settings and event.settings.max_distance or 15

                    local pose = AbilityEventAux.get_pose(event, false)
                    local origin = pose and Matrix4x4.translation(pose) or (Unit.world_position(owner, 0) + Vector3.up() * 1)
                    local forward = pose and Quaternion.forward(Matrix4x4.rotation(pose)) or Quaternion.forward(Unit.world_rotation(owner, 0))

                    local dir = nil

                    if angle ~= nil then
                        local rot = Quaternion(Vector3.up(), math.rad(angle))
                        dir = Quaternion.rotate(rot, forward)
                    elseif event.query_instance and event.query_instance.get_direction then
                        dir = event.query_instance:get_direction(event)
                    else
                        dir = forward
                    end

                    dir = Vector3.normalize(dir)

                    local target_pos = origin + dir * distance

                    local command = TempTableFactory:get_map(
                        "ability_name", "mortar_shot",
                        "settings_path", "equipment/elf/weapon03",
                        "target_position", Vector3Aux.box({}, target_pos)
                    )

                    EntityAux.queue_command_master(owner, "ability", "execute_ability", command)
                end
            end
        end

        if result.abilities.confusing_glare then
            result.abilities.confusing_glare.on_enter = {
                custom_callback = function (ability_component, unit, ability)
                    if EntityAux.owned(unit) then
                        local predicates = {
                            closure(StateAux.predicate_faction, FactionComponent.faction_mask("evil")),
                            function (component, caster, context, target_unit)
                                local settings = LuaSettingsManager:get_settings_by_unit(target_unit)
                                return settings and settings.enemy_type == "cultist_sorcerer"
                            end,
                            StateAux.predicate_line_of_sight_to_target,
                        }
                        
                        local target_unit = StateAux.get_random_target(ability_component, unit, nil, EYE_SORC_TARGET_RANGE, true, predicates)
                        
                        if target_unit then
                            local command = TempTableFactory:get_map(
                                "ability_name", "lightning_shield",
                                "settings_path", "equipment/wizard/weapon01",
                                "owner_unit", target_unit  -- This makes the shield owned by the cultist
                            )
                            EntityAux.queue_command_master(target_unit, "ability", "execute_ability", command)
                        end
                    end
                end
            }
        end

        if result.abilities.demon_egg then
            result.abilities.demon_egg.on_enter = {
                custom_callback = function (ability_component, unit, ability)
                    if EntityAux.owned(unit) then
                        local command = TempTableFactory:get_map(
                            "ability_name", "sinister_orb",
                            "settings_path", "equipment/wizard/weapon02"
                        )
                        EntityAux.queue_command_master(unit, "ability", "execute_ability", command)
                    end
                end
            }
        end
    end

    return result
end)