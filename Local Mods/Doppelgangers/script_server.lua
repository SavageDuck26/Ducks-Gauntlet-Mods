-- =================================================================================================
-- Author: SavageDuck26, Skapp
-- Purpose: Game server hooks for Doppelgangers mod
-- =================================================================================================

local MOD_NAME = "DoppelServer"

server_toggle = server_toggle ~= false -- default to true unless set false

Mods.hook:set(MOD_NAME .. "_server", "require", function(orig, path, ...)
    local result = orig(path, ...)
    
    -- Hook game_server.lua to handle server-side hotjoin logic
    -- Only run server code if server_toggle is true
    if server_toggle and path == "lua/states/game_server" and GameServer then
        -- print("[" .. MOD_NAME .. "] game_server.lua loaded - enabling server-side duplicate character support")
        
        -- Store original function
        local original_handle_from_client_player_drop_in_request = GameServer.handle_from_client_player_drop_in_request
        
        -- Override the actual drop-in handling to allow duplicate characters
        GameServer.handle_from_client_player_drop_in_request = function(self, peer_id, player_go_id, avatar_type, optional_position, optional_rotation)
            -- print("[" .. MOD_NAME .. "] Server handling drop-in request - peer: " .. peer_id .. ", player: " .. player_go_id .. ", avatar: " .. avatar_type)
            
            -- Check if player is already in the party
            for index, go_id in PartyLeadManager:players_iterator() do
                if go_id == player_go_id then
                    -- print("[" .. MOD_NAME .. "] Player already in party, returning")
                    return
                end
            end

            -- Always accept the request (skip the avatar_type_in_use check)
            local accepted = true
            
            -- print("[" .. MOD_NAME .. "] Accepting duplicate character selection: " .. avatar_type)

            self.network_router:transmit_to(peer_id, "from_server_player_drop_in_reply", player_go_id, accepted)

            if accepted then
                PartyLeadManager:add_player(player_go_id)
                PartyLeadManager:assign_player_type(player_go_id, avatar_type)

                local info = PlayerManager:get_player_info(player_go_id)

                if self.state == "in_game" then
                    if _G.GAME_TIME - self.floor_start_time < 1 then
                        self.delayed_entrance_spawns[#self.delayed_entrance_spawns + 1] = {
                            peer_id = peer_id,
                            player_go_id = player_go_id,
                            time_to_spawn = self.floor_start_time + 0.75,
                        }
                    else
                        -- Use the same logic as the original game for hotjoin spawning
                        local peer_info = self.dropped_player_infos[peer_id]
                        local controller_name = info.controller_name or "no_controller"

                        if peer_info and peer_info[controller_name] then
                            -- Player was dropped before, restore with HP ratio
                            local hitpoint_ratio = peer_info[controller_name]
                            self.dropped_player_infos[peer_id] = nil
                            
                            local position = optional_position or self:get_spawn_position(player_go_id)
                            local camera_spin = CameraManager:get_spin()
                            local rotation = optional_rotation or Quaternion(Vector3.up(), math.pi + camera_spin)
                            
                            self.network_router:transmit_to(peer_id, "from_server_spawn_avatar_with_hp_ratio", player_go_id, position, rotation, hitpoint_ratio)
                        elseif optional_position == nil then
                            -- FIX: For first-time hotjoin, spawn near the host instead of at the entrance
                            -- Use the camera's focus position (near the host) and calculate rotation
                            local position = CameraManager:get_focus_position()
                            local camera_spin = CameraManager:get_spin()
                            local rotation = Quaternion(Vector3.up(), math.pi + camera_spin)
                            
                            self.network_router:transmit_to(peer_id, "from_server_spawn_avatar", player_go_id, position, rotation)
                        else
                            -- Specific position provided
                            self.network_router:transmit_to(peer_id, "from_server_spawn_avatar", player_go_id, optional_position, optional_rotation)
                        end
                    end
                end
            end
        end
        
        -- Add server-side revive request handler using correct RPC name (like original game server)
        -- Only override if DeadMansHand is NOT active (DeadMansHand handles revive denial itself)
        if not _G.deadmanshand_active then
            GameServer.rpc_revive_request = function(self, peer_id, player_go_id)
                -- print("[" .. MOD_NAME .. "] Server received revive request RPC from peer: " .. peer_id .. " for player: " .. player_go_id)
                
                -- Guard against nil player_go_id
                if not player_go_id then
                    -- print("[" .. MOD_NAME .. "] Server: player_go_id is nil, ignoring request")
                    return
                end
                
                local player_info = PlayerManager:get_player_info(player_go_id)
                if not player_info then
                    -- print("[" .. MOD_NAME .. "] Server: No player info found for revive request")
                    self.network_router:transmit_to(peer_id, "from_server_revive_request_denied", player_go_id)
                    return
                end
                
                -- NEW: Check if the party has skull coins before allowing revive
                if not PartyLeadManager:has_skull_coins() then
                    -- print("[" .. MOD_NAME .. "] Server: Revive request denied - no skull coins available")
                    self.network_router:transmit_to(peer_id, "from_server_revive_request_denied", player_go_id)
                    return
                end
                
                -- Check if player can be revived (same logic as original game server)
                -- Use pcall to protect against race conditions
                if not player_info.reviving_in_progress then
                    -- print("[" .. MOD_NAME .. "] Server: Granting revive request for player: " .. player_go_id)
                    
                    -- Mark player as reviving FIRST to prevent duplicate requests (race condition protection)
                    player_info.reviving_in_progress = true
                    
                    -- NEW: Deduct 1 skull coin on successful revive
                    PartyLeadManager:use_skull_coin()
                    
                    -- Get spawn position (like original game server)
                    local position = self:get_spawn_position(player_go_id) or CameraManager:get_focus_position()
                    local camera_spin = CameraManager:get_spin()
                    local rotation = Quaternion(Vector3.up(), math.pi + camera_spin)
                    local owner = EntityAux.owner_go_id(player_go_id)
                    
                    -- Guard against nil owner (can happen with doppelgangers)
                    if not owner then
                        owner = peer_id
                    end
                    
                    -- Send spawn command to client with HP ratio (like original game server)
                    self.network_router:transmit_to(owner, "from_server_spawn_avatar_with_hp_ratio", player_go_id, position, rotation, 1.0)
                    self.network_router:transmit_to(owner, "from_server_revive_request_granted", player_go_id)
                    
                    -- Schedule clearing the reviving_in_progress flag after a short delay
                    -- This ensures the spawn completes before allowing another revive attempt
                    if self.scheduler then
                        self.scheduler:after(1.0, function()
                            local check_info = PlayerManager:get_player_info(player_go_id)
                            if check_info then
                                check_info.reviving_in_progress = false
                            end
                        end)
                    else
                        -- Fallback: clear immediately if no scheduler available
                        player_info.reviving_in_progress = false
                    end
                else
                    -- print("[" .. MOD_NAME .. "] Server: Revive request denied - already reviving player: " .. player_go_id)
                    self.network_router:transmit_to(peer_id, "from_server_revive_request_denied", player_go_id)
                end
            end
        end -- End of DeadMansHand check
    end
    
    -- Hook party_lead_manager.lua to disable duplicate character checking
    if path == "lua/managers/party_lead_manager" and PartyLeadManager then
        -- print("[" .. MOD_NAME .. "] party_lead_manager.lua loaded - disabling duplicate character restrictions")
        
        -- Store original function
        local original_is_avatar_type_in_use = PartyLeadManager.is_avatar_type_in_use
        
        -- Override to always allow character selection (like in lobby)
        PartyLeadManager.is_avatar_type_in_use = function(self, avatar_type)
            -- print("[" .. MOD_NAME .. "] Checking avatar type in use: " .. avatar_type .. " - allowing duplicate")
            return false -- Always allow duplicate characters
        end
    end
    
    -- Hook gui/player_hud_alive_ui.lua to handle doppelganger HUD display
    if path == "gui/player_hud_alive_ui.lua" then
        -- print("[" .. MOD_NAME .. "] player_hud_alive_ui.lua loaded - enabling doppelganger HUD support")
        
        -- Check if the module loaded properly and has the expected structure
        if result and type(result) == "table" then
            local PlayerHudAliveUI = result
            
            -- Store original functions if they exist
            if PlayerHudAliveUI.init then
                local original_init = PlayerHudAliveUI.init
                PlayerHudAliveUI.init = function(self, ...)
                    local result = original_init(self, ...)
                    -- print("[" .. MOD_NAME .. "] PlayerHudAliveUI initialized for doppelganger support")
                    return result
                end
            end
            
            -- Override player info retrieval to handle duplicates
            if PlayerHudAliveUI.set_player_info then
                local original_set_player_info = PlayerHudAliveUI.set_player_info
                PlayerHudAliveUI.set_player_info = function(self, player_info)
                    if player_info then
                        -- print("[" .. MOD_NAME .. "] Setting player info for HUD: " .. tostring(player_info.name or player_info.controller_name))
                        -- Ensure player has valid display info even if it's a duplicate
                        if not player_info.name and player_info.controller_name then
                            player_info.name = player_info.controller_name
                        end
                    end
                    return original_set_player_info(self, player_info)
                end
            end
        end
    end

    -- Hook gui/player_hud_dead_ui.lua to handle doppelganger death HUD
    if path == "gui/player_hud_dead_ui.lua" then
        -- print("[" .. MOD_NAME .. "] player_hud_dead_ui.lua loaded - enabling doppelganger death HUD support")
        
        if result and type(result) == "table" then
            local PlayerHudDeadUI = result
            
            if PlayerHudDeadUI.init then
                local original_init = PlayerHudDeadUI.init
                PlayerHudDeadUI.init = function(self, ...)
                    local result = original_init(self, ...)
                    -- print("[" .. MOD_NAME .. "] PlayerHudDeadUI initialized for doppelganger support")
                    return result
                end
            end
            
            if PlayerHudDeadUI.set_player_info then
                local original_set_player_info = PlayerHudDeadUI.set_player_info
                PlayerHudDeadUI.set_player_info = function(self, player_info)
                    if player_info then
                        -- print("[" .. MOD_NAME .. "] Setting dead player info for HUD: " .. tostring(player_info.name or player_info.controller_name))
                        if not player_info.name and player_info.controller_name then
                            player_info.name = player_info.controller_name
                        end
                    end
                    return original_set_player_info(self, player_info)
                end
            end
        end
    end

    -- Hook gui/player_hud_ui.lua to handle general doppelganger HUD display
    if path == "gui/player_hud_ui.lua" then
        -- print("[" .. MOD_NAME .. "] player_hud_ui.lua loaded - enabling doppelganger general HUD support")
        
        if result and type(result) == "table" then
            local PlayerHudUI = result
            
            if PlayerHudUI.init then
                local original_init = PlayerHudUI.init
                PlayerHudUI.init = function(self, ...)
                    local result = original_init(self, ...)
                    -- print("[" .. MOD_NAME .. "] PlayerHudUI initialized for doppelganger support")
                    return result
                end
            end
            
            -- Override update to ensure proper player tracking for duplicates
            if PlayerHudUI.update then
                local original_update = PlayerHudUI.update
                PlayerHudUI.update = function(self, dt, ...)
                    -- Ensure we have valid player references even with duplicates
                    if self.player_info and not self.player_info.name and self.player_info.controller_name then
                        self.player_info.name = self.player_info.controller_name
                    end
                    return original_update(self, dt, ...)
                end
            end
            
            if PlayerHudUI.set_player_info then
                local original_set_player_info = PlayerHudUI.set_player_info
                PlayerHudUI.set_player_info = function(self, player_info)
                    if player_info then
                        -- print("[" .. MOD_NAME .. "] Setting general player info for HUD: " .. tostring(player_info.name or player_info.controller_name))
                        if not player_info.name and player_info.controller_name then
                            player_info.name = player_info.controller_name
                        end
                    end
                    return original_set_player_info(self, player_info)
                end
            end
        end
    end

    -- Hook gui/player_hud_wizard_ui.lua to handle wizard-specific doppelganger HUD
    if path == "gui/player_hud_wizard_ui.lua" then
        -- print("[" .. MOD_NAME .. "] player_hud_wizard_ui.lua loaded - enabling wizard doppelganger HUD support")
        
        if result and type(result) == "table" then
            local PlayerHudWizardUI = result
            
            if PlayerHudWizardUI.init then
                local original_init = PlayerHudWizardUI.init
                PlayerHudWizardUI.init = function(self, ...)
                    local result = original_init(self, ...)
                    -- print("[" .. MOD_NAME .. "] PlayerHudWizardUI initialized for doppelganger support")
                    return result
                end
            end
            
            if PlayerHudWizardUI.set_player_info then
                local original_set_player_info = PlayerHudWizardUI.set_player_info
                PlayerHudWizardUI.set_player_info = function(self, player_info)
                    if player_info then
                        -- print("[" .. MOD_NAME .. "] Setting wizard player info for HUD: " .. tostring(player_info.name or player_info.controller_name))
                        if not player_info.name and player_info.controller_name then
                            player_info.name = player_info.controller_name
                        end
                    end
                    return original_set_player_info(self, player_info)
                end
            end
        end
    end

    return result
end)

