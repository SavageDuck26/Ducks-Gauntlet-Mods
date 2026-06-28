-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.0
-- Purpose: Adds the sprites to the load screen.
-- =================================================================================================

local MOD_NAME = "LoadScreenSprites"

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "gui/load_screen_ui" and result then 
        if result.children[1].children[10] then
            result.children[1].children[10].visible = true
        end
    end
    return result
end)