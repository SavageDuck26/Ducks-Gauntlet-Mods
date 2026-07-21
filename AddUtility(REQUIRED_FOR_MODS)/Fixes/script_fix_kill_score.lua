-- =================================================================================================
-- Author: SavageDuck26
-- =================================================================================================

local MOD_NAME = "KillScoreFix"

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/components/stats_component" then

        StatsComponent.command_master = function (self, unit, context, command_name, data)
            local state = context.state

            if command_name == "avatar_killed_something" then
                local victim_type = data.victim_type

                if victim_type == "player" then
                    -- Nothing
                elseif victim_type == "monster" then
                    state.enemy_kills = state.enemy_kills + 1

                    local victim_settings = LuaSettingsManager:get_settings_by_settings_path(data.victim_settings_path)
                    local kill_score = victim_settings.kill_score or 1

                    if data.victim_settings_path and string.find(data.victim_settings_path, "cultist_armor") then -- CHANHE IS HERE
                        kill_score = 25
                    end

                    local killing_spree = state.killing_spree

                    if killing_spree.time_first_kill == nil then
                        killing_spree.time_first_kill = _G.GAME_TIME
                    end

                    killing_spree.kills = killing_spree.kills + 1
                    killing_spree.kill_score = (killing_spree.kill_score or 0) + kill_score

                    if killing_spree.kills >= StatsComponent.KILLING_SPREE_MIN_COUNT then
                        if not killing_spree.in_progress then
                            killing_spree.in_progress = true
                            killing_spree.count = 0
                        end

                        killing_spree.time_updated = _G.GAME_TIME
                        killing_spree.count = killing_spree.count + 1

                        local multiplier = 1 + killing_spree.count * 0.05

                        state.spree_score = killing_spree.kill_score * multiplier
                        state.spree_score = math.clamp(state.spree_score, self.kill_score_increment_info.min, self.kill_score_increment_info.max)

                        local kill_spree_data = TempTableFactory:get_map("kill_score", killing_spree.kill_score, "multiplier", multiplier)

                        self.event_delegate:trigger("on_stat_event", "killing_spree", unit, kill_spree_data, StatEventHud.ALWAYS_SHOW)
                        self:send_killing_spree_info(unit, killing_spree, true)
                    end

                    HydraManager:add_enemy_killed(victim_settings.enemy_type)
                elseif victim_type == "smashable" then
                    state.smashables_smashed = state.smashables_smashed + 1

                    HydraManager:add_prop_destroyed()
                elseif victim_type == "food" then
                    HydraManager:add_shot_the_food()

                    state.food_items_killed = state.food_items_killed + 1
                end
            elseif command_name == "force_end_killing_spree" then
                local killing_spree = state.killing_spree

                if killing_spree.in_progress then
                    _end_kill_streak(self, unit, state, killing_spree)
                end
            elseif command_name == "avatar_killed_by_something" then
                state.deaths = state.deaths + 1

                PerkManager:increase_count_to(unit, "deader_than_dead", state.deaths)
                HydraManager:add_times_died(DifficultyManager:difficulty_setting())

                local death_type

                if data.perp_unit_path then
                    local perp_settings = LuaSettingsManager:get_settings_by_settings_path(data.perp_unit_path)

                    death_type = perp_settings.enemy_type
                else
                    death_type = "environment"
                end

                HydraManager:add_death_by(death_type)
            elseif command_name == "best_mini_boss_killer" then
                -- Nothing
            elseif command_name == "food_consumed" then
                state.food_items_consumed = state.food_items_consumed + 1
                state.food_health_boost = state.food_health_boost + data
            elseif command_name == "treasure_picked_up" then
                local treasure_unit = data
                local treasure_settings = LuaSettingsManager:get_settings_by_unit(treasure_unit).treasure
                local treasure_id = treasure_settings.id
                local has_var = "has_" .. treasure_id

                state[has_var] = true
            elseif command_name == "treasure_dropped" then
                local treasure_unit = data
                local treasure_settings = LuaSettingsManager:get_settings_by_unit(treasure_unit).treasure
                local treasure_id = treasure_settings.id
                local has_var = "has_" .. treasure_id

                state[has_var] = false
            elseif command_name == "clear_stats" then
                StatsComponent:clear_floor_stats(unit, context)
                self:queue_command_slave(unit, self.name, command_name, data)
            end
        end        
    end

    if path == "lua/states/game_server" then
        GameServer.rpc_kill_score_add = function (self, peer_id, amount)
            if self.state == "in_game" then
                if amount and amount >= 500 then -- Only catches Cultist Armor's excessive score
                    amount = 25
                end
                PartyLeadManager:add_kill_score(amount)

                if self.state_game.game_type == _G.GAME_TYPE_COLOSSEUM then
                    PartyLeadManager:add_wave_score(amount)
                end
            end
        end
    end

    return result
end)
