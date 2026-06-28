-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Fix monster files that are broken.
-- =================================================================================================

local MOD_NAME = "FixMonsters"

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/mummy_giant_greed/mummy_giant_greed" then
        local t = SettingsAux.override_settings("characters/mummy_base", {
            always_ignore_knockbacks = true,
            animation_driven_movement = true,
            big_dude = true,
            blood_effect_node = "j_collarbone",
            bloodtype = "red",
            can_instakill = false,
            default_mover_collision_filter = "enemy_mover_no_player",
            enemy_type = "mummy_giant",
            hitpoints = 212,
            instakill_on = "nil",
            kill_score = 5,
            max_movespeed = 5,
            movespeed = 5,
            movespeed_0_to_100_duration = 3,
            name = "loc_enemy_mummy_giant",
            preferred_distance_max = 2,
            preferred_distance_min = 1,
            rotationspeed = 1,
            soul_multiplier = 8,
            hit_reacts = require("characters/hit_reacts_elite"),
            scale_info = {
                scale = 2,
                variation = 0.05,
            },
            ability_selection = {
                claw = {
                    cooldown = 1,
                    max_distance = 2,
                    min_distance = 0,
                    request_execution = true,
                    weight = 1,
                },
            },
            abilities = {
                default_event_data = {
                    damage_amount = 5,
                    damage_type = "slash",
                    effect_type = "axe",
                    event_data = true,
                    event_duration = 1,
                    event_start = 5,
                    hit_react = "tackle",
                    type = "box",
                    origin = {
                        x = 0,
                        y = 0.5,
                        z = 0,
                    },
                    half_extents = {
                        x = 0.6,
                        y = 1,
                        z = 0.5,
                    },
                },
                claw = {
                    duration = 75,
                    rotation_lock_start = "nil",
                    animation_events = {
                        {
                            event_name = "attack_claw_windup_fast",
                            time = 0,
                        },
                    },
                    flow_events = {
                        {
                            event_name = "ability_claw_windup",
                            time = 0,
                        },
                        {
                            event_name = "ability_claw_swing",
                            time = 20,
                        },
                    },
                    events = {
                        {
                            behind_wall_test = true,
                            damage_amount = 15,
                            damage_type = "punch",
                            event_duration = 2,
                            event_start = 30,
                            hit_react = "tackle",
                            inherit_from = "default_event_data",
                            origin = {
                                x = 0.2,
                                y = 0,
                                z = 0,
                            },
                            half_extents = {
                                x = 0.8,
                                y = 1.3,
                                z = 1,
                            },
                        },
                    },
                },
                out_of_my_way = {
                    mode = "infinite",
                    events = {
                        {
                            damage_amount = 0,
                            event_duration = 120,
                            event_start = 0,
                            friendly_fire = true,
                            hit_react = "push",
                            inherit_from = "default_event_data",
                            only_friendly_fire = true,
                            type = "box",
                            origin = {
                                x = 0,
                                y = 0,
                                z = 0,
                            },
                            half_extents = {
                                x = 0.8,
                                y = 0.8,
                                z = 0.5,
                            },
                        },
                    },
                    on_exit = {
                        ability = "out_of_my_way",
                    },
                },
            },
            gibs = {
                split_vertical = {
                    {
                        amount = 1,
                        node = "root",
                        unit_path = "characters/mummy_risen/gib/gib_split_vertical",
                    },
                },
                split_horizontal = {
                    {
                        amount = 1,
                        node = "root",
                        unit_path = "characters/mummy_risen/gib/gib_split_horizontal",
                    },
                },
                decapitated = {
                    {
                        amount = 1,
                        node = "root",
                        unit_path = "characters/mummy_risen/gib/gib_headless",
                    },
                    {
                        amount = 1,
                        node = "j_head",
                        pitch = 120,
                        pitch_variation = 20,
                        power = 20,
                        power_variation = 1,
                        unit_path = "characters/mummy_risen/gib/gib_head",
                        yaw = 0,
                        yaw_variation = 20,
                    },
                },
            },
        })

        t.on_death_authorative = function (unit, is_local_hit, hit, component)
            if EntityAux.has_component(unit, "dropper") then
                EntityAux.command_immediately(unit, "dropper", "spawn_drop", is_local_hit)
            end
        end

        t.states = function (component)
            local cache_component_states = closure(StateCommon.cache_component_states, component)

            return StateCommonBuilderFodder.build_default(component, {}, t.start_state), cache_component_states
        end
        
    return t

    end
    return result
end)

