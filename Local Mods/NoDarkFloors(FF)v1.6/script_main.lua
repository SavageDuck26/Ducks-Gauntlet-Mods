-- =================================================================================================
-- Author: SavageDuck26, (Used Skapp's code as a reference.)
-- Version: 1.6
-- Purpose: Removes dark floors from the game. Like the light of Alfheim.
-- =================================================================================================

NoDarkFloors = {}
NoDarkFloors.loaded = true

local MOD_NAME = "NoDarkFloors"

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/managers/endless_client" then
        Mods.hook:set(MOD_NAME, "EndlessClient.apply_floor_rules", function(orig, self, layout_info)
            local rules = EndlessServer.get_floor_rules(self._floor_index)
            
            if layout_info and layout_info.environment ~= "d01_lava" then
                layout_info.is_dark = false
            end

        end)
    end
    return result
end)