-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.1
-- Purpose: Allows you to switch characters in game.
-- =================================================================================================

-- Open the menu IN GAME and press "F3" or "R2".

CharacterSelect = CharacterSelect or {}
CharacterSelect.loaded = true

local MOD_NAME = "CharacterSelect"

-- print("[" .. MOD_NAME .. "] Someone's indecisive...")

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/menu/screen_ingame_main" then
        Mods.hook:set(MOD_NAME, "ScreenIngameMain.update", 
            function (orig, self, dt)
                if (_G.IS_PS4 and Pad1.active() and Pad1.pressed(Pad1.button_index("r2")) or _G.IS_PC and Keyboard.pressed(Keyboard.button_index("f3"))) then
                    if self.app_state:isa(StateGame) then
                        self:exit()

                        local game_client = self.app_state.game_client

                        game_client:drop_user(self.user_name)
                        game_client.entity_spawner:delete_marked_entities()
                        game_client:try_join(self.user_name)
                    end
                end
            end)

    end
    return result
end)