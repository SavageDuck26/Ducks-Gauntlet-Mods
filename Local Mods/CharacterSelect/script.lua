-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.1
-- Purpose: Allows you to switch characters in game.
-- =================================================================================================

local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "1.1.0"
local MOD_DESCRIPTION = "Allows you to switch characters in game."


-- Open the menu IN GAME and press "F3" or "R2".

CharacterSelect = CharacterSelect or {}
CharacterSelect.loaded = true

local MOD_NAME, log_message = Mods.init_mod()
-- print("[" .. MOD_NAME .. "] Someone's indecisive...")

Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/menu/screen_ingame_main" then
        Mods.hook:set_object_path("ScreenIngameMain", "update", function(orig, self, dt)
                if (_G.IS_PS4 and Pad1.active() and Pad1.pressed(Pad1.button_index("r2")) or _G.IS_PC and Keyboard.pressed(Keyboard.button_index("f3"))) then
                    if self.app_state:isa(StateGame) then
                        self:exit()

                        local game_client = self.app_state.game_client

                        game_client:drop_user(self.user_name)
                        game_client.entity_spawner:delete_marked_entities()
                        game_client:try_join(self.user_name)
                    end
                end
            end, MOD_NAME .. ".ScreenIngameMain.update", MOD_NAME)

    end
    return result
end, MOD_NAME .. ".require", MOD_NAME)