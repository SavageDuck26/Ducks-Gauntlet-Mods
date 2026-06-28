-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.4
-- Purpose: No Skullcoins
-- =================================================================================================

local MOD_NAME = "DeadMansHand"

_G.deadmanshand_active = true

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/states/game_server" and GameServer then
        if not GameServer._deadmanshand_original_revive_with_hp_ratio then
            GameServer._deadmanshand_original_revive_with_hp_ratio = GameServer.rpc_revive_with_hp_ratio_request
        end
        if not GameServer._deadmanshand_original_revive_request then
            GameServer._deadmanshand_original_revive_request = GameServer.rpc_revive_request
        end
        if not GameServer._deadmanshand_original_revive_for_free then
            GameServer._deadmanshand_original_revive_for_free = GameServer.rpc_revive_for_free_request
        end

        GameServer.rpc_revive_request = function(self, sender, player_go_id)
            self.network_router:transmit_to(sender, "from_server_revive_request_denied", player_go_id)
        end
        GameServer.rpc_revive_for_free_request = function(self, sender, player_go_id)
            self.network_router:transmit_to(sender, "from_server_revive_request_denied", player_go_id)
        end
        GameServer.rpc_revive_with_hp_ratio_request = function(self, sender, player_go_id, hp_ratio)
            if hp_ratio == 0.1 then
                return GameServer._deadmanshand_original_revive_with_hp_ratio(self, sender, player_go_id, hp_ratio)
            else
                self.network_router:transmit_to(sender, "from_server_revive_request_denied", player_go_id)
            end
        end

        AddUtility.register_update(MOD_NAME .. "_skull_coins", function(dt)
            if _G.is_host_ducks_mods and rawget(_G, "PartyLeadManager") then
                local plm = PartyLeadManager
                if plm.party_data and plm.party_data.skull_coins_protected and plm.network_session and plm.party_id then
                    plm.party_data.skull_coins_protected:set(0)
                    GameSession.set_game_object_field(plm.network_session, plm.party_id, "skull_coins", 0)
                end
            end
        end)
    end

    if path == "lua/states/game_client" and GameClient then
        GameClient.from_server_revive_request_denied = function(self, sender, player_go_id)
            local player_info = PlayerManager:get_player_info(player_go_id)
            if player_info then
                player_info.revive_request_sent = false
            end
        end
    end

    if path == "lua/ui/game_hud" and GameHud then
        if GameHud.draw_ui_game then
            local orig_draw_ui_game = GameHud.draw_ui_game
            GameHud.draw_ui_game = function(self, dt)
                orig_draw_ui_game(self, dt)
                if self.widget_lookup and self.widget_lookup.skull_coins then
                    self.widget_lookup.skull_coins:set_text("0")
                end
                if self.widget_lookup and self.widget_lookup.skull_coins_shadow then
                    self.widget_lookup.skull_coins_shadow:set_text("0")
                end
            end
        else
            print("[" .. MOD_NAME .. "] GameHud.draw_ui_game not found, skipping HUD patch.")
        end
    end

    return result
end)