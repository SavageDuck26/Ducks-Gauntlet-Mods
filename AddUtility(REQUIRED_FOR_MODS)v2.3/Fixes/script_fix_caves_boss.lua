-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Fixes Caves Boss for mods.
-- =================================================================================================

local MOD_NAME = "CavesBossOverride"

local is_caves_boss_floor = false

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/menu/lobby_logic" then
        Mods.hook:set(MOD_NAME, "LobbyLogic.from_server_lobby_start_countdown", function (orig, self, server_peer_id, countdown_time, floor_id)
            orig(self, server_peer_id, countdown_time, floor_id)
            if floor_id == "caves_floor_10" then
                is_caves_boss_floor = true
                require("lua/ai_states/state_drakh_boss")
            else
                is_caves_boss_floor = false
                require("lua/ai_states/state_drakh_boss")
            end
        end)
    end

    if (path == "characters/boss_orox/boss_orox" or path == "boss_orox") and is_caves_boss_floor == false and result then
        local t = {
            always_full_update_ai = true,
            always_ignore_knockbacks = true,
            animation_driven_movement = true,
            big_dude = true,
            blood_effect_node = "j_collarbone",
            bloodtype = "red",
            default_mover_collision_filter = "enemy_mover",
            disable_health_bar = true,
            discovery_disabled = true,
            enemy_type = "beast_of_orox",
            enraged_time = 15,
            global_ability_cooldown = 2,
            hit_react_default = "default",
            ignore_interrupt = true,
            intro_duration = 170,
            like_a_boss = true,
            motion_variables_from_enemy = true,
            movespeed = 7,
            name = "loc_enemy_beast_of_orox",
            override_difficulty_speed = 1,
            rotationspeed = 1,
            simple_mover_radius = 1.75,
            static_lighting_wait_time = 7,
            stopping_power = 10,
            time_before_decay = 60,
            scale_info = {
                scale = 1.5,
                variation = 0.05,
            },
            faction = {
                "evil",
            },
            hitpoints = {
                320, -- Quartered
                480, -- Quartered
                640, -- Quartered
                800, -- Quartered
            },
            random_movespeed_range = {
                0,
                0,
            },
            resistance_exceptions = {
                croc_crusher = true,
            },
            resistances = {},
            target_lock_info = {
                base_radius_multiplier = 0.25,
                head_radius_multiplier = 0.25,
            },
            arrow_attach_joints = {
                "j_hips",
                "j_l_thigh",
                "j_r_thigh",
                "j_l_knee",
                "j_r_knee",
                "j_spine1",
                "j_spine2",
                "j_spine3",
            },
            aim_constraint_info = {
                look_target = {
                    constraint_target = "look_target",
                    max_angle = 100,
                    turn_speed = 15,
                    offset = {
                        x = 0,
                        y = 0,
                        z = 3,
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
                        animation_event = "hit",
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
                    ability = "roar",
                    ability_selection = "ability_selection",
                    duration = 60,
                    enter_hp_limit = 80,
                    global_ability_cooldown = 1.5,
                    movespeed_multiplier = 1,
                },
                {
                    ability = "roar",
                    ability_selection = "ability_selection_stage2",
                    duration = 60,
                    enter_hp_limit = 60,
                    global_ability_cooldown = 1.5,
                    movespeed_multiplier = 1,
                },
                {
                    ability = "roar",
                    ability_selection = "ability_selection_stage3",
                    duration = 60,
                    enter_hp_limit = 40,
                    global_ability_cooldown = 1.5,
                    movespeed_multiplier = 1,
                },
                {
                    ability = "roar",
                    ability_selection = "ability_selection_stage4",
                    duration = 60,
                    enter_hp_limit = 20,
                    global_ability_cooldown = 1.5,
                    movespeed_multiplier = 1,
                },
            },
            ability_selection = {
                chomp = {
                    cooldown = 6,
                    weight = 10,
                    target_func = StateAux.get_closest_target,
                    predicates = {
                        partial(StateAux.predicate_within_range, 0, 15),
                    },
                },
                charge = {
                    cooldown = 6,
                    next_state = "charge",
                    range = 50,
                    weight = 1000,
                    target_func = StateAux.get_best_target,
                    predicates = {
                        partial(StateAux.predicate_within_range, 15, 50),
                    },
                    desirability_funcs = {
                        StateAux.normalized_range,
                    },
                    desirability_mixer = function (range)
                        return range
                    end,
                },
                summon_dwellers = {
                    cooldown = 10,
                    max_distance = 50,
                    min_distance = 0,
                    next_state = "summon_minions",
                    weight = 100,
                },
            },
            ability_selection_stage2 = {
                chomp = {
                    cooldown = 5,
                    weight = 10,
                    target_func = StateAux.get_closest_target,
                    predicates = {
                        partial(StateAux.predicate_within_range, 0, 15),
                    },
                },
                charge = {
                    cooldown = 6,
                    next_state = "charge",
                    range = 50,
                    weight = 1000,
                    target_func = StateAux.get_best_target,
                    predicates = {
                        partial(StateAux.predicate_within_range, 15, 50),
                    },
                    desirability_funcs = {
                        StateAux.normalized_range,
                    },
                    desirability_mixer = function (range)
                        return range
                    end,
                },
                summon_dwellers = {
                    cooldown = 10,
                    max_distance = 50,
                    min_distance = 0,
                    next_state = "summon_minions",
                    weight = 100,
                },
            },
            ability_selection_stage3 = {
                chomp = {
                    cooldown = 4,
                    weight = 10,
                    target_func = StateAux.get_closest_target,
                    predicates = {
                        partial(StateAux.predicate_within_range, 0, 15),
                    },
                },
                charge = {
                    cooldown = 5,
                    next_state = "charge",
                    range = 50,
                    weight = 1000,
                    target_func = StateAux.get_best_target,
                    predicates = {
                        partial(StateAux.predicate_within_range, 12, 50),
                    },
                    desirability_funcs = {
                        StateAux.normalized_range,
                    },
                    desirability_mixer = function (range)
                        return range
                    end,
                },
                summon_dwellers = {
                    cooldown = 8,
                    max_distance = 50,
                    min_distance = 0,
                    next_state = "summon_minions",
                    weight = 100,
                },
            },
            ability_selection_stage4 = {
                chomp = {
                    cooldown = 3,
                    weight = 10,
                    target_func = StateAux.get_closest_target,
                    predicates = {
                        partial(StateAux.predicate_within_range, 0, 15),
                    },
                },
                charge = {
                    cooldown = 4,
                    next_state = "charge",
                    range = 50,
                    weight = 1000,
                    target_func = StateAux.get_best_target,
                    predicates = {
                        partial(StateAux.predicate_within_range, 10, 50),
                    },
                    desirability_funcs = {
                        StateAux.normalized_range,
                    },
                    desirability_mixer = function (range)
                        return range
                    end,
                },
                summon_dwellers = {
                    cooldown = 8,
                    max_distance = 50,
                    min_distance = 0,
                    next_state = "summon_minions",
                    weight = 100,
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
                    hit_react = "tackle",
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
                },
                roar = {
                    animation = "ability_roar",
                    duration = 30,
                    flow_events = {
                        {
                            event_name = "ability_roar",
                            time = 0,
                        },
                    },
                },
                leap_smash = {
                    animation = "ability_roar",
                    constrain_target_position_to_navgrid = true,
                    duration = 120,
                    ignore_interrupt = true,
                    rotation_lock_start = 1,
                    animation_events = {
                        {
                            event_name = "ability_jump",
                            time = 30,
                        },
                    },
                    extract_target_position = {
                        node = "root",
                    },
                    custom_movement = {
                        duration = 20,
                        start = 40,
                    },
                    flow_events = {
                        {
                            event_name = "on_leap_smash_impact",
                            time = 60,
                        },
                    },
                    events = {
                        {
                            event_duration = 1,
                            event_start = 1,
                            target_position_as_origin = true,
                            on_enter_custom = function (ability_event_handler, event)
                                local target_position = Vector3Aux.unbox(event.target_position_box)
                                local unit = event.caster_unit

                                Unit.set_flow_variable(unit, "leap_smash_target_position", target_position)
                                Unit.flow_event(unit, "on_leap_smash_start")
                            end,
                        },
                        {
                            can_be_reflected = false,
                            damage_amount = 128,
                            damage_type = "punch",
                            event_duration = 2,
                            event_start = 60,
                            friendly_fire = true,
                            hit_react = "explosion",
                            origin_type = "center",
                            radius = 5,
                            target_position_as_origin = true,
                            type = "sphere",
                            origin = {
                                x = 0,
                                y = 0,
                                z = 0,
                            },
                            ignore_block = {
                                hit_react = true,
                                shock_receiver = true,
                            },
                        },
                    },
                    invincibilities = {
                        {
                            window = {
                                40,
                                60,
                            },
                        },
                    },
                },
                chomp = {
                    animation = "attack_chomp",
                    animation_driven_movement = false,
                    duration = 55,
                    enemy_collisions = "disable",
                    ignore_interrupt = true,
                    override_mover_filter = "level_bound_mover",
                    rotation_lock_start = 5,
                    flow_events = {
                        {
                            event_name = "ability_chomp",
                            time = 0,
                        },
                    },
                    events = {
                        {
                            can_be_reflected = false,
                            damage_amount = 16,
                            damage_type = "slash",
                            effect_type = "tackle",
                            event_duration = 20,
                            event_start = 30,
                            friendly_fire = true,
                            hit_react = "shockwave",
                            on_exit_flow = "ability_chomp_stop",
                            tick_frequency = 60,
                            type = "box",
                            origin = {
                                x = 0,
                                y = 2,
                                z = 1,
                            },
                            half_extents = {
                                x = 2.2,
                                y = 1,
                                z = 0.5,
                            },
                            ignore_block = {
                                hit_react = true,
                                shock_receiver = true,
                            },
                        },
                    },
                    movements = {
                        {
                            translation = 15,
                            window = {
                                30,
                                47,
                            },
                        },
                    },
                },
                summon_dwellers = {
                    animation = "ability_roar",
                    duration = 60,
                    rotation_lock_start = 0,
                },
                charge = {
                    animation = "charge_initiate",
                    ignore_shock = true,
                    mode = "infinite",
                    events = {
                        {
                            can_be_reflected = false,
                            damage_amount = 16,
                            event_start = 29,
                            friendly_fire = true,
                            hit_react = "tackle",
                            inherit_from = "default_event_data",
                            tick_frequency = 60,
                            type = "box",
                            origin = {
                                x = 0,
                                y = 0.5,
                                z = 0,
                            },
                            half_extents = {
                                x = 2,
                                y = 1,
                                z = 2,
                            },
                            ignore_block = {
                                hit_react = true,
                                shock_receiver = true,
                            },
                            on_exit = {
                                animation_event = "charge_exit",
                            },
                        },
                    },
                },
                push_others = {
                    enemy_collisions = "disable",
                    mode = "infinite",
                    set_as_busy = false,
                    target_type = "allies",
                    events = {
                        {
                            event_start = 1,
                            hit_react = "push",
                            only_friendly_fire = true,
                            refresh_hitlist_time = 1,
                            type = "box",
                            origin = {
                                x = 0,
                                y = 0.5,
                                z = 0,
                            },
                            half_extents = {
                                x = 2.5,
                                y = 1.5,
                                z = 1,
                            },
                        },
                    },
                },
            },
        }

        t.on_entity_registered = function (unit)
            if EntityAux.owned(unit) and EntityAux.has_component(unit, "ability") then
                local command = {
                    ability_name = "push_others",
                }

                EntityAux.queue_command_master(unit, "ability", "execute_ability", command)


                -- ===============================================================
                Unit.set_unit_visibility(unit, true)
                EntityAux.call_master(unit, "enemy", "change_state", "battle")
                -- ===============================================================
            end
        end

        t.on_death_notified = function (unit)
            local perk_id = "besting_the_beast_of_orox"

            for player_go_id, player_info in PlayerManager:local_players_iterator() do
                PerkManager:increase_count_to(player_go_id, perk_id, 1)
            end

            HydraManager:add_boss_killed(t.enemy_type)
            StateAux.nuke_all_enemies(FlowCallbacks.state_game.entity_manager)
        end

        t.custom_handle_death = function (unit, context, component)
            component:queue_command(unit, "ability", "set_enabled", true)

            if EntityAux.owned(unit) then
                component:queue_command_master(unit, "ability", "execute_ability", {
                    ability_name = "nuke",
                    settings_path = "characters/generic_abilities",
                })
            end
        end

        t.start_state = "idle"

        t.states = function (component)
            local cache_component_states = closure(StateCommon.cache_component_states, component)

            return {
                setup = StateCommonBuilder.build_skip_state(component, t.start_state),
                spawn = StateCommonBuilder.build_spawn_state(component, closure(StateBoss.compulsory_checks, component)),
                select_action = {
                    on_enter = {},
                    update = {},
                    post_transitions = {
                        {
                            action = function (unit, context)
                                return context.state.submerged and "submerged" or "battle"
                            end,
                        },
                    },
                    on_exit = {},
                },
                idle = {
                    on_enter = {},
                    update = {},
                    post_transitions = {
                        {
                            next_state = "intro",
                            action = function() return true end,
                        },
                    },
                    on_exit = {},
                },
                intro = {
                    on_enter = {
                        closure(StateBoss.intro_enter, component),
                        closure(StateDrakhBoss.intro_enter, component),
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
                        closure(StateDrakhBoss.intro_exit, component),
                        function(unit)
                            Unit.set_unit_visibility(unit, true)
                        end,
                    },
                },
                battle = {
                    on_enter = {
                        closure(StateBoss.battle_enter, component),
                        closure(StateDrakhBoss.battle_enter, component),
                    },
                    update = {
                        closure(StateCommon.select_target_player, component),
                        closure(StateBoss.move_update, component),
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
                    },
                    on_exit = {
                        closure(StateBoss.battle_exit, component),
                    },
                },
                attack = {
                    on_enter = {
                        closure(StateBoss.attack_enter, component),
                        closure(StateCommon.attack_enter, component),
                    },
                    pre_transitions = {
                        {
                            action = closure(StateBoss.compulsory_checks, component),
                        },
                    },
                    update = {
                        closure(StateCommon.rotate_towards_target, component),
                    },
                    post_transitions = {
                        {
                            next_state = "select_action",
                            action = closure(StateCommon.attack_update, component),
                        },
                    },
                    on_exit = {},
                },
                summon_minions = {
                    on_enter = {
                        closure(StateDrakhBoss.summon_minions, component),
                    },
                    update = {
                        closure(StateCommon.select_target_player, component),
                        closure(StateBoss.move_update, component),
                    },
                    pre_transitions = {
                        {
                            action = closure(StateBoss.compulsory_checks, component),
                        },
                    },
                    post_transitions = {
                        {
                            next_state = "select_action",
                            action = closure(StateCommon.attack_update, component),
                        },
                    },
                    on_exit = {
                        closure(StateBoss.battle_exit, component),
                    },
                },
                charge = {
                    on_enter = {
                        closure(StateCommon.select_target_player, component),
                        closure(StateDrakhBoss.charge_enter, component),
                    },
                    pre_transitions = {
                        {
                            action = closure(StateBoss.compulsory_checks, component),
                        },
                    },
                    update = {
                        closure(StateCommon.select_target_player, component),
                        closure(StateBoss.wanted_translation_update, component),
                    },
                    post_transitions = {
                        {
                            next_state = "battle",
                            action = closure(StateDrakhBoss.wait_for_reached_target, component),
                        },
                    },
                    on_exit = {
                        closure(StateDrakhBoss.charge_exit, component),
                    },
                },
                charge_wallhit = {
                    on_enter = {
                        closure(StateDrakhBoss.charge_wallhit_enter, component),
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
                            action = closure(StateDrakhBoss.charge_wallhit_should_exit, component),
                        },
                    },
                    on_exit = {},
                },
                stagechange = {
                    on_enter = {
                        closure(StateBoss.stagechange_enter, component),
                        closure(StateDrakhBoss.stagechange_enter, component),
                    },
                    update = {},
                    post_transitions = {
                        {
                            next_state = "charge",
                            action = closure(StateBoss.stagechange_should_exit, component),
                        },
                    },
                    on_exit = {
                        closure(StateDrakhBoss.stagechange_exit, component),
                    },
                },
                jump_fallingrock = {
                    on_enter = {
                        closure(StateDrakhBoss.jump_fallingrock_enter, component),
                        closure(StateBoss.attack_enter, component),
                        closure(StateCommon.attack_enter, component),
                    },
                    pre_transitions = {
                        {
                            action = closure(StateBoss.compulsory_checks, component),
                        },
                    },
                    update = {
                        closure(StateDrakhBoss.jump_fallingrock_update, component),
                    },
                    post_transitions = {
                        {
                            next_state = "charge",
                            action = closure(StateCommon.attack_update, component),
                        },
                    },
                    on_exit = {},
                },
                decay = {
                    on_enter = {},
                    update = {},
                    pre_transitions = {},
                    post_transitions = {},
                    on_exit = {},
                },
            }, cache_component_states
        end

        return t
    end

    if path == "lua/ai_states/state_drakh_boss" then

        StateDrakhBoss = StateDrakhBoss or {}

        local MINION_SPAWN_PATH = "lake_dweller"
        local MINION_SPAWN_KEY
        local NR_MINIONS_PER_MARKER = 1
        local TIME_SUBMERGED = 5
        local DIVE_DEPTH = 5
        local TIME_CHARGE_WALL_HIT = 0.5
        local DIVE_DURATION = 1

        local function _on_damaged_in_penguine_mode(unit)
            Unit.set_data(unit, "penguin_damaged", true)
        end

        local function _enter_penguin_mode(component, unit, context)
            local t = TempTableFactory:get_map("resistance_id", "all", "type", "immune")

            if is_caves_boss_floor then
                EntityAux.call_master(unit, "resistance", "set_resistance", t)
                EntityAux.call_master(unit, "boss_health_bar", "set_active", false)
            end

            local state = context.state

            state.in_penguin_mode = true
            state.penguin_start_time = _G.GAME_TIME

            component:trigger_rpc_event("flow_event", unit, "enraged_start")
        end

        local function _exit_penguin_mode(component, unit, context)
            local t = TempTableFactory:get_map("resistance_id", "all", "type", nil)

            EntityAux.call_master(unit, "resistance", "set_resistance", t)
            EntityAux.call_master(unit, "boss_health_bar", "set_active", true)
            EntityEventModifierManager:unregister_modifier(unit, "damaged", "state_drakh_boss")
            Unit.set_data(unit, "penguin_damaged", false)

            context.state.in_penguin_mode = false

            local fallingrock = Unit.get_data(unit, "fallingrock")

            if fallingrock then
                Unit.set_data(unit, "fallingrock", nil)
                component.entity_spawner:despawn_entity(fallingrock)
            end

            component:trigger_rpc_event("flow_event", unit, "enraged_stop")
        end

        local function _dive_enter(component, unit, context, target_unit)
            local state = context.state

            component:queue_command_master(unit, "animation", "trigger_event", "jump_dive")

            local source_position = Unit.world_position(unit, 0)
            local target_position = Unit.world_position(target_unit, 0)

            state.source_position = Vector3Aux.box({}, source_position)
            state.target_position = Vector3Aux.box({}, target_position)
            state.start_move_time = _G.GAME_TIME + 0.8
            state.land_anim_played = false
            state.flow_played = false

            EntityAux.queue_command_master(unit, "rotation", "rotate_towards", target_position - source_position)
            EntityAux.queue_command_master(unit, "motion", "change_state", "custom_translation")
            EntityAux.queue_command_master(unit, "motion", "constrain_to_ground", false)
        end

        local function _dive_update(component, unit, context, going_up)
            local state = context.state
            local t = math.saturate((_G.GAME_TIME - state.start_move_time) / DIVE_DURATION)
            local source = Vector3Aux.unbox(state.source_position)
            local target = Vector3Aux.unbox(state.target_position)

            if going_up then
                local height = math.abs(target.z - source.z)

                target.z = source.z

                local up = Vector3.up() * height

                target = Vector3.slerp(target, target + up, math.saturate(t * 2))
            else
                local down = -Vector3.up() * 5

                target = Vector3.slerp(target, target + down, math.saturate((t - 0.5) * 2))
            end

            local position = Vector3.slerp(source, target, t)

            if t >= 0.75 and not state.land_anim_played then
                state.land_anim_played = true
            end

            if t >= 0.9 and not state.flow_played then
                Unit.flow_event(unit, "_land_water")

                state.flow_played = true

                local drawer = Debug.drawer("testing")

                drawer:reset()
                drawer:sphere(Unit.world_position(unit, 0), 0.2)
            end

            EntityAux.queue_command_master(unit, "motion", "move_to", Vector3Aux.box_temp(position))

            state.move_done = t >= 1
        end

        local function _get_closest_dive_marker(position, dive_markers)
            local closest_unit
            local closest_dist_sq = math.huge

            for i, marker_unit in ipairs(dive_markers) do
                local dist_sq = Vector3.length_squared(Unit.world_position(marker_unit, 0) - position)

                if dist_sq <= closest_dist_sq then
                    closest_unit = marker_unit
                    closest_dist_sq = dist_sq
                end
            end

            return closest_unit
        end

        local function _get_best_fallingrock_marker(position, markers)
            local index = math.random(#markers)

            return markers[index]
        end

        StateDrakhBoss.is_damaged = function (component, unit, context)
            local is_damaged = Unit.get_data(unit, "penguin_damaged")

            if is_damaged then
                _exit_penguin_mode(component, unit, context)

                return true
            end
        end

        StateDrakhBoss.intro_enter = function (component, unit, context)
            local state = context.state
            local dive_markers = {}
            local fallingrock_markers = {}
            local world_proxy = component.world_proxy

            for _, level in world_proxy:levels_iterator() do
                local units = LevelAux.units_recursive(level)

                for i, unit in ipairs(units) do
                    if Unit.is_a(unit, "gameobjects/level_editor/generic_marker") then
                        local marker_type = Unit.get_data(unit, "type")

                        if marker_type == "drakh_dive_point" then
                            dive_markers[#dive_markers + 1] = unit
                        elseif marker_type == "fallingrock" then
                            fallingrock_markers[#fallingrock_markers + 1] = unit
                        end
                    end
                end
            end

            state.dive_markers = dive_markers
            state.fallingrock_markers = fallingrock_markers
        end

        StateDrakhBoss.intro_exit = function (component, unit, context)
            EntityAux.call_master(unit, "boss_health_bar", "set_active", true)
        end

        StateDrakhBoss.battle_enter = function (component, unit, context)
            EntityAux.queue_command_master(unit, "rotation", "set_rotation_speed", 3)
        end

        StateDrakhBoss.stagechange_enter = function (component, unit, context, dt)
            _enter_penguin_mode(component, unit, context)
        end

        StateDrakhBoss.stagechange_exit = function (component, unit, context, dt)
            EntityEventModifierManager:register_modifier(unit, "damaged", "state_drakh_boss", _on_damaged_in_penguine_mode)

            local state = context.state

            for _, marker_unit in ipairs(state.dive_markers) do
                local water_position = Unit.world_position(marker_unit, 0)

                for i = 1, NR_MINIONS_PER_MARKER do
                    local position = QueryManager:query_position_in_hollow_disc(water_position, 1, 8, 0.5)
                    local min_h = position.z - 10
                    local max_h = position.z + 10
                    local land_position = QueryManager:snap_to_navgrid(position, 0.5, nil, min_h, max_h)
                    local to_land = land_position - position

                    to_land.z = 0

                    local rotation = Quaternion.look(Vector3.normalize(to_land))

                    AIManager:spawn_monster(MINION_SPAWN_PATH, land_position, rotation, nil, {
                        spawn_info_key = MINION_SPAWN_KEY,
                    })
                end
            end
        end

        StateDrakhBoss.attack_enter = function (component, unit, context)
            local state = context.state
            local target_position

            if state.ability_position then
                target_position = state.ability_position
            elseif state.ability_target_unit then
                target_position = Unit.world_position(state.ability_target_unit, 0)
            elseif state.target_unit then
                target_position = Unit.world_position(state.target_unit, 0)
            else
                return
            end

            local direction = Vector3.normalize(target_position - Unit.world_position(unit, 0))

            component:queue_command_master(unit, "rotation", "set_rotation_towards", direction)
        end

        StateDrakhBoss.dive_enter = function (component, unit, context, dt)
            local state = context.state
            local closest_marker = _get_closest_dive_marker(Unit.world_position(unit, 0), state.dive_markers)

            state.target_dive_marker = closest_marker

            _dive_enter(component, unit, context, context.state.target_dive_marker)

            local t = TempTableFactory:get_map("resistance_id", "all", "type", "immune")

            EntityAux.call_master(unit, "resistance", "set_resistance", t)
            EntityAux.call_master(unit, "boss_health_bar", "set_active", false)
        end

        StateDrakhBoss.dive_update = function (component, unit, context, dt)
            _dive_update(component, unit, context, false)
        end

        StateDrakhBoss.dive_should_exit = function (component, unit, context, dt)
            return context.state.move_done
        end

        StateDrakhBoss.dive_exit = function (component, unit, context, dt)
            context.state.submerged = true

            if EntityAux.state_master_interface(unit, "i_damage_receiver").hitpoints > 0 then
                Unit.set_unit_visibility(unit, false)
            end
        end

        StateDrakhBoss.submerged_enter = function (component, unit, context, dt)
            local state = context.state

            state.submerged_enter_time = _G.GAME_TIME
        end

        StateDrakhBoss.submerged_should_exit = function (component, unit, context, dt)
            local state = context.state

            if not state.picked_new_target then
                local decide_target = _G.GAME_TIME >= (state.submerged_enter_time or 0) + (TIME_SUBMERGED - 0.5)

                if decide_target then
                    local nr_players = 0
                    local player_positions = Vector3.zero()

                    for go_id, player_info in PlayerManager:avatars_iterator() do
                        local avatar_unit = player_info.avatar_unit
                        local p = Unit.world_position(avatar_unit, 0)

                        player_positions = player_positions + p
                        nr_players = nr_players + 1
                    end

                    local state = context.state
                    local center_position = player_positions / nr_players
                    local closest_dive_marker = _get_closest_dive_marker(center_position, state.dive_markers)
                    local new_position = Unit.world_position(closest_dive_marker, 0)

                    EntityAux.queue_command_master(unit, "motion", "force_set_position", new_position - Vector3.up() * DIVE_DEPTH)

                    state.picked_new_target = true
                end
            end

            local should_exit = _G.GAME_TIME >= (state.submerged_enter_time or 0) + TIME_SUBMERGED

            if should_exit and state.target_unit then
                state.selected_ability_name = "emerge"
                state.ability_position = Unit.world_position(state.target_unit, 0)

                return "jump_up"
            end
        end

        StateDrakhBoss.submerged_exit = function (component, unit, context, dt)
            local state = context.state

            state.submerged = false
            state.picked_new_target = false
        end

        StateDrakhBoss.jump_up_enter = function (component, unit, context, dt)
            EntityAux.queue_command_master(unit, "rotation", "set_rotation_towards", context.state.ability_position - Unit.world_position(unit, 0))
            EntityAux.queue_command_master(unit, "motion", "constrain_to_ground", false)
            Unit.set_data(unit, "penguin_damaged", false)
        end

        StateDrakhBoss.jump_up_update = function (component, unit, context, dt)
            return
        end

        StateDrakhBoss.jump_up_should_exit = function (component, unit, context, dt)
            local attack_busy = EntityAux.state_master(unit, "ability").is_busy

            if not attack_busy then
                local state = context.state

                return state.in_penguin_mode and "charge" or "battle"
            end
        end

        StateDrakhBoss.jump_up_exit = function (component, unit, context, dt)
            context.state.submerged = false

            EntityAux.queue_command_master(unit, "motion", "change_state", "default")
            EntityAux.queue_command_master(unit, "motion", "constrain_to_ground", true)

            local t = TempTableFactory:get_map("resistance_id", "all", "type", nil)

            EntityAux.call_master(unit, "resistance", "set_resistance", t)
            EntityAux.call_master(unit, "boss_health_bar", "set_active", true)
            Unit.set_unit_visibility(unit, true)
        end

        StateDrakhBoss.summon_minions = function (component, unit, context, dt)
            local state = context.state
            local command = TempTableFactory:get_map("ability_name", "summon_dwellers")

            component:queue_command_master(unit, "ability", "execute_ability", command)

            for _, marker_unit in ipairs(state.dive_markers) do
                local water_position = Unit.world_position(marker_unit, 0)

                for i = 1, 2 do
                    local position = QueryManager:query_position_in_hollow_disc(water_position, 1, 8, 0.5)
                    local min_h = position.z - 10
                    local max_h = position.z + 10
                    local land_position = QueryManager:snap_to_navgrid(position, 0.5, nil, min_h, max_h)
                    local to_land = land_position - position

                    to_land.z = 0

                    local rotation = Quaternion.look(Vector3.normalize(to_land))

                    AIManager:spawn_monster(MINION_SPAWN_PATH, land_position, rotation, nil, {
                        spawn_info_key = MINION_SPAWN_KEY,
                    })
                end
            end
        end

        StateDrakhBoss.charge_enter = function (component, unit, context)
            local state = context.state

            if state.target_unit then
                EntityAux.queue_command_master(unit, "rotation", "rotate_towards_unit", nil)
                EntityAux.queue_command_master(unit, "rotation", "set_rotation_towards", Unit.world_position(state.target_unit, 0) - Unit.world_position(unit, 0))

                local command = TempTableFactory:get_map("ability_name", "charge")

                component:queue_command_master(unit, "ability", "execute_ability", command)

                state.start_time = _G.GAME_TIME
                state.started_charging = true
                state.charge_speed_changed = not state.in_penguin_mode

                if state.charge_speed_changed then
                    local t = TempTableFactory:get_map("id", "drakh_charge", "value", 0.5)

                    EntityAux.queue_command_master_interface(unit, "i_speed_listener", "add_speed_multiplier", t)
                end

                if not state.in_penguin_mode then
                    component:trigger_rpc_event("rpc_start_charge_marker", unit, state.target_unit)
                end
            end
        end

        StateDrakhBoss.wait_for_reached_target = function (component, unit, context, dt)
            local state = context.state

            if state.target_unit then
                if not state.started_charging then
                    StateDrakhBoss.charge_enter(component, unit, context)
                end

                if state.started_charging then
                    local rotation_lock_frame = 15

                    if _G.GAME_TIME - state.start_time <= rotation_lock_frame / 30 then
                        local target_position = Unit.world_position(state.target_unit, 0)

                        EntityAux.queue_command_master(unit, "rotation", "rotate_towards", target_position - Unit.world_position(unit, 0))
                        EntityAux.queue_command_master(unit, "rotation", "rotate_towards_unit", nil)
                    end
                end
            end

            if state.started_charging and _G.GAME_TIME - state.start_time >= 1 then
                if state.target_unit then
                    local my_position = Unit.world_position(unit, 0)
                    local target_position = Unit.world_position(state.target_unit, 0)
                    local distance_sqr = Vector3.distance_xy_squared(my_position, target_position)

                    if distance_sqr <= 4 then
                        return "charge_wallhit"
                    end
                end

                local collided = MotionState.has_collided(EntityAux.state_master(unit, "motion").motion_state)

                if collided then
                    state.collided_time = _G.GAME_TIME

                    return "charge_wallhit"
                end
            end
        end

        StateDrakhBoss.charge_exit = function (component, unit, context)
            local state = context.state

            state.ability_position = nil
            state.ability_target_unit = nil
            state.started_charging = false

            component:queue_command_master(unit, "ability", "interrupt")

            if state.charge_speed_changed then
                state.charge_speed_changed = nil

                EntityAux.queue_command_master_interface(unit, "i_speed_listener", "remove_speed_multiplier", "drakh_charge")
                EntityAux.queue_command_master(unit, "rotation", "set_rotation_speed", 0)
            end

            if not state.in_penguin_mode then
                component:trigger_rpc_event("flow_event", unit, "ability_charge_stop")
            end
        end

        function _check_exit_charge(component, unit, context)
            local state = context.state

            if state.in_penguin_mode then
                if _G.GAME_TIME - state.penguin_start_time > context.settings.enraged_time then
                    _exit_penguin_mode(component, unit, context)
                end

                if StateDrakhBoss.try_to_jump(component, unit, context) then
                    return "jump_fallingrock"
                else
                    return "charge"
                end
            else
                return "battle"
            end
        end

        StateDrakhBoss.charge_wallhit_enter = function (component, unit, context, dt)
            component:queue_command_master(unit, "animation", "trigger_event", "charge_exit")

            context.state.chargeslide_enter_time = _G.GAME_TIME
            context.state.next_ability_time = _G.GAME_TIME + 5
        end

        StateDrakhBoss.charge_wallhit_should_exit = function (component, unit, context, dt)
            local should_exit = _G.GAME_TIME >= context.state.chargeslide_enter_time + TIME_CHARGE_WALL_HIT

            if should_exit then
                component:queue_command_master(unit, "animation", "trigger_event", "move")

                context.state.movespeed = 0

                return _check_exit_charge(component, unit, context)
            end
        end

        StateDrakhBoss.try_to_jump = function (component, unit, context)
            local predicates = {
                partial(StateAux.predicate_within_range, 10, 50),
            }
            local desirability_funcs = {
                StateAux.normalized_range,
            }

            local function desirability_mixer(range)
                return range
            end

            local target = StateAux.get_best_target(component, unit, context, 50, false, predicates, TempTableFactory:get_map("desirability_funcs", desirability_funcs, "desirability_mixer", desirability_mixer))

            if target then
                context.state.target_unit = target

                return true
            end

            return false
        end

        StateDrakhBoss.jump_fallingrock_enter = function (component, unit, context, dt)
            local state = context.state

            state.start_time = _G.GAME_TIME

            local nr_players = 0
            local player_positions = Vector3.zero()

            for go_id, player_info in PlayerManager:avatars_iterator() do
                local avatar_unit = player_info.avatar_unit
                local p = Unit.world_position(avatar_unit, 0)

                player_positions = player_positions + p
                nr_players = nr_players + 1
            end

            local center_position

            if nr_players == 0 then
                center_position = Unit.world_position(unit, 0)
            else
                center_position = player_positions / nr_players
            end

            state.next_fallingrock_marker = _get_best_fallingrock_marker(center_position, state.fallingrock_markers)
            state.landed = false
            state.selected_ability_name = "leap_smash"

            if state.target_unit then
                state.ability_position = Unit.world_position(state.target_unit, 0)
            else
                state.ability_position = center_position
            end
        end

        StateDrakhBoss.jump_fallingrock_update = function (component, unit, context, dt)
            local state = context.state

            if not state.landed and _G.GAME_TIME - state.start_time > 2 then
                state.landed = true

                local fallingrock = Unit.get_data(unit, "fallingrock")

                if fallingrock then
                    local command = TempTableFactory:get_map("ability_name", "crush")

                    EntityAux.queue_command_master(fallingrock, "ability", "execute_ability", command)
                end

                state.current_fallingrock_marker = state.next_fallingrock_marker
            end
        end
    end

    return result
end)
