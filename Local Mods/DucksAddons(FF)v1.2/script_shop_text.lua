-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Adds custom text to shop items.
-- =================================================================================================

local MOD_NAME = "ShopText"

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "gameobjects/shop/article_ham" then
        result.interact_text = "Go Ham with your savings."
    end
    if path == "gameobjects/shop/article_turkey" then
        result.interact_text = "Thanksgiving is cancelled, thanks."
    end
    if path == "gameobjects/shop/article_potion" then
        result.interact_text = "Don't drink and drive."
    end
    if path == "gameobjects/shop/article_skullcoin" then
        result.interact_text = "You really need one of these?"
    end

    return result
end)