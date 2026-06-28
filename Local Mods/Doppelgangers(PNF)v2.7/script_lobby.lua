-- =================================================================================================
-- Author: SavageDuck26, Skapp
-- Purpose: Team preview/lobby hooks for Doppelgangers mod
-- =================================================================================================

local MOD_NAME = "DoppelLobby"

lobby_toggle = lobby_toggle ~= false 

Mods.hook:set(MOD_NAME .. "_lobby", "require", function(orig, path, ...)
    local result = orig(path, ...)

    if lobby_toggle and path == "lua/menu/team_preview" and TeamPreview then

        TeamPreview.is_assigned = function(self, hero_name, locked)
            return false -- Always allow hero selection regardless of who has it
        end

        TeamPreview.get_locked_hero_named = function(self, name)
            return nil -- Allow any hero to be locked, even if another player has it
        end

    end
    return result
end)

