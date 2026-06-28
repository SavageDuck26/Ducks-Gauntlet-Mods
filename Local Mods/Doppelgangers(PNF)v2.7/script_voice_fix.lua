-- =================================================================================================
-- Author: SavageDuck26, Skapp
-- Purpose: Fix voice lines playing on wrong heroes when doppelgangers are present
-- =================================================================================================

local MOD_NAME = "DoppelVoiceFix"

-- Hook the require function to modify stat event handling
Mods.hook:set(MOD_NAME .. "_voice", "require", function(orig, path, ...)
    local result = orig(path, ...)
    
    -- Hook stat_event_hud.lua to use player_go_id instead of avatar_type for identification
    if path == "lua/ui/stat_event_hud" and result then
        -- print("[" .. MOD_NAME .. "] stat_event_hud.lua loaded - fixing voice line targeting")
        
        local StatEventHud = result
        
        if StatEventHud.on_stat_event then
            local original_on_stat_event = StatEventHud.on_stat_event
            
            StatEventHud.on_stat_event = function(self, event_type, player_unit, data, priority)
                -- Get player info using the player_unit (go_id) directly
                -- This ensures we're matching the EXACT player, not just avatar type
                local player_info = PlayerManager:get_player_info(player_unit)
                
                if not player_info then
                    return original_on_stat_event(self, event_type, player_unit, data, priority)
                end
                
                -- Check if this HUD's player_go_id matches the event's player
                -- This is more accurate than avatar_type matching for doppelgangers
                if self.player_go_id and self.player_go_id == player_info.go_id then
                    self:add_stat_event(event_type, player_info.avatar_type, data, priority)
                elseif self.avatar_type == player_info.avatar_type then
                    -- Fallback: If no player_go_id tracking, check avatar_type
                    -- But only if this is the LOCAL player with that avatar type
                    local my_peer_id = Network and Network.peer_id and Network.peer_id() or 1
                    if player_info.peer_id == my_peer_id then
                        self:add_stat_event(event_type, player_info.avatar_type, data, priority)
                    end
                end
            end
        end
        
        -- Also fix the init to track player_go_id
        if StatEventHud.init then
            local original_init = StatEventHud.init
            
            StatEventHud.init = function(self, avatar_type, world_proxy, event_delegate, ...)
                local result = original_init(self, avatar_type, world_proxy, event_delegate, ...)
                
                -- Try to find and store the player_go_id for this avatar_type on our peer
                local my_peer_id = Network and Network.peer_id and Network.peer_id() or 1
                if PlayerManager and PlayerManager.players_iterator then
                    for go_id, info in PlayerManager:players_iterator() do
                        if info.avatar_type == avatar_type and info.peer_id == my_peer_id then
                            self.player_go_id = go_id
                            break
                        end
                    end
                end
                
                return result
            end
        end
    end
    
    -- Hook score_synchronizer.lua to properly handle duplicate avatar types
    if path == "lua/managers/score_synchronizer" and result then
        -- print("[" .. MOD_NAME .. "] score_synchronizer.lua loaded - fixing score attribution")
        
        local ScoreSynchronizer = result
        
        -- Wrap get_mastery_events to handle nil player_info for doppelgangers
        if ScoreSynchronizer.get_mastery_events then
            local original_get_mastery_events = ScoreSynchronizer.get_mastery_events
            ScoreSynchronizer.get_mastery_events = function(self, avatar_type)
                local success, result_or_err = pcall(function()
                    return original_get_mastery_events(self, avatar_type)
                end)
                if success then
                    return result_or_err
                end
                -- Return nil on error to prevent crashes
                return nil
            end
        end
        
        -- Wrap get_banked_gold to handle nil player_info for doppelgangers
        if ScoreSynchronizer.get_banked_gold then
            local original_get_banked_gold = ScoreSynchronizer.get_banked_gold
            ScoreSynchronizer.get_banked_gold = function(self, avatar_type)
                local success, result_or_err = pcall(function()
                    return original_get_banked_gold(self, avatar_type)
                end)
                if success then
                    return result_or_err
                end
                -- Return 0 on error to prevent crashes
                return 0
            end
        end
        
        -- Wrap get_colosseum_reward to handle nil player_info for doppelgangers
        if ScoreSynchronizer.get_colosseum_reward then
            local original_get_colosseum_reward = ScoreSynchronizer.get_colosseum_reward
            ScoreSynchronizer.get_colosseum_reward = function(self, floor_id, avatar_type)
                local success, cape_unlock, gold_bonus = pcall(function()
                    return original_get_colosseum_reward(self, floor_id, avatar_type)
                end)
                if success then
                    return cape_unlock, gold_bonus
                end
                -- Return nil on error to prevent crashes
                return nil, nil
            end
        end
    end
    
    -- Hook the narrator/voice event triggering to use correct player identification
    if path == "gui/player_hud_ui" and result then
        -- print("[" .. MOD_NAME .. "] player_hud_ui.lua loaded - adding player_go_id tracking")
        
        local PlayerHudUI = result
        
        if PlayerHudUI.set_player_info then
            local original_set_player_info = PlayerHudUI.set_player_info
            
            PlayerHudUI.set_player_info = function(self, player_info)
                if player_info then
                    -- Track the player_go_id for accurate event targeting
                    self.player_go_id = player_info.go_id
                    
                    -- Ensure name is set
                    if not player_info.name and player_info.controller_name then
                        player_info.name = player_info.controller_name
                    end
                end
                return original_set_player_info(self, player_info)
            end
        end
    end
    
    return result
end)
