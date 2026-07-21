-- =================================================================================================
-- Author: SavageDuck26, Skapp
-- Version: 2.6
-- Purpose: Revive functionality for Doppelgangers mod - Fixed simultaneous revive crashes
-- =================================================================================================

local MOD_NAME = "DoppelRevive"

-- Hook the require function to modify classes after they're loaded

-- Global revive toggle (set by main script)
revive_toggle = revive_toggle ~= false -- default to true unless set false

-- Track pending revive requests to prevent race conditions
local pending_revives = {}

Mods.hook:set(MOD_NAME .. "_revive", "require", function(orig, path, ...)
    local result = orig(path, ...)
    -- Only run revive code if revive_toggle is true AND DeadMansHand is NOT active
    if revive_toggle and not _G.deadmanshand_active and path == "lua/states/game_client" and GameClient then
        -- Store original functions
        local original_revive_avatar = GameClient.revive_avatar
        local original_spawn_avatar = GameClient.spawn_avatar
        -- Override revive_avatar to use server-side coordination like the original game
        GameClient.revive_avatar = function(self, avatar_unit)
            -- print("[" .. MOD_NAME .. "] Revive attempt for avatar_unit: " .. tostring(avatar_unit))
            -- Guard against invalid input (same as original)
            if not avatar_unit or not Unit.alive(avatar_unit) then
                -- print("[" .. MOD_NAME .. "] Cannot revive: invalid or dead avatar unit")
                return nil
            end
            -- Get player info (same as original)
            local player_info = PlayerManager:get_player_info_by_avatar(avatar_unit)
            if not player_info then
                -- print("[" .. MOD_NAME .. "] Cannot revive: no player info found for avatar")
                return nil
            end
            local player_go_id = player_info.go_id
            if not player_go_id then
                -- print("[" .. MOD_NAME .. "] Cannot revive: player info has no go_id")
                return nil
            end
            
            -- Prevent duplicate revive requests (race condition protection)
            if pending_revives[player_go_id] then
                -- print("[" .. MOD_NAME .. "] Revive already pending for player: " .. tostring(player_go_id))
                return nil
            end
            pending_revives[player_go_id] = true
            
            -- print("[" .. MOD_NAME .. "] Requesting revive for go_id: " .. tostring(player_go_id))
            -- KEY FIX: Use server-side coordination with correct RPC name like original game
            -- Instead of calling spawn_avatar directly, send a revive request to the server
            if Network and Network.peer_id() ~= 1 then
                -- Client: Send revive request to server using the correct RPC name
                self.network_router:transmit_to(1, "rpc_revive_request", player_go_id)
                -- print("[" .. MOD_NAME .. "] Sent revive request to server for player: " .. tostring(player_go_id))
                
                -- Clear pending flag after a timeout to allow retry if request fails
                if self.scheduler then
                    self.scheduler:after(3.0, function()
                        pending_revives[player_go_id] = nil
                    end)
                end
                
                return nil -- Don't spawn directly on client
            else
                -- Server/Host: Process revive directly (like original game server logic)
                local position = Unit.local_position(avatar_unit, 0)
                local rotation = Unit.local_rotation(avatar_unit, 0)
                -- Use server-side spawn coordination
                self.network_router:transmit_to(player_info.peer_id or Network.peer_id(), "from_server_spawn_avatar_with_hp_ratio", player_go_id, position, rotation, 1.0)
                -- print("[" .. MOD_NAME .. "] Server sent spawn command for player: " .. tostring(player_go_id))
                
                -- Clear pending flag after spawn
                pending_revives[player_go_id] = nil
                
                return player_go_id
            end
        end
        -- Override spawn_avatar to use the original game's simple approach with minimal changes
        GameClient.spawn_avatar = function(self, player_go_id, position, rotation, hitpoint_ratio)
            -- print("[" .. MOD_NAME .. "] Spawning avatar for player_go_id: " .. tostring(player_go_id))
            
            -- Clear any pending revive flag when spawn actually happens
            if player_go_id then
                pending_revives[player_go_id] = nil
            end
            
            -- Basic validation (keep it minimal like original)
            local player_info = PlayerManager:get_player_info(player_go_id)
            if not player_info then
                -- print("[" .. MOD_NAME .. "] Error: No player info found for go_id: " .. tostring(player_go_id))
                return nil
            end
            -- Default position/rotation if needed (like original)
            position = position or Vector3.zero()
            rotation = rotation or Quaternion.identity()
            -- print("[" .. MOD_NAME .. "] Calling original spawn_avatar for avatar_type: " .. tostring(player_info.avatar_type))
            -- Call original spawn_avatar directly (simple approach like hotjoin)
            return original_spawn_avatar(self, player_go_id, position, rotation, hitpoint_ratio)
        end
        
        -- Clear pending revive when request is denied
        local original_from_server_revive_request_denied = GameClient.from_server_revive_request_denied
        GameClient.from_server_revive_request_denied = function(self, sender, player_go_id)
            -- Clear pending flag
            if player_go_id then
                pending_revives[player_go_id] = nil
            end
            
            -- Call original if exists
            if original_from_server_revive_request_denied then
                return original_from_server_revive_request_denied(self, sender, player_go_id)
            end
            
            -- Default behavior: reset revive_request_sent
            local player_info = PlayerManager:get_player_info(player_go_id)
            if player_info then
                player_info.revive_request_sent = false
            end
        end
    end
    return result
end)

