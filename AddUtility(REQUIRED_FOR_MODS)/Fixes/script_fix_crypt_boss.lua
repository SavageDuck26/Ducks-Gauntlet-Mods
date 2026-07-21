-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Fixes Crypt Boss for mods.
-- =================================================================================================

local MOD_NAME = "CryptBossOverride"

local is_crypt_boss_floor = false

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/menu/lobby_logic" then
        Mods.hook:set(MOD_NAME, "LobbyLogic.from_server_lobby_start_countdown", function (orig, self, server_peer_id, countdown_time, floor_id)
            orig(self, server_peer_id, countdown_time, floor_id)
            if floor_id == "crypt_floor_10" then
                is_crypt_boss_floor = true
            else
                is_crypt_boss_floor = false
            end
        end)
    end

    if (path == "characters/boss_mummy/boss_mummy" or path == "boss_mummy") and is_crypt_boss_floor == false and result then
        local t = {
            always_full_update_ai = true,
            animation_driven_movement = true,
            big_dude = true,
            blood_effect_node = "j_collarbone",
            bloodtype = "red",
            default_mover_collision_filter = "enemy_mover",
            disable_health_bar = true,
            discovery_disabled = true,
            enemy_type = "mummy_king",
            global_ability_cooldown = 15,
            hide_unit_on_spawn = false,
            hit_react_default = "default",
            intro_duration = 480,
            like_a_boss = true,
            max_damage = 300,
            motion_variables_from_enemy = true,
            movespeed = 0.7,
            name = "loc_enemy_mummy_king",
            simple_mover_radius = 1.75,
            static_lighting_wait_time = 7,
            stopping_power = 10,
            time_before_decay = 60,
            faction = {
                "evil",
            },
            hitpoints = {
                640,
                1280,
                1920,
                2560,
            },
            random_movespeed_range = {
                1,
                1,
            },
            resistances = {
                all = "immune",
            },
            resistance_exceptions = {
                bossheart_damage = true,
            },
            aim_constraint_info = {
                look_target = {
                    catch_up_turn_speed = 10,
                    constraint_target = "look_target",
                    max_angle = 80,
                    turn_speed = 10,
                    offset = {
                        x = 0,
                        y = 0,
                        z = 7,
                    },
                },
            },
            hit_reacts = {
                default = {
                    blood_pitch = 0,
                    blood_pitch_variation = 0,
                    decal_pitch = -20,
                    decal_pitch_variation = 0,
                    yaw = 180,
                    yaw_variation = 10,
                    hit = {
                        animation_event = "hit_chestburst",
                    },
                    death = {
                        generic = {
                            animation_event = "die",
                            flow_event = "die",
                            weight = 1,
                        },
                    },
                },
            },
            stage_infos = {
                {
                    ability = "bash",
                    ability_selection = "ability_selection_2",
                    animation_speed_multiplier = 1.4,
                    duration = 80,
                    enter_hp_limit = 65,
                    global_ability_cooldown = 10,
                    pre_selected_abilities = {
                        "raise_mummies",
                    },
                },
                {
                    ability = "bash",
                    ability_selection = "ability_selection_3",
                    animation_speed_multiplier = 1.7,
                    duration = 80,
                    enter_hp_limit = 35,
                    global_ability_cooldown = 5,
                    pre_selected_abilities = {
                        "raise_mummies",
                    },
                },
            },
            pre_selected_abilities = {
                "raise_mummies",
            },
            ability_selection = {
                bash = {
                    cooldown = 20,
                    max_distance = 50,
                    min_distance = 0,
                    weight = 0.8,
                },
            },
            ability_selection_2 = {
                bash = {
                    cooldown = 20,
                    max_distance = 50,
                    min_distance = 0,
                    weight = 0.8,
                },
            },
            ability_selection_3 = {
                bash = {
                    cooldown = 20,
                    max_distance = 50,
                    min_distance = 0,
                    weight = 0.8,
                },
            },
            abilities = {
                default_event_data = {
                    damage_amount = 1,
                    damage_type = "slash",
                    effect_type = "axe",
                    event_data = true,
                    event_duration = 1,
                    event_start = 15,
                    friendly_fire = true,
                    hit_react = "heavy",
                    type = "box",
                    origin = {
                        x = 0,
                        y = 0.5,
                        z = 0,
                    },
                    half_extents = {
                        x = 0.6,
                        y = 0.4,
                        z = 0.5,
                    },
                    ignore_block = {
                        hit_react = true,
                        shock_receiver = true,
                    },
                },
                stomp = {
                    animation = "attack_stomp",
                    duration = 30,
                    rotation_lock_start = 0,
                    flow_events = {
                        {
                            event_name = "ability_stomp",
                            time = 0,
                        },
                    },
                    events = {
                        {
                            collision_filter = "damageable_only",
                            damage_amount = 128,
                            damage_type = "punch",
                            event_duration = 1,
                            event_start = 5,
                            hit_react = "explosion",
                            inherit_from = "default_event_data",
                            origin_type = "center",
                            radius = 3,
                            stagger_origin_type = "character",
                            type = "sphere",
                            origin = {
                                x = -1,
                                y = 1,
                                z = 0,
                            },
                        },
                    },
                },
                bash = {
                    animation = "ability_fissure",
                    duration = 89,
                    rotation_lock_start = 0,
                    events = {
                        {
                            collision_filter = "damageable_only",
                            damage_amount = 128,
                            damage_type = "punch",
                            event_duration = 1,
                            event_start = 54,
                            friendly_fire = true,
                            hit_react = "explosion",
                            inherit_from = "default_event_data",
                            on_enter_flow = "ability_bash",
                            origin_type = "center",
                            stagger_origin_type = "character",
                            type = "box",
                            origin = {
                                x = 0,
                                y = 3,
                                z = 0,
                            },
                            half_extents = {
                                x = 2,
                                y = 2,
                                z = 2,
                            },
                        },
                    },
                },
                nuke_event = {
                    collision_filter = "damageable_only",
                    damage_amount = 1000,
                    event_data = true,
                    event_duration = 1,
                    friendly_fire = true,
                    hit_react = "explosion",
                    only_friendly_fire = true,
                    origin_type = "center",
                    target_position_as_origin = true,
                    type = "box",
                    origin = {
                        x = 0,
                        y = 0,
                        z = 0,
                    },
                    half_extents = {
                        x = 5,
                        y = 5,
                        z = 5,
                    },
                },
                nuke = {
                    duration = 70,
                    target_type = "allies",
                    events = {
                        {
                            event_start = 45,
                            inherit_from = "nuke_event",
                            half_extents = {
                                x = 3,
                                y = 3,
                                z = 3,
                            },
                        },
                        {
                            event_start = 48,
                            inherit_from = "nuke_event",
                            half_extents = {
                                x = 7,
                                y = 7,
                                z = 3,
                            },
                        },
                        {
                            event_start = 51,
                            inherit_from = "nuke_event",
                            half_extents = {
                                x = 11,
                                y = 11,
                                z = 3,
                            },
                        },
                        {
                            event_start = 54,
                            inherit_from = "nuke_event",
                            half_extents = {
                                x = 15,
                                y = 15,
                                z = 3,
                            },
                        },
                        {
                            event_start = 57,
                            inherit_from = "nuke_event",
                            half_extents = {
                                x = 20,
                                y = 20,
                                z = 3,
                            },
                        },
                        {
                            event_start = 60,
                            inherit_from = "nuke_event",
                            half_extents = {
                                x = 50,
                                y = 50,
                                z = 3,
                            },
                        },
                    },
                },
                small_impact_event = {
                    collision_filter = "damageable_only",
                    damage_amount = 16,
                    damage_type = "shieldbash",
                    event_data = true,
                    event_duration = 1,
                    event_start = 0,
                    friendly_fire = true,
                    hit_react = "tackle",
                    inherit_from = "default_event_data",
                    node_use_root_rotation = true,
                    on_enter_flow = "ability_small_impact",
                    origin_type = "center",
                    stagger_origin_type = "character",
                    type = "box",
                    origin = {
                        x = 0,
                        y = 0,
                        z = 0,
                    },
                    half_extents = {
                        x = 1,
                        y = 1,
                        z = 1,
                    },
                    on_enter_custom = function (ability_event_handler, event)
                        local unit = event.caster_unit

                        Unit.set_flow_variable(unit, "impact_node", event.settings.node)
                        Unit.flow_event(unit, "impact")
                    end,
                },
                step_generic = {
                    duration = 1,
                    rotation_lock_start = 0,
                    events = {
                        {
                            inherit_from = "small_impact_event",
                        },
                    },
                },
                step_left = {
                    inherit_from = "step_generic",
                    events = {
                        {
                            node = "j_l_ball",
                        },
                    },
                },
                step_right = {
                    inherit_from = "step_generic",
                    events = {
                        {
                            node = "j_r_ball",
                        },
                    },
                },
                raise_mummies = {
                    animation = "ability_summon",
                    duration = 70,
                    rotation_lock_start = 1,
                    flow_events = {
                        {
                            event_name = "spawn_spawners",
                            time = 28,
                        },
                    },
                },
                tantrum_data = {
                    ability_data = true,
                    rotation_lock_start = 20,
                    on_enter = {
                        animation_event = "floor_bash",
                        flow_event = "ability_tantrum",
                    },
                    events = {
                        {
                            event_start = 39,
                            inherit_from = "small_impact_event",
                            node = "j_r_hand_attach",
                            loop = {
                                count = 3,
                                frequency = 30,
                            },
                        },
                        {
                            event_start = 54,
                            inherit_from = "small_impact_event",
                            node = "j_l_hand_attach",
                            loop = {
                                count = 3,
                                frequency = 30,
                            },
                        },
                    },
                    spawn_entities = {
                        {
                            spawn_info_key = "summon",
                            time = 24,
                            time_interval = 15,
                            unit_path = "characters/boss_mummy/abilities/fallingrock",
                            use_target_unit = true,
                            random_position_offset = {
                                max_radius = 15,
                                min_radius = 0,
                            },
                        },
                        {
                            spawn_info_key = "summon",
                            time = 24,
                            time_interval = 15,
                            unit_path = "characters/boss_mummy/abilities/fallingrock",
                            use_target_unit = true,
                            random_position_offset = {
                                max_radius = 5,
                                min_radius = 0,
                            },
                        },
                    },
                },
                tantrum = {
                    duration = 120,
                    inherit_from = "tantrum_data",
                    animation_events = {
                        {
                            event_name = "floor_bash_exit",
                            time = 100,
                        },
                    },
                },
                tantrum_tier2 = {
                    duration = 150,
                    inherit_from = "tantrum_data",
                    animation_events = {
                        {
                            event_name = "floor_bash_exit",
                            time = 130,
                        },
                    },
                },
                tantrum_tier3 = {
                    duration = 185,
                    inherit_from = "tantrum_data",
                    spawn_entities = {
                        {
                            spawn_info_key = "summon",
                            time = 24,
                            time_interval = 15,
                            unit_path = "characters/boss_mummy/abilities/fallingrock",
                            use_target_unit = true,
                            random_position_offset = {
                                max_radius = 15,
                                min_radius = 0,
                            },
                        },
                        {
                            spawn_info_key = "summon",
                            time = 24,
                            time_interval = 15,
                            unit_path = "characters/boss_mummy/abilities/fallingrock",
                            use_target_unit = true,
                            random_position_offset = {
                                max_radius = 5,
                                min_radius = 0,
                            },
                        },
                        {
                            spawn_info_key = "summon",
                            time = 24,
                            time_interval = 15,
                            unit_path = "characters/boss_mummy/abilities/fallingrock",
                            use_target_unit = true,
                        },
                    },
                    animation_events = {
                        {
                            event_name = "floor_bash_exit",
                            time = 165,
                        },
                    },
                },
                spawn_heart = {
                    animation = "chestburst",
                    duration = 149,
                    rotation_lock_start = 0,
                    spawn_entities = {
                        {
                            node = "j_spine2",
                            time = 80,
                            unit_path = "boss_mummy_heart",
                            custom_callback = function (abilty_event_handler, ability_info, entity)
                                local caster_unit = ability_info.caster_unit

                                Unit.set_data(caster_unit, "heart_unit", entity)
                            end,
                        },
                    },
                },
            },
        }

        t.heart_explosion = function (unit, circle_unit, context)

        end

        t.on_entity_registered = function (unit)
            local boss_data = {
                play_footstep_effect = function (self, params)
                    if Unit.is_a(params.unit, "characters/boss_mummy/boss_mummy") then
                        local right_foot = params["node?"] == "j_r_ball"
                        local ability_id = 0
                        local command = TempTableFactory:get_map("ability_name", right_foot and "step_right" or "step_left", "execute_local_only", true, "ability_id", ability_id)

                        EntityAux.queue_command(params.unit, "ability", "execute_ability", command)

                        local state = EntityAux._state_master_raw(params.unit, "enemy")

                        if state then
                            state.should_update_legs_angle = true
                        end
                    end
                end,
            }
            
            -- ==============================================================================================
            -- Store the boss_data on the unit so it can be retrieved later
            Unit.set_data(unit, "boss_data", boss_data)
            -- Register the callback with the flow router
            FlowCallbacks.state_game.flow_router:register(boss_data, "play_footstep_effect")
            
            -- Force the boss to wake up and enter battle state
            if EntityAux.owned(unit) then
                EntityAux.call_master(unit, "enemy", "change_state", "battle")
            end
        end

        t.on_entity_unregistering = function (unit)
            local boss_data = Unit.get_data(unit, "boss_data")

            if boss_data then
                FlowCallbacks.state_game.flow_router:unregister(boss_data, "play_footstep_effect")
            else
                local empty
            end
        end
        -- ==================================================================================================
        t.on_death_notified = function (unit)
            local perk_id = "the_undeath_of_khamun"

            for player_go_id, player_info in PlayerManager:local_players_iterator() do
                PerkManager:increase_count_to(player_go_id, perk_id, 1)
            end

            StateAux.nuke_all_enemies(FlowCallbacks.state_game.entity_manager)
        end

        t.start_state = "idle"

        t.states = function (component)
            local cache_component_states = closure(StateCommon.cache_component_states, component)

            return {
                setup = StateCommonBuilder.build_skip_state(component, t.start_state),
                spawn = StateCommonBuilder.build_spawn_state(component, closure(StateBoss.compulsory_checks, component)),
                select_action = StateCommonBuilder.build_skip_state(component, "battle"),
                idle = {
                    on_enter = {},
                    update = {},
                    post_transitions = {
                        {
                            next_state = "intro",
                            action = closure(StateBoss.should_start, component),
                        },
                    },
                    on_exit = {},
                },
                intro = {
                    on_enter = {
                        closure(StateBoss.intro_enter, component),
                    },
                    update = {},
                    post_transitions = {
                        {
                            next_state = "battle",
                            action = closure(StateBoss.intro_should_exit, component),
                        },
                    },
                    on_exit = {
                        closure(StateBoss.intro_exit, component),
                    },
                },
                battle = {
                    on_enter = {
                        closure(StateMummyBoss.move_enter, component),
                    },
                    update = {
                        closure(StateCommon.select_target_player, component),
                        closure(StateBoss.update_aimconstraint, component),
                        closure(StateBoss.update_legs_angle, component),
                        closure(StateMummyBoss.move_update, component),
                    },
                    pre_transitions = {
                        {
                            action = closure(StateBoss.compulsory_checks, component),
                        },
                    },
                    post_transitions = {
                        {
                            next_state = "stagechange",
                            action = closure(StateBoss.stagechange_should_enter, component),
                        },
                        {
                            action = closure(StateCommon.select_random_ability, component),
                        },
                        {
                            next_state = "attack",
                            action = closure(StateMummyBoss.check_stomp, component),
                        },
                    },
                    on_exit = {
                        closure(StateBoss.battle_exit, component),
                    },
                },
                attack = {
                    on_enter = {
                        closure(StateCommon.attack_enter, component),
                    },
                    pre_transitions = {
                        {
                            action = closure(StateBoss.compulsory_checks, component),
                        },
                    },
                    update = {},
                    post_transitions = {
                        {
                            next_state = "battle",
                            action = closure(StateCommon.attack_update, component),
                        },
                    },
                    on_exit = {},
                },
                heart = {
                    on_enter = {
                        closure(StateMummyBoss.heart_enter, component),
                    },
                    update = {
                        closure(StateBoss.update_aimconstraint, component),
                        closure(StateBoss.wanted_translation_update, component),
                    },
                    pre_transitions = {
                        {
                            action = closure(StateBoss.compulsory_checks, component),
                        },
                    },
                    post_transitions = {
                        {
                            next_state = "battle",
                            action = StateCommon.setup_sequence({
                                closure(StateMummyBoss.heart_explosion, component),
                                closure(StateCommon.wait_for_animation, component),
                                closure(StateMummyBoss.wait_for_heart_return, component),
                                closure(StateCommon.wait_for_animation, component),
                            }),
                        },
                    },
                    on_exit = {
                        closure(StateMummyBoss.heart_exit, component),
                    },
                },
                stagechange = {
                    on_enter = {
                        closure(StateBoss.stagechange_enter, component),
                    },
                    update = {},
                    post_transitions = {
                        {
                            next_state = "battle",
                            action = closure(StateBoss.stagechange_should_exit, component),
                        },
                    },
                    on_exit = {},
                },
                incapacitated = {
                    on_enter = {
                        closure(StateMummyBoss.incapacitated_enter, component),
                    },
                    update = {},
                    pre_transitions = {
                        {
                            action = closure(StateBoss.compulsory_checks, component),
                        },
                    },
                    post_transitions = {
                        {
                            next_state = "battle",
                            action = closure(StateMummyBoss.incapacitated_should_exit, component),
                        },
                    },
                    on_exit = {},
                },
                decay = StateCommonBuilder.build_decay_state(component),
            }, cache_component_states
        end

        return t
    end

    return result
end)
