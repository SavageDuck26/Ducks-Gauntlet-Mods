-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Loads all resources to avoid any crashes from missing assets.
-- =================================================================================================

local MOD_NAME = "ResourcePacks"

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    -- Check if path is under layouts but exclude specific files
    if string.match(path, "^lua/dungeon/layouts/") 
        and not string.match(path, "audio_floor")
        and not string.match(path, "limbo")
        and not string.match(path, "lookup")
        and not string.match(path, "room_behavior")
        and not string.match(path, "tutorial")
        and result then
        
        local floor_data = result
        floor_data.packages = {
            "resource_packages/morak",
            "resource_packages/elias/lava_boss",
            "resource_packages/crypt_boss",
            "resource_packages/elias/crypt_boss",
            "resource_packages/cave_boss",
            "resource_packages/elias/cave_boss",
            "resource_packages/base",
            "resource_packages/surface_effects",
            "resource_packages/particle_effects",
            "resource_packages/gore_effects",
            "resource_packages/elias",
            "resource_packages/all_effects",
            "resource_packages/misc_units",
            "resource_packages/food_units",
            "resource_packages/relic_units",
            "resource_packages/scripts_settings",
            "modules/d01_crypt/resources",
            "resource_packages/d01_crypt",
            "resource_packages/elias/crypt_adventure",
            "resource_packages/elias/crypt_labyrinth",
            "modules/d01_caves/resources",
            "resource_packages/d01_caves",
            "resource_packages/elias/cave_adventure",
            "resource_packages/elias/cave_labyrinth",
            "modules/d01_lava/resources",
            "resource_packages/d01_lava",
            "resource_packages/elias/lava_adventure",
            "resource_packages/elias/lava_labyrinth",
            "modules/d01_hub_room/resources",
            "resource_packages/d01_hub_room",
            "resource_packages/elias/hubroom",
        }
        return floor_data
    end

    return result
end)