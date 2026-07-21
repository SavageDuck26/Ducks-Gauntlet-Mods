-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Adds spawning abilities to Grunt Shaman
-- =================================================================================================

local MOD_NAME = "SummonerGruntShaman"

-- Helper function to check if grunt_shaman summoning is enabled
local function is_grunt_shaman_enabled()
    if Summoners.CONFIG.enabled == false then
        return false
    end
    if Summoners.CONFIG.summoners and Summoners.CONFIG.summoners.grunt_shaman then
        return Summoners.CONFIG.summoners.grunt_shaman.enabled
    end
    return true
end

-- Helper function to get spawn chance
local function get_projectile_chance()
    if Summoners.CONFIG.summoners and Summoners.CONFIG.summoners.grunt_shaman then
        return Summoners.CONFIG.summoners.grunt_shaman.projectile_chance or 0.25
    end
    return 0.25
end

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/grunt_shaman/grunt_shaman" and result and _G.is_host_ducks_mods == true then

        if result.ability_selection then
            -- Replace buff_spawner with spawn_stone (does both buff + summon stone)
            result.ability_selection.buff_spawner = {
                cooldown = 200,
                range = 18,
                target_allies = true,
                use_target_unit = true,
                weight = 3,
                initial_cooldown = {
                    15,
                    30,
                },
                target_func = StateAux.get_random_target,
                predicates = {
                    closure(StateAux.predicate_unit_types, {
                        "spawner_caves_grunt",
                        "spawner_caves_grunt_t1",
                    }),
                    function (component, unit, context, target_unit)
                        local spawner_state = EntityAux.state(target_unit, "monster_spawner")

                        return not spawner_state.turbo_buffed
                    end,
                    StateAux.predicate_line_of_sight_to_target,
                },
            }

            -- Replace projectile with spawn_orc (does both projectile + summon orc)
            result.ability_selection.projectile = {
                cooldown = 5,
                max_distance = 18,
                min_distance = 1,
                request_execution = true,
                weight = 1,
                initial_cooldown = {
                    2,
                    4,
                },
            }
        end

        -- Add the actual ability definitions
        if result.abilities then
            -- buff_spawner that ALSO summons stone spawner
            result.abilities.buff_spawner = {
                animation = "ability_buff_spawner",
                mode = "infinite",
                flow_events = {
                    {
                        event_name = "on_buff_spawner_start",
                        time = 0,
                    },
                    {
                        event_name = "on_buff_spawner_cast",
                        time = 19,
                    },
                },
                on_enter = {
                    custom_callback = function (component, unit, ability)
                        local entity_spawner = FlowCallbacks.state_game.entity_spawner
                        local position = Unit.world_position(unit, 0)
                        local rotation = Unit.world_rotation(unit, 0)
                        
                        local spawn = entity_spawner:spawn_entity("spider_queen", position, rotation)
                        NetworkUnitSynchronizer:add(spawn)
                    end,
                },
                on_exit = {
                    animation_event = "ability_buff_spawner_exit",
                    flow_event = "on_buff_spawner_stop",
                },
                custom_update = function (component, unit, context, ability, dt)
                    if not EntityAux.owned(unit) then
                        return
                    end

                    local target_unit = ability.target_unit

                    if not DamageReceiverComponent.is_alive(target_unit) then
                        EntityAux.queue_command_master(unit, component.name, "interrupt")

                        return
                    end
                end,
                events = {
                    {
                        beam_effect = "effects/cha_grunt_shaman_turbo_beam",
                        event_start = 19,
                        length_max = 0.5,
                        length_min = 0,
                        node = "j_r_hand_attach",
                        pass_through_damageable = true,
                        target_type = "target_unit",
                        beam_target_offset = {
                            x = 0,
                            y = 0,
                            z = 1,
                        },
                        on_enter_custom = CommonEventsAux.beam_on_enter,
                        custom_update = CommonEventsAux.beam_update,
                        on_valid_hit = {
                            custom_callback = function (ability_event_handler, event, hit)
                                if EntityAux.owned(event.target_unit) then
                                    local temp = TempTableFactory:get_map("is_buffed", true)

                                    EntityAux.queue_command_master(event.target_unit, "monster_spawner", "turbo_buff", temp)
                                end
                            end,
                        },
                        on_exit_custom = function (ability_event_handler, event)
                            CommonEventsAux.beam_on_exit(ability_event_handler, event)

                            if Unit.alive(event.target_unit) and EntityAux.owned(event.target_unit) then
                                local temp = TempTableFactory:get_map("is_buffed", false)

                                EntityAux.queue_command_master(event.target_unit, "monster_spawner", "turbo_buff", temp)
                            end
                        end,
                    },
                },
            }
            
            -- projectile that ALSO summons orc
            result.abilities.projectile = {
                animation = "ability_homing_skull",
                duration = 135,
                rotation_lock_start = 20,
                flow_events = {
                    {
                        event_name = "on_projectile_windup",
                        time = 0,
                    },
                    {
                        event_name = "on_projectile_cast",
                        time = 39,
                    },
                },
                -- Original projectile events
                events = {
                    {
                        damage_amount = 10,
                        damage_type = "punch",
                        effect_type = "firebolt",
                        event_duration = 60,
                        event_start = 39,
                        hit_react = "tackle",
                        max_distance = 10,
                        radius = 0.5,
                        speed = 5,
                        stagger_origin_type = "direction",
                        type = "projectile",
                        unit_path = "grunt_shaman_projectile",
                        origin = {
                            x = 0,
                            y = 1,
                            z = 0,
                        },
                        on_event_complete = {
                            ability = "projectile_split",
                            condition = "max_distance_reached",
                            flow_event = "test",
                        },
                    },
                },
                on_enter = {
                    custom_callback = function(component, unit, ability)
                        if not is_grunt_shaman_enabled() then return end
                        if math.random() < get_projectile_chance() then
                            local entity_spawner = FlowCallbacks.state_game.entity_spawner
                            local position = Unit.world_position(unit, 0)
                            local rotation = Unit.world_rotation(unit, 0)
                            entity_spawner:spawn_entity(
                                "characters/grunt_shaman/abilities/homing_skull_projectile",
                                position,
                                rotation,
                                { spawn_info_key = "default" }
                            )
                        end
                    end,
                },
            }
        end
    end

    return result
end)