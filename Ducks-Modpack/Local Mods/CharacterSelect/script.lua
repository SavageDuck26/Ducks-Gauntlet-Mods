
local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "1.2.0"
local MOD_DESCRIPTION = "Allows you to switch characters in game. (F3 or R2)"

-- Open the menu IN GAME and press "F3" or "R2".

CharacterSelect = CharacterSelect or {}
CharacterSelect.loaded = true

local MOD_NAME, log_message = Mods.init_mod(nil, "mods/CharacterSelect/CharacterSelect.lua")


local RIGHT_TRIGGER = _G.IS_PS4 and "r2" or "right_trigger"
local function right_trigger_pressed()
    local pad = rawget(_G, "Pad1")

    if pad == nil or not pad.active() then
        return false
    end

    local index = pad.button_index(RIGHT_TRIGGER)

    return index ~= nil and pad.pressed(index)
end

Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/menu/screen_ingame_main" then
        Mods.hook:set_object_path("ScreenIngameMain", "update", function(orig, self, dt)
                if right_trigger_pressed() or (_G.IS_PC and Keyboard.pressed(Keyboard.button_index("f3"))) then
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