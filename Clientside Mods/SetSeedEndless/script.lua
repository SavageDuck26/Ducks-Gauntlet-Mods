
local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "1.0.0"
local MOD_DESCRIPTION = "Set seed for endless, same layout per floor index"

local MOD_NAME, log_message = Mods.init_mod()
Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/dungeon/dungeon_generator" then
        Mods.hook:set_object_path("DungeonGenerator", "generate", function(orig, self, seed, layout_info)
            local floor_index = EndlessClient and EndlessClient._floor_index
            if floor_index then
                seed = floor_index
            else
                -- Nothing, used original random seed.
            end
            return orig(self, seed, layout_info)
        end, MOD_NAME .. ".DungeonGenerator.generate", MOD_NAME)
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)