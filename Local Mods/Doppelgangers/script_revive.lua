
local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Host: keep the skullcoin revive working when two players share a hero."


local MOD_NAME, log_message = Mods.init_mod()

-- rpc_revive_request grants a revive by calling GameServer.revive_player, which resolves the
-- respawning player's owner with EntityAux.owner_go_id and hands that straight to
-- network_router:transmit_to. Two players on one hero can leave that lookup empty, and transmit_to
-- then dials the RPC with a nil peer, taking the host down mid-revive. Rebuild the same revive with
-- the two guards it is missing: a nil owner falls back to the player's own peer, and a missing
-- player_info stops the revive instead of indexing nil. Everything else matches the engine.
local function revive_player_safely(self, player_go_id)
    local player_info = PlayerManager:get_player_info(player_go_id)

    if not player_info then
        return
    end

    local owner = EntityAux.owner_go_id(player_go_id) or player_info.peer_id

    if not owner then
        return
    end

    player_info.reviving_in_progress = true

    local position = self:get_spawn_position(player_go_id) or CameraManager:get_focus_position()
    local camera_spin = CameraManager:get_spin()
    local rotation = Quaternion(Vector3.up(), math.pi + camera_spin)

    self.network_router:transmit_to(owner, "from_server_spawn_avatar", player_go_id, position, rotation)
    self.network_router:transmit_to(owner, "from_server_revive_request_granted", player_go_id)
end

Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    -- GameServer only exists on the host, and the host check keeps the engine's own revive in
    -- charge anywhere else.
    if path == "lua/states/game_server" and GameServer then
        Mods.hook:set_object_path("GameServer", "revive_player", function(orig2, self, player_go_id)
            if not _G.is_host_ducks_mods then
                return orig2(self, player_go_id)
            end

            revive_player_safely(self, player_go_id)
        end, MOD_NAME .. ".GameServer.revive_player", MOD_NAME)
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)
