
local MOD_AUTHOR = "SavageDuck26/Skapp"
local MOD_DESCRIPTION = "In-game: route a duplicated hero to the right player."


local MOD_NAME, log_message = Mods.init_mod()

Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    -- The hotjoin / colosseum character select only lists heroes the party is not already using
    -- (game_client:on_party_changed strips them before calling this), so a duplicate can never
    -- be picked there. Always hand it the full hero list.
    if path == "lua/states/game_client" and GameClient then
        Mods.hook:set_object_path("GameClient", "set_available_heroes", function(orig, self, available_heroes, ...)
            return orig(self, AvatarSettings.avatars, ...)
        end, MOD_NAME .. ".GameClient.set_available_heroes", MOD_NAME)
    end

    -- get_player_info_by_avatar_type returns whichever player the iteration reaches first. That
    -- is fine while every hero is unique, but can point at a remote player once two players
    -- share a hero. Its only callers (screen_floor_end's banked-gold / mastery / colosseum
    -- sheets) want the local player's own record, so prefer the local player and fall back to
    -- the engine's first match.
    if path == "foundation/lua/player/player_manager" and PlayerManager then
        Mods.hook:set_object_path("PlayerManager", "get_player_info_by_avatar_type", function(orig, self, avatar_type, ...)
            local my_peer_id = Network and Network.peer_id and Network.peer_id()
            local first_match

            for _, info in self:players_iterator() do
                if info.avatar_type == avatar_type then
                    if info.peer_id == my_peer_id then
                        return info
                    end

                    first_match = first_match or info
                end
            end

            return first_match or orig(self, avatar_type, ...)
        end, MOD_NAME .. ".PlayerManager.get_player_info_by_avatar_type", MOD_NAME)
    end

    -- The kill-streak banner subscribes to on_stat_event and matches by avatar_type, which both
    -- duplicates share, so every duplicate HUD shows every event. Each HUD is built with its
    -- owning player_go_id (lua/ui/player_hud), so capture it and match on that instead.
    if path == "lua/ui/stat_event_hud" and StatEventHud then
        Mods.hook:set_object_path("StatEventHud", "init", function(orig, self, world_proxy, event_delegate, player_go_id, avatar_type, ...)
            self.player_go_id = player_go_id

            return orig(self, world_proxy, event_delegate, player_go_id, avatar_type, ...)
        end, MOD_NAME .. ".StatEventHud.init", MOD_NAME)

        Mods.hook:set_object_path("StatEventHud", "on_stat_event", function(orig, self, event_type, player_unit, data, priority)
            if self.player_go_id == nil then
                return orig(self, event_type, player_unit, data, priority)
            end

            local player_info = PlayerManager:get_player_info(player_unit)

            if player_info and player_info.go_id == self.player_go_id then
                self:add_stat_event(event_type, player_info.avatar_type, data, priority)
            end
        end, MOD_NAME .. ".StatEventHud.on_stat_event", MOD_NAME)
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)
