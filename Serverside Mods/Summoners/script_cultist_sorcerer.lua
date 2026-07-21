-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Adds spawning abilities to Cultist Sorcerer
-- =================================================================================================

local MOD_NAME = "SummonerCulistSorcerer"

-- Helper function to check if cultist_sorcerer summoning is enabled
local function is_cultist_sorcerer_enabled()
    if Summoners.CONFIG.enabled == false then
        return false
    end
    if Summoners.CONFIG.summoners and Summoners.CONFIG.summoners.cultist_sorcerer then
        return Summoners.CONFIG.summoners.cultist_sorcerer.enabled
    end
    return true
end

-- Helper function to get spawn chance
local function get_shadow_serpent_chance()
    if Summoners.CONFIG.summoners and Summoners.CONFIG.summoners.cultist_sorcerer then
        return Summoners.CONFIG.summoners.cultist_sorcerer.shadow_serpent_chance or 0.25
    end
    return 0.25
end

local function get_shield_spawner_chance()
    if Summoners.CONFIG.summoners and Summoners.CONFIG.summoners.cultist_sorcerer then
        return Summoners.CONFIG.summoners.cultist_sorcerer.shield_spawner_chance or 0.25
    end
    return 0.25
end

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/cultist_sorcerer/cultist_sorcerer" and result and _G.is_host_ducks_mods == true then

        if result.ability_selection then
            result.ability_selection.shadow_serpent = {
                cooldown = 6, -- 6 is base
                max_distance = 20,
                min_distance = 3,
                weight = 1,
            }

            result.ability_selection.shield_spawner = {
                cooldown = 25, -- 15 is base
                range = 12,
                target_allies = true,
                use_target_unit = true,
                weight = 5,
                target_func = StateAux.get_random_target,
                predicates = {
                    closure(StateAux.predicate_faction, FactionComponent.faction_mask("spawner")),
                    function (component, unit, context, target_unit)
                        return not Unit.get_data(target_unit, "spawner_marked")
                    end,
                    StateAux.predicate_line_of_sight_to_target,
                    function (component, unit, context, target_unit)
                        local state = EntityAux.state_interface(target_unit, "i_damage_receiver")
                        local hitpoint_ratio = state.hitpoints / state.max_hitpoints
                        local hp_limit = 0.75

                        return hitpoint_ratio <= hp_limit
                    end,
                },
            }
        end

        if result.abilities then
            result.abilities.shadow_serpent = {
                animation = "ability_shadowserpent",
                duration = 75,
                rotation_lock_start = 30,
                flow_events = {
                    {
                        event_name = "on_shadowserpent_windup",
                        time = 0,
                    },
                    {
                        event_name = "on_shadowserpent_cast",
                        time = 50,
                    },
                },
                events = {
                    {
                        amplitude = 80,
                        angle = 0,
                        angular_frequency = 0.5,
                        event_start = 50,
                        hit_react = "push",
                        max_distance = 50,
                        node_use_root_rotation = true,
                        radius = 0.4,
                        speed = 10,
                        stagger_origin_type = "direction",
                        type = "projectile_serpent",
                        unit_path = "cultist_sorcerer_projectile",
                        damage_amount = 16,
                        origin = {
                            x = -0.1,
                            y = 1.5,
                            z = 0,
                        },
                        phase_offset = math.pi / 2,
                    },
                    {
                        amplitude = 80,
                        angle = 0,
                        angular_frequency = 0.5,
                        event_start = 50,
                        hit_react = "push",
                        max_distance = 50,
                        node_use_root_rotation = true,
                        radius = 0.4,
                        speed = 10,
                        stagger_origin_type = "direction",
                        type = "projectile_serpent",
                        unit_path = "cultist_sorcerer_projectile",
                        damage_amount = 16,
                        origin = {
                            x = -0.1,
                            y = 1.5,
                            z = 0,
                        },
                        phase_offset = -math.pi / 2,
                    },
                },
                on_enter = {
                    custom_callback = function(component, unit, ability)
                        if not is_cultist_sorcerer_enabled() then return end
                        if math.random() < get_shadow_serpent_chance() then
                            local entity_spawner = FlowCallbacks.state_game.entity_spawner
                            local position = Unit.world_position(unit, 0)
                            local rotation = Unit.world_rotation(unit, 0)
                            
                            local spawn = entity_spawner:spawn_entity("cultist_armor", position, rotation)
                            NetworkUnitSynchronizer:add(spawn)
                        end
                    end,
                },
            }

            result.abilities.shield_spawner = {
                animation = "ability_shield",
                mode = "infinite",
                on_enter = {
                    flow_event = "on_shield_spawner_start",
                    custom_callback = function (component, unit, ability)
                        
                        local shielding_effect = "effects/cha_cultist_sorcerer_shielding"
                        local world = component.world_proxy:get_world()

                        ability.custom_start_time = _G.GAME_TIME

                        Unit.set_data(ability.target_unit, "spawner_marked", true)

                        ability.shielding_id = World.create_particles(world, shielding_effect, Unit.world_position(ability.target_unit, 0))
                        
                        if is_cultist_sorcerer_enabled() and math.random() < get_shield_spawner_chance() then
                            local entity_spawner = FlowCallbacks.state_game.entity_spawner
                            local position = Unit.world_position(unit, 0)
                            local rotation = Unit.world_rotation(unit, 0)
                            
                            local spawn = entity_spawner:spawn_entity("demon_heavy", position, rotation)
                            NetworkUnitSynchronizer:add(spawn)
                        end
                    end,
                },
                on_exit = {
                    animation_event = "move",
                    flow_event = "on_shield_spawner_stop",
                    custom_callback = function (component, unit, ability)
                        local world = component.world_proxy:get_world()

                        World.destroy_particles(world, ability.shielding_id)

                        if ability.target_unit then
                            Unit.set_data(ability.target_unit, "spawner_marked", false)
                        end
                    end,
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
                        beam_effect = "effects/cha_cultist_sorcerer_shielding_beam",
                        event_start = 15,
                        length_max = 0.5,
                        length_min = 0,
                        node = "j_l_hand_attach",
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
                                    local t = TempTableFactory:get_map("resistance_id", "all", "type", "immune")

                                    EntityAux.call_master(event.target_unit, "resistance", "set_resistance", t)
                                end
                            end,
                        },
                        on_exit_custom = function (ability_event_handler, event)
                            CommonEventsAux.beam_on_exit(ability_event_handler, event)

                            if Unit.alive(event.target_unit) and EntityAux.owned(event.target_unit) then
                                local t = TempTableFactory:get_map("resistance_id", "all", "type", nil)

                                EntityAux.call_master(event.target_unit, "resistance", "set_resistance", t)
                            end
                        end,
                    },
                },
            }
        end
    end

    return result
end)