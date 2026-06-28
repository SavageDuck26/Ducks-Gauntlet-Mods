-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Fixes issues with Homing Skull behavior
-- =================================================================================================

local MOD_NAME = "FixHomingSkull"

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/grunt_shaman/abilities/homing_skull_projectile" and result and _G.is_host_ducks_mods == true then

        if result.scale_info then
            result.scale_info.scale = 0.6 -- 1 is base scale
        end
        if result.lifetime then
            result.lifetime = 8 -- 16 is base
        end

        -- Override the states function
        result.states = function(component)
            local function hunting_local(component, unit, context, dt)
                -- Copy of the global hunting function
                local settings = context.settings
                local state = context.state
                local next_target_select_time = state.next_target_select_time or 0

                if next_target_select_time < _G.GAME_TIME then
                    if state.target_unit and not DamageReceiverComponent.is_alive(state.target_unit) then
                        state.target_unit = nil
                    end

                    if state.target_unit == nil then
                        local new_target_unit
                        for go_id, player_info in PlayerManager:avatars_iterator() do
                            local avatar_unit = player_info.avatar_unit
                            if DamageReceiverComponent.is_alive(avatar_unit) then
                                new_target_unit = avatar_unit
                                break
                            end
                        end
                        state.target_unit = new_target_unit
                        if not new_target_unit then
                        end
                    end

                    state.next_target_select_time = _G.GAME_TIME + 1
                end

                if not state.target_unit then
                    return
                end

                local current_pos = Unit.world_position(unit, 0)
                local to_target = Unit.world_position(state.target_unit, 0) - current_pos
                to_target.z = to_target.z + TargetAlignmentAux.AIM_HEIGHT

                local wanted_direction = Vector3.normalize(to_target)
                local motion_info = settings.motion_info
                local speed = motion_info.movespeed_max * 1.5  -- 4 is base speed
                local velocity = wanted_direction * speed

                if EntityAux.owned(unit) then
                    EntityAux.queue_command_master(unit, "motion", "set_velocity", velocity)
                    EntityAux.queue_command_master(unit, "rotation", "rotate_towards", wanted_direction)
                    -- print("[Homing Skull] Set velocity: " .. tostring(velocity) .. ", Position: " .. tostring(current_pos))
                else
                    -- print("[Homing Skull] Not owned - skipping motion")
                end
            end

            return {
                hunt = {
                    on_enter = {
                        closure(function(component, unit, context)
                            local command = TempTableFactory:get_map("ability_name", "collide")
                            EntityAux.queue_command_master(unit, "ability", "execute_ability", command)
                            EntityAux.queue_command_master(unit, "motion", "set_max_speed", 8) -- Speed here
                            context.state.time_to_die = _G.GAME_TIME + context.settings.lifetime
                        end, component),
                    },
                    update = {
                        closure(hunting_local, component),
                    },
                    pre_transitions = {
                        {
                            next_state = "dead",
                            action = closure(function(component, unit, context)
                                local state = context.state
                                local dying = _G.GAME_TIME >= state.time_to_die
                                if dying then
                                end
                                return dying
                            end, component),
                        },
                    },
                    post_transitions = {},
                    on_exit = {},
                },
                dead = {
                    on_enter = {
                        closure(function(component, unit, context)
                            local command = TempTableFactory:get_map("ability_name", "expire")
                            EntityAux.queue_command_master(unit, "ability", "execute_ability", command)
                        end, component),
                    },
                    update = {},
                    post_transitions = {},
                    on_exit = {},
                },
            }
        end
    end
    -- Diff changes for same thing
    local function hunting(component, unit, context, dt)
        local settings = context.settings
        local state = context.state
        local next_target_select_time = state.next_target_select_time or 0

        if next_target_select_time < _G.GAME_TIME then
            if state.target_unit and not DamageReceiverComponent.is_alive(state.target_unit) then
                state.target_unit = nil
            end

            if state.target_unit == nil then
                -- Pick the first alive player, no checks
                local new_target_unit
                for go_id, player_info in PlayerManager:avatars_iterator() do
                    local avatar_unit = player_info.avatar_unit
                    if DamageReceiverComponent.is_alive(avatar_unit) then
                        new_target_unit = avatar_unit
                        break
                    end
                end
                state.target_unit = new_target_unit
                if not new_target_unit then
                end
            end

            state.next_target_select_time = _G.GAME_TIME + 1  -- Frequent updates for aggression
        end

        if not state.target_unit then
            return
        end

        local current_pos = Unit.world_position(unit, 0)
        local to_target = Unit.world_position(state.target_unit, 0) - current_pos
        to_target.z = to_target.z + TargetAlignmentAux.AIM_HEIGHT

        local wanted_direction = Vector3.normalize(to_target)
        local motion_info = settings.motion_info
        local speed = motion_info.movespeed_max  -- Use max speed for aggression
        local velocity = wanted_direction * speed

        -- Only apply motion if owned (required for commands to execute)
        if EntityAux.owned(unit) then
            EntityAux.queue_command_master(unit, "motion", "set_velocity", velocity)
            EntityAux.queue_command_master(unit, "rotation", "rotate_towards", wanted_direction)
            print("[Homing Skull] Set velocity: " .. tostring(velocity) .. ", Position: " .. tostring(current_pos))
        else
            print("[Homing Skull] Not owned - skipping motion")
        end

    end
    return result
end)