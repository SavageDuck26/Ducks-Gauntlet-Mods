-- =================================================================================================
-- Author: SavageDuck26, Skapp
-- Purpose: Hotjoin/game client hooks for Doppelgangers mod
-- =================================================================================================

local MOD_NAME = "DoppelHotJoin"

-- Hook the require function to modify classes after they're loaded
Mods.hook:set(MOD_NAME .. "_hotjoin", "require", function(orig, path, ...)
    local result = orig(path, ...)
    
    -- Hook game_client.lua to handle hotjoin character selection
    if path == "lua/states/game_client" and GameClient then
        -- print("[" .. MOD_NAME .. "] game_client.lua loaded - enabling duplicate character selection for hotjoin")
        
        -- Store original functions
        local original_is_controller_taken = GameClient.is_controller_taken
        local original_hero_selected = GameClient.hero_selected
        local original_set_available_heroes = GameClient.set_available_heroes
        local original_revive_avatar = GameClient.revive_avatar
        local original_spawn_avatar = GameClient.spawn_avatar
        local original_find_or_create_player_for_controller = GameClient.find_or_create_player_for_controller
        
        -- Override is_controller_taken to allow multiple players on same character
        GameClient.is_controller_taken = function(self, controller_name)
            return false -- Always allow controller assignment
        end
        
        -- Override find_or_create_player_for_controller to properly set player names
        GameClient.find_or_create_player_for_controller = function(self, controller_name)
            for go_id, player_info in PlayerManager:local_players_iterator() do
                if player_info.controller_name == controller_name then
                    -- Sync player data to all clients if we're host
                    if Network and Network.peer_id and Network.peer_id() == 1 then
                        local user = ProfileManager:get_user(controller_name)
                        local player_name = user and Platform:username(user.user_id) or controller_name
                        if not player_info.name or player_info.name ~= player_name then
                            player_info.name = player_name
                            PlayerManager:set_local_player_name(go_id, player_name)
                            -- Broadcast to all peers
                            for peer_id = 2, 4 do
                                if Network.has_peer and Network.has_peer(peer_id) then
                                    Network.send_rpc(peer_id, "sync_player_data", {
                                        player_go_id = go_id,
                                        user_name = player_name,
                                        controller_name = controller_name,
                                        avatar_type = player_info.avatar_type
                                    })
                                end
                            end
                        end
                    end
                    return go_id, false
                end
            end
            
            local player_unit, go_id = self.entity_spawner:spawn_entity("gameobjects/player/player", Vector3.zero())
            
            PlayerManager:set_player_controller_name(player_unit, controller_name)
            
            local user = ProfileManager:get_user(controller_name)
            local player_name = Platform:username(user.user_id)
            
            PlayerManager:set_local_player_name(go_id, player_name)
            
            -- Sync new player data to all clients if we're host
            if Network and Network.peer_id and Network.peer_id() == 1 then
                for peer_id = 2, 4 do
                    if Network.has_peer and Network.has_peer(peer_id) then
                        Network.send_rpc(peer_id, "sync_player_data", {
                            player_go_id = go_id,
                            user_name = player_name,
                            controller_name = controller_name,
                            avatar_type = nil
                        })
                    end
                end
            end
            
            return go_id, true
        end
        
        -- Override hero_selected to allow duplicate character selection
        GameClient.hero_selected = function(self, controller_name, avatar_type, loadout_ids)
            -- print("[" .. MOD_NAME .. "] Hotjoin hero selected: " .. avatar_type .. " for controller: " .. controller_name)
            
            -- Force assignment regardless of server restrictions
            if PartyManager and PartyManager.get_player_info_by_controller_name then
                local player_info = PartyManager:get_player_info_by_controller_name(controller_name)
                if player_info then
                    player_info.avatar_type = avatar_type
                    player_info.loadout_ids = loadout_ids
                    
                    -- Get user information for proper name assignment
                    local user_name = controller_name
                    if ProfileManager and ProfileManager.get_user then
                        local user = ProfileManager:get_user(controller_name)
                        if user and user.user_id then
                            user_name = Platform:username(user.user_id) or controller_name
                        end
                    end
                    
                    -- print("[" .. MOD_NAME .. "] Forced hotjoin assignment - sending to server")
                    
                    -- Send custom network message to force server acceptance
                    if Network and Network.send_rpc then
                        Network.send_rpc(1, "force_hotjoin_assignment", {
                            controller_name = controller_name,
                            avatar_type = avatar_type,
                            loadout_ids = loadout_ids,
                            player_go_id = player_info.go_id or 0,
                            user_name = user_name -- Include username for proper assignment
                        })
                    end
                    
                    return true
                end
            end
            
            -- Fallback to original if PartyManager not available
            return original_hero_selected(self, controller_name, avatar_type, loadout_ids)
        end
        
        -- Override set_available_heroes to always allow all heroes
        GameClient.set_available_heroes = function(self, available_heroes)
            -- print("[" .. MOD_NAME .. "] Setting available heroes for hotjoin - allowing all duplicates")
            
            -- Safety checks
            if not AvatarSettings or not AvatarSettings.avatars then
                return original_set_available_heroes(self, available_heroes)
            end
            
            -- Make all heroes available regardless of current assignments
            local all_heroes = {}
            for _, hero_name in ipairs(AvatarSettings.avatars) do
                all_heroes[hero_name] = true
            end
            
            self.available_heroes_bimap = table.make_bimap(AvatarSettings.avatars)
            
            if self.event_delegate then
                self.event_delegate:trigger("on_available_heroes_changed", self.available_heroes_bimap)
            end
        end
    end
    
    -- Hook gui/player_hud_*.lua files to ensure proper HUD display for doppelgangers
    if path == "gui/player_hud_alive_ui.lua" then
        -- print("[" .. MOD_NAME .. "] player_hud_alive_ui.lua loaded - fixing black HUD for doppelgangers")
        
        if result and type(result) == "table" then
            local PlayerHudAliveUI = result
            
            if PlayerHudAliveUI.set_player_info then
                local original_set_player_info = PlayerHudAliveUI.set_player_info
                PlayerHudAliveUI.set_player_info = function(self, player_info)
                    if player_info then
                        -- Ensure player has valid display name
                        if not player_info.name and player_info.controller_name then
                            player_info.name = player_info.controller_name
                        end
                        -- Ensure avatar_type is set for HUD display
                        if not player_info.avatar_type and player_info.go_id then
                            local updated_info = PlayerManager:get_player_info(player_info.go_id)
                            if updated_info and updated_info.avatar_type then
                                player_info.avatar_type = updated_info.avatar_type
                            end
                        end
                    end
                    return original_set_player_info(self, player_info)
                end
            end
        end
    end
    
    if path == "gui/player_hud_ui.lua" then
        -- print("[" .. MOD_NAME .. "] player_hud_ui.lua loaded - fixing general HUD for doppelgangers")
        
        if result and type(result) == "table" then
            local PlayerHudUI = result
            
            if PlayerHudUI.set_player_info then
                local original_set_player_info = PlayerHudUI.set_player_info
                PlayerHudUI.set_player_info = function(self, player_info)
                    if player_info then
                        -- Ensure proper player identification for HUD
                        if not player_info.name and player_info.controller_name then
                            player_info.name = player_info.controller_name
                        end
                        if not player_info.avatar_type and player_info.go_id then
                            local updated_info = PlayerManager:get_player_info(player_info.go_id)
                            if updated_info and updated_info.avatar_type then
                                player_info.avatar_type = updated_info.avatar_type
                            end
                        end
                    end
                    return original_set_player_info(self, player_info)
                end
            end
            
            -- Override update to refresh player info for duplicates
            if PlayerHudUI.update then
                local original_update = PlayerHudUI.update
                PlayerHudUI.update = function(self, dt, ...)
                    -- Refresh player info if it seems incomplete
                    if self.player_info and self.player_info.go_id and (not self.player_info.avatar_type or not self.player_info.name) then
                        local fresh_info = PlayerManager:get_player_info(self.player_info.go_id)
                        if fresh_info then
                            if not self.player_info.avatar_type and fresh_info.avatar_type then
                                self.player_info.avatar_type = fresh_info.avatar_type
                            end
                            if not self.player_info.name and fresh_info.name then
                                self.player_info.name = fresh_info.name
                            end
                        end
                    end
                    return original_update(self, dt, ...)
                end
            end
        end
    end
    
    return result
end)

