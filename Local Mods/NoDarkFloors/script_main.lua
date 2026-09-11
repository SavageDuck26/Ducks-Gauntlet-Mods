
local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "1.6.0"
local MOD_DESCRIPTION = "Removes dark floors from the game. Like the light of Alfheim."

NoDarkFloors = {}
NoDarkFloors.loaded = true

local MOD_NAME, log_message = Mods.init_mod(nil, "mods/NoDarkFloors/NoDarkFloors.lua")
Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/managers/endless_client" then
        Mods.hook:set_object_path("EndlessClient", "apply_floor_rules", function(orig, self, layout_info)
            local rules = EndlessServer.get_floor_rules(self._floor_index)
            
            if layout_info and layout_info.environment ~= "d01_lava" then
                layout_info.is_dark = false
            end

        end, MOD_NAME .. ".EndlessClient.apply_floor_rules", MOD_NAME)
    end
    return result
end, MOD_NAME .. ".require", MOD_NAME)