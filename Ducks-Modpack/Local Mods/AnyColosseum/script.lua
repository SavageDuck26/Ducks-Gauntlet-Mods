-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.1.1
-- Purpose: Lets you choose any colosseum level you want by cycling through them.
-- =================================================================================================

local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "1.1.1"
local MOD_DESCRIPTION = "Lets you choose any colosseum level you want by cycling through them."


local COLOSSEUM_CHANGE_KEYBIND = "f1"  -- Change this to your desired keybind for increasing day

-- Here is a list of all of the available keybinds that are recommended:
-- f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12
-- a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z

-- ON CONTROLLER: Press R1 to cycle.

local MOD_NAME, log_message = Mods.init_mod(nil, "mods/AnyColosseum/AnyColosseum.lua")
local COLOSSEUM_COUNTER = 0

print("[" .. MOD_NAME .. "] Someone's cherry picking...")

Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/menu/screen_main_menu" then
        
        Mods.hook:set_object_path("ScreenMainMenu", "update", function(orig, self, dt, ...)
            if not self.popup and self.widget then
                local cycle_pressed = (_G.IS_PS4 and Pad1.active() and Pad1.pressed(Pad1.button_index("r1")))
                    or (_G.IS_PC and Keyboard.pressed(Keyboard.button_index(COLOSSEUM_CHANGE_KEYBIND)))

                if cycle_pressed then
                    COLOSSEUM_COUNTER = COLOSSEUM_COUNTER + 1
                    ColosseumSettings:set_days_since_colosseum_start(COLOSSEUM_COUNTER - 1)
                    self:rebuild_ui()
                    self:show_mode_buttons("online")
                end
            end

            return orig(self, dt, ...)
        end, MOD_NAME .. ".ScreenMainMenu.update", MOD_NAME)
    end
    return result
end, MOD_NAME .. ".require", MOD_NAME)
