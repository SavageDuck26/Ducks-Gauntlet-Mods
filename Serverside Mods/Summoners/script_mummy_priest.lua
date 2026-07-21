-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Adds spawning abilities to Mummy Priest
-- =================================================================================================

local MOD_NAME = "SummonerMummyPriest"

-- Helper function to check if mummy_priest summoning is enabled
local function is_mummy_priest_enabled()
    if Summoners.CONFIG.enabled == false then
        return false
    end
    if Summoners.CONFIG.summoners and Summoners.CONFIG.summoners.mummy_priest then
        return Summoners.CONFIG.summoners.mummy_priest.enabled
    end
    return true
end

-- Helper function to get spawn chances
local function get_bloat_skeleton_chance()
    if Summoners.CONFIG.summoners and Summoners.CONFIG.summoners.mummy_priest then
        return Summoners.CONFIG.summoners.mummy_priest.bloat_skeleton_chance or 0.33
    end
    return 0.33
end

local function get_bloat_necromancer_chance()
    if Summoners.CONFIG.summoners and Summoners.CONFIG.summoners.mummy_priest then
        return Summoners.CONFIG.summoners.mummy_priest.bloat_necromancer_chance or 0.10
    end
    return 0.10
end

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/mummy_priest/mummy_priest" and result and _G.is_host_ducks_mods == true then
        if result.ability_selection then
            result.ability_selection.bloat = {
                cooldown = 20, -- 15 is base
                range = 13,
                target_allies = true,
                use_target_unit = true,
                weight = 5,
                target_func = StateAux.get_random_target,
                predicates = {
                    closure(StateAux.predicate_unit_type, "characters/mummy_risen/mummy_risen"),
                },
            }
            -- Add a new ability selection for fireball
            result.ability_selection.priest_fireball = {
                cooldown = 5, -- 5 is base
                max_distance = 16,
                min_distance = 1,
                use_target_unit = true,
                weight = 1,
            }
        end

        if result.abilities then
            result.abilities.priest_fireball = {
                animation = "attack_normal",
                duration = 40,
                rotation_lock_start = 20,
                events = {
                    {
                        angle = 0,
                        damage_type = "pierce",
                        effect_type = "fire",
                        event_start = 19,
                        inherit_from = "default_event_data",
                        radius = 0.4,
                        speed = 8,
                        speed_multiplier = 1.2,
                        stagger_origin_type = "direction",
                        type = "projectile",
                        unit_path = "characters/mummy_priest/mummy_priest_bolt",
                        damage_amount = 16,
                        origin = {
                            x = 0.3,
                            y = 1,
                            z = 0,
                        },
                        hit_react = "poke",
                    },
                },
            }

            -- bloat that ALSO summons enemies
            result.abilities.bloat = {
                animation = "ability_bloat",
                duration = 60,
                rotation_lock_start = 0,
                flow_events = {
                    {
                        event_name = "cast_transform",
                        time = 1,
                    },
                },
                events = {
                    {
                        event_duration = 1,
                        event_start = 50,
                        target_type = "target_unit",
                        on_enter_custom = function (event_handler, event)
                            local unit = event.owner_unit

                            if not EntityAux.owned(unit) then
                                return
                            end

                            if not Unit.alive(event.target_unit) then
                                return
                            end

                            local target_unit = event.target_unit
                            local position = Unit.world_position(target_unit, 0)
                            local rotation = Unit.world_rotation(target_unit, 0)
                            local unit_path = "characters/mummy_bloated/mummy_bloated"
                            local entity = event_handler.entity_spawner:spawn_entity(unit_path, position, rotation, nil, {
                                spawn_info_key = "default",
                            })

                            event_handler.ability_component.entity_spawner:despawn_entity(target_unit)
                            
                            if not is_mummy_priest_enabled() then return end
                            
                            local entity_spawner = FlowCallbacks.state_game.entity_spawner
                            if math.random() < get_bloat_skeleton_chance() then
                                local position1 = Unit.world_position(unit, 0)
                                local rotation1 = Unit.world_rotation(unit, 0)
                                local spawn1 = entity_spawner:spawn_entity("skeleton_warrior", position1, rotation1)
                                NetworkUnitSynchronizer:add(spawn1)
                            end
                            if math.random() < get_bloat_necromancer_chance() then
                                local position2 = Unit.world_position(unit, 0)
                                local rotation2 = Unit.world_rotation(unit, 0)
                                local spawn2 = entity_spawner:spawn_entity("necromancer", position2, rotation2)
                                NetworkUnitSynchronizer:add(spawn2)
                            end
                        end,
                    },
                },
            }
        end
    end

    return result
end)