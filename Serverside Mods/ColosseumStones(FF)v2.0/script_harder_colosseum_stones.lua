-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Replace normal spawners with colosseum stone spawners
-- =================================================================================================

local MOD_NAME = "HarderColosseumStones"

ColosseumStones = ColosseumStones or {}
ColosseumStones.CONFIG = ColosseumStones.CONFIG or { harder_stones_enabled = false }

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)
    
    -- ==========================================================================================================
    if path == "gameobjects/spawners/spawner_beam" and result and ColosseumStones.CONFIG.harder_stones_enabled == true then

        local BEAM_DAMAGE = 8 -- 20 is base

        if result.abilities.beam_event_data and result.abilities.beam_event_data.damage_amount then
            result.abilities.beam_event_data.damage_amount = BEAM_DAMAGE
        end
        
        result.on_entity_registered = function(unit)
            if EntityAux.owned(unit) and EntityAux.has_component(unit, "ability") then
                local command = {
                    ability_name = "spawned",
                }
                EntityAux.queue_command_master(unit, "ability", "execute_ability", command)
            end
            Game.scheduler:repeat_action(5, function()  -- 10 is base
                if EntityAux.owned(unit) and DamageReceiverComponent.is_alive(unit) and EntityAux.is_alive_entity(unit) then
                    local command = {
                        ability_name = "beam",
                    }
                    EntityAux.queue_command_master(unit, "ability", "execute_ability", command)
                end
            end)
        end
    end
    -- ==========================================================================================================
    if path == "gameobjects/spawners/spawner_exploding" and result and ColosseumStones.CONFIG.harder_stones_enabled == true then
        result.on_entity_registered = function(unit)
            if EntityAux.owned(unit) and EntityAux.has_component(unit, "ability") then
                local command = {
                    ability_name = "spawned",
                }
                EntityAux.queue_command_master(unit, "ability", "execute_ability", command)
            end
            Game.scheduler:repeat_action(5, function()  -- 10 is base
                if EntityAux.owned(unit) and DamageReceiverComponent.is_alive(unit) and EntityAux.is_alive_entity(unit) then
                    local command = TempTableFactory:get_map("ability_name", "effects")
                    EntityAux.queue_command_master(unit, "ability", "execute_ability", command)
                end
            end)
            Game.scheduler:repeat_action(5, function()  -- 10 is base
                if EntityAux.owned(unit) and DamageReceiverComponent.is_alive(unit) and EntityAux.is_alive_entity(unit) then
                    local time_in_seconds = 2
                    Game.scheduler:delay_action(time_in_seconds, function()
                        if Unit.alive(unit) then
                            local command = TempTableFactory:get_map("ability_name", "reactive_explosion")
                            EntityAux.queue_command_master(unit, "ability", "execute_ability", command)
                        end
                    end)
                end
            end)
        end
    end
    -- ==========================================================================================================
    if path == "gameobjects/spawners/spawner_freeze_nova" and result and ColosseumStones.CONFIG.harder_stones_enabled == true then
        result.on_entity_registered = function(unit)
            if EntityAux.owned(unit) and EntityAux.has_component(unit, "ability") then
                local command = {
                    ability_name = "spawned",
                }
                EntityAux.queue_command_master(unit, "ability", "execute_ability", command)
            end
            Game.scheduler:repeat_action(6, function()  -- 8 is base
                if EntityAux.owned(unit) and DamageReceiverComponent.is_alive(unit) and EntityAux.is_alive_entity(unit) then
                    local command = {
                        ability_name = "freeze_nova",
                    }
                    EntityAux.queue_command_master(unit, "ability", "execute_ability", command)
                end
            end)
        end
    end
    -- ==========================================================================================================
    if path == "gameobjects/spawners/spawner_mortar" and result and ColosseumStones.CONFIG.harder_stones_enabled == true then
        result.ability_selection.mortar_mine.cooldown = 4  -- 8 is base
    end
    -- ==========================================================================================================
    if path == "gameobjects/spawners/spawner_poison_launcher" and result then

        local cooldown

        if ColosseumStones.CONFIG.harder_stones_enabled == true then
            cooldown = 4
        else
            cooldown = 8
        end

        local t = SettingsAux.override_settings("characters/spawner_base", {
            is_ranged_attacker = true,
            spawner_wave_selection = "empty",
            ability_selection = {
                gas_projectile = {
                    cooldown = cooldown,
                    max_distance = 25,
                    min_distance = 6,
                    request_execution = true,
                    use_target_position = true,
                    weight = 1,
                },
            },
            abilities = {
                gas_projectile = {
                    duration = 5,
                    execute = true,
                    flow_events = {
                        {
                            event_name = "on_poison_erupt",
                            time = 0,
                        },
                    },
                    events = {
                        {
                            angle = 30,
                            collision_filter = "floor_only",
                            damage_amount = 0,
                            drag_coefficient = 0.5,
                            effect_type = "arrow",
                            event_duration = 1,
                            event_start = 0,
                            hit_react = "light",
                            marker_unit_path = "spawner_poison_marker",
                            speed_multiplier = 0.5,
                            stagger_origin_type = "direction",
                            type = "projectile_lob",
                            unit_path = "spawner_poison_projectile",
                            origin = {
                                x = 0,
                                y = -0.3,
                                z = 3,
                            },
                            construct_target_position = {
                                distance_max = 15,
                                distance_min = 5,
                            },					
                            on_event_complete = {
                                spawn_entities = {
                                    {
                                        time = 0,
                                        unit_path = "spawner_poison_gascloud",
                                        position_offset = {
                                            x = 0,
                                            y = 0,
                                            z = 0,
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        })
    end
    -- ==========================================================================================================
    if path == "gameobjects/spawners/spawner_twister" and result and ColosseumStones.CONFIG.harder_stones_enabled == true then
        result.on_entity_registered = function(unit)
            if EntityAux.owned(unit) and EntityAux.has_component(unit, "ability") then
                local command = {
                    ability_name = "spawned",
                }
                EntityAux.queue_command_master(unit, "ability", "execute_ability", command)
            end
            Game.scheduler:repeat_action(8, function()  -- 6 is base
                if EntityAux.owned(unit) and DamageReceiverComponent.is_alive(unit) and EntityAux.is_alive_entity(unit) then
                    local command = {
                        ability_name = "summon_twister",
                    }
                    EntityAux.queue_command_master(unit, "ability", "execute_ability", command)
                end
            end)
        end
    end
    -- ==========================================================================================================
    return result
end)