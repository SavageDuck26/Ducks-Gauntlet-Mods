
local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Host: keep the skullcoin revive working when two players share a hero."


local MOD_NAME, log_message = Mods.init_mod()

-- rpc_revive_request grants a revive by calling GameServer.revive_player, which resolves the
-- respawning player's owner with EntityAux.owner_go_id and hands that straight to
-- network_router:transmit_to. Two players on one hero can leave that lookup empty, and transmit_to
-- then dials the RPC with a nil peer, taking the host down mid-revive. Rebuild the same revive with
-- the two guards it is missing: a nil owner falls back to the player's own peer, and a missing
-- player_info stops the revive instead of indexing nil. Everything else matches the engine.
-- Engine positions are untrusted: a dead player leaves get_spawn_position with no living friend to
-- fall back on, so it can hand back a stale last_ground_position (or nil) from outside the floor,
-- and the owner client then spawns the avatar at it and the engine can spin. NaN fails x == x,
-- infinity fails the magnitude bound, so one check covers both. This file guards both ends of that
-- payload on the host: get_spawn_position (used by revives AND drop-ins) and the revive grant.
local POSITION_LIMIT = 100000

local function is_finite(position)
    if not position then
        return false
    end

    local x, y, z = position.x, position.y, position.z

    return x == x and y == y and z == z
        and math.abs(x) < POSITION_LIMIT and math.abs(y) < POSITION_LIMIT and math.abs(z) < POSITION_LIMIT
end

local function revive_player_safely(self, player_go_id, hp_ratio)
    local player_info = PlayerManager:get_player_info(player_go_id)

    if not player_info then
        return
    end

    local owner = EntityAux.owner_go_id(player_go_id) or player_info.peer_id

    if not owner then
        return
    end

    local position = self:get_spawn_position(player_go_id)

    if not is_finite(position) then
        position = CameraManager:get_focus_position()
    end

    -- Do not flag the revive until a usable position exists, or a skipped revive would leave the
    -- flag set and the player could never revive again.
    if not is_finite(position) then
        return
    end

    local camera_spin = CameraManager:get_spin()
    local rotation = Quaternion(Vector3.up(), math.pi + camera_spin)

    player_info.reviving_in_progress = true

    -- The plain revive sends no ratio (full health, like the engine); the hp-ratio entry point
    -- (necromagus talisman) supplies its own.
    if hp_ratio ~= nil then
        self.network_router:transmit_to(owner, "from_server_spawn_avatar_with_hp_ratio", player_go_id, position, rotation, hp_ratio)
    else
        self.network_router:transmit_to(owner, "from_server_spawn_avatar", player_go_id, position, rotation)
    end

    self.network_router:transmit_to(owner, "from_server_revive_request_granted", player_go_id)
end

Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    -- GameServer only exists on the host, and the host check keeps the engine's own revive in
    -- charge anywhere else.
    if path == "lua/states/game_server" and GameServer then
        Mods.hook:set_object_path("GameServer", "revive_player", function(orig2, self, player_go_id)
            if not Doppelgangers.is_host() then
                return orig2(self, player_go_id)
            end

            revive_player_safely(self, player_go_id)
        end, MOD_NAME .. ".GameServer.revive_player", MOD_NAME)

        -- rpc_revive_with_hp_ratio_request (necromagus talisman) builds its own transmit and resolves
        -- the owner with the same unguarded EntityAux.owner_go_id, so it needs the rebuild too: it is
        -- the third of the three revive entry points and the only one the revive_player hook misses.
        Mods.hook:set_object_path("GameServer", "rpc_revive_with_hp_ratio_request", function(orig2, self, sender, player_go_id, hp_ratio)
            if not Doppelgangers.is_host() then
                return orig2(self, sender, player_go_id, hp_ratio)
            end

            if self.state ~= "in_game" then
                self.network_router:transmit_to(sender, "from_server_revive_request_denied", player_go_id)

                return
            end

            local player_info = PlayerManager:get_player_info(player_go_id)

            -- Engine parity: an in-flight revive is ignored, and an unknown player is ignored rather
            -- than dereferenced.
            if not player_info or player_info.reviving_in_progress then
                return
            end

            revive_player_safely(self, player_go_id, hp_ratio)
        end, MOD_NAME .. ".GameServer.rpc_revive_with_hp_ratio_request", MOD_NAME)

        -- Every host spawn position funnels through get_spawn_position (revive, drop-in, delayed
        -- entrance), and the engine hands back whatever friend_position / last_ground_position held.
        -- A non-finite value makes the client spawn the avatar into nothing and the engine spin, so
        -- report "no position" instead and let each caller take its own fallback (camera focus for a
        -- revive, the entrance marker for a drop-in).
        Mods.hook:set_object_path("GameServer", "get_spawn_position", function(orig2, self, player_go_id)
            if not Doppelgangers.is_host() then
                return orig2(self, player_go_id)
            end

            local position = orig2(self, player_go_id)

            if is_finite(position) then
                return position
            end

            return nil
        end, MOD_NAME .. ".GameServer.get_spawn_position", MOD_NAME)
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)
