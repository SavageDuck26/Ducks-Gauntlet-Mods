
local MOD_AUTHOR = "SavageDuck26/Skapp"
local MOD_DESCRIPTION = "Host: accept a drop-in on a hero already in the party."


local MOD_NAME, log_message = Mods.init_mod()

Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    -- handle_from_client_player_drop_in_request is the one place the host rejects a duplicate:
    -- it sets accepted = not PartyLeadManager:is_avatar_type_in_use(avatar_type), and nothing
    -- else consults that check. Reporting "not in use" lets the drop-in through while the rest
    -- of the host's spawn handling (position, hp ratio, delayed entrance, party bookkeeping)
    -- runs untouched. The manager only exists on the host, so the hook is inert on clients.
    if path == "lua/managers/party_lead_manager" and PartyLeadManager then
        Mods.hook:set_object_path("PartyLeadManager", "is_avatar_type_in_use", function(orig, self, avatar_type)
            return false
        end, MOD_NAME .. ".PartyLeadManager.is_avatar_type_in_use", MOD_NAME)
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)
