-- =================================================================================================
-- Author: SavageDuck26, Skapp
-- Version: 2.5
-- Purpose: Main entry point for Doppelgangers mod with toggleable features
-- =================================================================================================


local MOD_NAME = "Doppelgangers"

_G.deadmanshand_active = _G.deadmanshand_active or false -- Ensure this is defined for compatibility with DeadMansHand mod

print("[" .. MOD_NAME .. "] Making a few doubles, doubles, doubles, doubles...")

local toggles = {
    lobby_toggle = true,            -- Team preview/lobby duplicate selection
    loadout_toggle = true,          -- Avatar loadout duplicate assignment
    hotjoin_toggle = true,          -- Hotjoin/game client duplicate support
    player_manager_toggle = true,   -- Player manager duplicate support
    network_toggle = true,          -- Network RPC handlers
    server_toggle = true,           -- Game server duplicate support
    revive_toggle = true,           -- revive_toggle functionality
    voice_fix_toggle = true,        -- Voice line fix for doppelgangers
}

-- Export toggles globally so other scripts can access them
_G.doppelgangers_toggles = toggles

local is_host_doppelgangers = false

-- Function to check if we're the host
local function check_is_host()
    if Network and Network.peer_id then
        return Network.peer_id() == 1
    end
    return false
end

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "gui/screen_main_menu_ui" and result then
        is_host_doppelgangers = false
        -- Reset toggles for non-host (will be enabled if we become host)
        toggles.revive_toggle = false
        toggles.lobby_toggle = false
        toggles.loadout_toggle = false
        toggles.player_manager_toggle = false
        toggles.server_toggle = false
        -- Voice fix should always be enabled
        toggles.voice_fix_toggle = true
        -- print("[" .. MOD_NAME .. "] NOT HOST - waiting for host detection")
    end

    if path == "gui/popup_hosting_lobby_ui" and result then
        is_host_doppelgangers = true
        toggles.revive_toggle = true
        toggles.lobby_toggle = true
        toggles.loadout_toggle = true
        toggles.player_manager_toggle = true
        toggles.server_toggle = true
        toggles.voice_fix_toggle = true
        print("[" .. MOD_NAME .. "] HOST MODE - All features enabled")
    end
    
    -- Also enable for clients joining a lobby (they need lobby features too)
    if path == "gui/popup_joining_lobby_ui" and result then
        is_host_doppelgangers = false
        toggles.lobby_toggle = true
        toggles.loadout_toggle = true
        toggles.player_manager_toggle = true
        toggles.voice_fix_toggle = true
        -- Server and revive handled by host only
        toggles.server_toggle = false
        toggles.revive_toggle = false
        print("[" .. MOD_NAME .. "] CLIENT MODE - Lobby features enabled")
    end

    return result
end)