-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.0
-- Purpose: Set seed for endless, same layout per floor index.
-- =================================================================================================

local MOD_NAME = "SetSeedEndless"

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/dungeon/dungeon_generator" then
        Mods.hook:set(MOD_NAME, "DungeonGenerator.generate", function (orig, self, seed, layout_info)
            local floor_index = EndlessClient and EndlessClient._floor_index
            if floor_index then
                seed = floor_index
            else
                -- Nothing, used original random seed.
            end
            return orig(self, seed, layout_info)
        end)
    end

    return result
end)