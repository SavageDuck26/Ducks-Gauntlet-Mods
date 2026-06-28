-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Fixes issues with Cultist Armor behavior
-- =================================================================================================

local MOD_NAME = "FixCultistArmor"

print("[" .. MOD_NAME .. "] Loaded")

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/cultist_armor/cultist_armor" and result then
        if result.abilities and result.abilities.stab and result.abilities.stab.events then
            for _, event in ipairs(result.abilities.stab.events) do
                if event.half_extents then
                    event.half_extents.y = 1.5  -- Reduced from 2.5 to prevent piercing shields
                end
            end
        end
    end

    if path == "characters/cultist_armor/cultist_armor_corpse" and result then
        result.interact_text = "Destroy Reforming Armor"
    end

    return result
end)