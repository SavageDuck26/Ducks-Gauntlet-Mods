
local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Fixes issues with Homing Skull behavior"


local MOD_NAME, log_message = Mods.init_mod()

-- The skull is built on ghost_enemy_base (can_move_though_walls = true) and its collide event only
-- queries "damageable_only", so walls are never part of the hit query: nothing ever reports the
-- collision and the skull flies straight through geometry. An invincible target is missing from the
-- same query for a different reason -- BaseDamageReceiverComponent moves the a_damageable actor to
-- the "damageable_disabled" filter while invincible -- so a shielded player is never reported as a
-- hit either and the skull keeps circling them until its lifetime runs out. Both are caught here.
-- 0.6m is several frames of travel (the skull covers ~0.13m per frame), which is enough to catch a
-- wall it is flying into without killing it for merely flying alongside one.
local WALL_PROBE_LENGTH = 0.6
local TOUCH_RADIUS = 1.2

-- TargetAlignmentAux.raycast is the engine's own statics-only "what is in the way" raycast.
local function has_hit_wall(component, unit)
    return TargetAlignmentAux.raycast(component.world_proxy, Unit.world_position(unit, 0), UnitAux.unit_forward(unit), WALL_PROBE_LENGTH)
end

-- Physics cannot answer this while the avatar is invincible, so measure against the avatars the
-- skull is already hunting. Ground-plane distance only, because the skull flies at the aim height.
local function has_touched_avatar(unit)
    local position = Unit.world_position(unit, 0)

    for go_id, player_info in PlayerManager:avatars_iterator() do
        local avatar_unit = player_info.avatar_unit

        if DamageReceiverComponent.is_alive(avatar_unit) then
            local distance_sq = Vector3.distance_xy_squared(Unit.world_position(avatar_unit, 0), position)

            if distance_sq < TOUCH_RADIUS * TOUCH_RADIUS then
                return true
            end
        end
    end

    return false
end

-- The same death the skull already takes on a damageable hit (t.on_hit in its settings). The
-- modifier is dropped first so a hit arriving in the same frame cannot fire it twice.
local function destroy(component, unit)
    EntityEventModifierManager:unregister_modifier(unit, "on_hit_dealt", "shaman_projectile")
    component:trigger_rpc_event("rpc_destroy_ghost", unit, "on_death")
end

Mods.hook:set_object(_G, "require", function(orig, path, ...)
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

                -- Checked before the target logic so a skull that has lost its target still dies on
                -- the wall it is drifting into. Only the owning peer despawns it, the way every other
                -- projectile is removed.
                if EntityAux.owned(unit) and (has_hit_wall(component, unit) or has_touched_avatar(unit)) then
                    destroy(component, unit)

                    return
                end

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
                                return _G.GAME_TIME >= context.state.time_to_die
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
    return result
end, MOD_NAME .. ".require", MOD_NAME)