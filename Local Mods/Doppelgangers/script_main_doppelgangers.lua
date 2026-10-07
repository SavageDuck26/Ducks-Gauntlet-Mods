
local MOD_AUTHOR = "SavageDuck26/Skapp"
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

-- print("[" .. MOD_NAME .. "] Making a few doubles, doubles, doubles, doubles...")
