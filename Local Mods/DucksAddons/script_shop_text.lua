
local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Adds custom text to shop items."


local MOD_NAME, log_message = Mods.init_mod()
Mods.hook:set_object(_G, "require", function(orig, path, ...)
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
end, MOD_NAME .. ".require", MOD_NAME)