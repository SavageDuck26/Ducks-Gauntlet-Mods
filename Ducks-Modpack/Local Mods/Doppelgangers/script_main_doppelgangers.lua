
local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "3.0.0"
local MOD_DESCRIPTION = "Lets every player pick the same hero (doppelgangers) in co-op."


local MOD_NAME, log_message = Mods.init_mod()

-- The engine keys almost everything by player_go_id (avatar units, player_infos, the party
-- roster, revive and drop-in RPCs), so two players on the same hero already work once the
-- handful of places that treat a hero as unique are relaxed. Those places, and only those, are:
--   lua/menu/avatar_loadout        - lobby hero cycling skips heroes already on the board
--   lua/menu/team_preview          - get_locked_hero_named blocks a hero locked on another slot
--   lua/states/game_client         - set_available_heroes hides heroes the party already uses
--   player_manager / stat_event_hud - avatar_type lookups become ambiguous with duplicates
--   party_lead_manager             - the host refuses a drop-in on a hero already in use
-- Each is handled by one sibling script; this file only sets up the shared namespace.
Doppelgangers = Doppelgangers or {}
Doppelgangers.loaded = true

-- Which board may run the host-authority fixes (the drop-in gate in script_server and the revive /
-- spawn positions in script_revive). Both host signals are honoured:
--   * the engine's own authority - StateGame builds GameServer only when its is_server flag is set,
--     so either one is exactly "this board answers server RPCs" (the .clinerules convention);
--   * AddUtility's _G.is_host_ducks_mods, which is fed from lobby:lobby_host().
-- AddUtility's flag must never be the only gate: it is refreshed only while a network lobby exists
-- and leave_lobby() nils both lobby fields, so after the lobby closes it freezes and can read false
-- on the real host - dropping the authority path exactly when the duplicate revive needs it.
-- Erring towards "host" is safe here: every hook this gates lives on GameServer, which a client
-- never instantiates, so a stale true on a client cannot run anything.
Doppelgangers.is_host = function()
    local state_game = _G.FlowCallbacks and FlowCallbacks.state_game

    if state_game and (state_game.is_server == true or state_game.game_server ~= nil) then
        return true
    end

    return _G.is_host_ducks_mods == true
end

-- print("[" .. MOD_NAME .. "] Making a few doubles, doubles, doubles, doubles...")
