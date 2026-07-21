-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.1
-- Purpose: Lets you choose any colosseum level you want by cycling through them.
-- =================================================================================================

local COLOSSEUM_CHANGE_KEYBIND = "f1"  -- Change this to your desired keybind for increasing day

-- Here is a list of all of the available keybinds that are recommended:
-- f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12
-- a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z

-- ON CONTROLLER: Press R1 to cycle.

local MOD_NAME = "AnyColosseum"
local COLOSSEUM_COUNTER = 0

print("[" .. MOD_NAME .. "] Someone's cherry picking...")

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/menu/screen_main_menu" then
        
        Mods.hook:set(MOD_NAME, "ScreenMainMenu.update", function(orig, self, dt, ...)
            if Platform:get_connection_status() == Platform.CONNECTION_LOST or Platform:resumed_from_suspension() then
                    self.menu_manager:clear_selection_history(self._screen_name)
                    self:show_mode_buttons()
                    update_online_required_options(self)
                end

                if Platform:get_connection_status() == Platform.CONNECTION_LOST or Platform:get_connection_status() == Platform.CONNECTION_REGAINED or Platform:resumed_from_suspension() then
                    self.motd_set = false

                    update_wbid_ui(self)
                    update_online_required_options(self)
                end

                if not self.motd_set then
                    local title, message, link = Game:get_message_of_the_day()

                    if title or message or link then
                        update_wbid_ui(self)
                    end
                end

                if (_G.IS_PS4 and Pad1.active() and Pad1.pressed(Pad1.button_index("r1")) or _G.IS_PC and Keyboard.pressed(Keyboard.button_index(COLOSSEUM_CHANGE_KEYBIND))) then
                    COLOSSEUM_COUNTER = COLOSSEUM_COUNTER + 1
                    ColosseumSettings:set_days_since_colosseum_start(COLOSSEUM_COUNTER - 1)
                    self:rebuild_ui()
                    self:show_mode_buttons("online")
                    
                end

                if self.popup then
                    self.popup:update(dt)

                    if self.widget == nil then
                        return
                    end
                end      
            return orig(self, dt, ...)
        end)
    end
    return result
end)
