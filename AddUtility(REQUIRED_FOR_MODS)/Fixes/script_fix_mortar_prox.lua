
local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Fix stone Mortars. Make all players trigger them, not only host."

local MOD_NAME, log_message = Mods.init_mod()

-- The mortar mine deals no damage with its trigger event; all it does is run the
-- "mine_explosion" ability from an on_valid_hit callback. Two rules decide who may
-- fire it:
--  - AbilityEventHandler.handle_event_callback runs that callback only on the peer
--     that owns the mine, which is always the host, because the host spawns it,
--  - PredictionAux.is_event_authorative hands a hit to the peer that owns the
--     victim, so the host threw away every hit on an avatar it did not own.
-- The mine therefore only detonated for the host. Making a mine's hits
-- performer-authorative gives the mine's owner the hits on every player caught in
-- the blast; the damage is still networked to the victim's own peer, and the other
-- peers keep running the explosion as a predictor so the effect stays visible.
local MORTAR_MINE_SETTINGS_PATH = "ability_units/spawners/spawner_mortar_mine"

Mods.hook:set_object_path("PredictionAux", "is_event_authorative", function(orig, performer_unit, recipient_unit, peer)
    if performer_unit and Unit.get_data(performer_unit, "settings_path") == MORTAR_MINE_SETTINGS_PATH then
        return EntityAux.owned(performer_unit)
    end

    return orig(performer_unit, recipient_unit, peer)
end, MOD_NAME .. ".PredictionAux.is_event_authorative", MOD_NAME)


-- NEEDS TESTER, UNCONFIRMED
