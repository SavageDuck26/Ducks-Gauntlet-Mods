
local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "1.0.0"
local MOD_DESCRIPTION = "Makes player die in one hit"

local MOD_NAME = "FragileHeroes"

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    -- =======================================================================================================
    if path == "lua/components/avatar_damage_receiver_component" then
        
        Mods.hook:set(MOD_NAME, "AvatarDamageReceiverComponent.calculate_damage", function (orig, self, unit, state, context, damage, hit_settings)
            damage = 9999999

            return damage
        end)
    end
    -- =======================================================================================================
    
    return result
end)