-- =================================================================================================
-- Author: SavageDuck26, Skapp
-- Purpose: Network RPC handlers for Doppelgangers mod
-- =================================================================================================

local MOD_NAME = "DoppelNetwork"

-- Track if network RPCs are registered
local rpcs_registered = false

-- Safe RPC registration that won't break for non-mod players
local function safe_register_rpc(name, handler)
    if Network and Network.register_rpc then
        local success, err = pcall(function()
            Network.register_rpc(name, handler)
        end)
        if not success then
            -- print("[" .. MOD_NAME .. "] Warning: Could not register RPC " .. name .. ": " .. tostring(err))
        end
    end
end

-- Register network RPCs if available
if Network and Network.register_rpc and not rpcs_registered then
    rpcs_registered = true
    
    -- Force hotjoin assignment - only used between mod users
    safe_register_rpc("force_hotjoin_assignment", function(sender_peer_id, assignment_data)
        -- print("[" .. MOD_NAME .. "] Host received force hotjoin request")
        local ok, err = pcall(function()
            -- Validate player_go_id
            if not assignment_data.player_go_id or assignment_data.player_go_id == 0 then
                if assignment_data.controller_name and PlayerManager then
                    local player_info = PlayerManager:get_player_info_by_controller_name(assignment_data.controller_name)
                    if player_info then
                        assignment_data.player_go_id = player_info.go_id
                    end
                end
                if not assignment_data.player_go_id or assignment_data.player_go_id == 0 then
                    return
                end
            end
            
            -- Force accept the hotjoin request on server side
            if PartyLeadManager and PartyLeadManager.assign_player_type then
                PartyLeadManager:assign_player_type(assignment_data.player_go_id, assignment_data.avatar_type)
            end
            
            -- Update PlayerManager if available
            if PlayerManager and PlayerManager.get_player_info then
                local player_info = PlayerManager:get_player_info(assignment_data.player_go_id)
                if player_info then
                    player_info.avatar_type = assignment_data.avatar_type
                    player_info.loadout_ids = assignment_data.loadout_ids
                    if assignment_data.user_name and not player_info.name then
                        player_info.name = assignment_data.user_name
                        if PlayerManager.set_local_player_name then
                            PlayerManager:set_local_player_name(assignment_data.player_go_id, assignment_data.user_name)
                        end
                    end
                end
            end
        end)
        if not ok then
            -- print("[" .. MOD_NAME .. "] Error in force_hotjoin_assignment: " .. tostring(err))
        end
    end)
    
    -- Sync player data between peers
    safe_register_rpc("sync_player_data", function(sender_peer_id, player_data)
        local ok, err = pcall(function()
            if PlayerManager and PlayerManager.get_player_info and player_data.player_go_id then
                local player_info = PlayerManager:get_player_info(player_data.player_go_id)
                if player_info then
                    if player_data.user_name and player_data.user_name ~= "" then
                        player_info.name = player_data.user_name
                        player_info.user_name = player_data.user_name
                    end
                    if player_data.controller_name then
                        player_info.controller_name = player_data.controller_name
                    end
                    if player_data.avatar_type then
                        player_info.avatar_type = player_data.avatar_type
                    end
                end
            end
        end)
        if not ok then
            -- print("[" .. MOD_NAME .. "] Error in sync_player_data: " .. tostring(err))
        end
    end)
    
    -- Register revive request RPC
    safe_register_rpc("rpc_revive_request", function(sender_peer_id, player_go_id)
        -- This will be handled by GameServer when server hooks are loaded
    end)
end

