
local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Floor end: credit banked gold, mastery and cape unlocks to the right player."


local MOD_NAME, log_message = Mods.init_mod()

-- screen_floor_end builds one ResultSheet per player and then asks ScoreSynchronizer for that
-- player's banked gold, mastery events and colosseum reward. The getters are handed only the hero
-- name (avatar_type) and resolve the player with PlayerManager:get_player_info_by_avatar_type, which
-- cannot tell two players on one hero apart - so every sheet reads whichever duplicate it reaches
-- first, and the cape/gold bonus is decided from the wrong player's colosseum record. The sheet is
-- built for a player immediately before those reads (screen_floor_end.on_enter), so remember that
-- player and let the lookup return it. The score tables themselves are already keyed by go_id.
local sheet_player_info = nil

Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "foundation/lua/player/player_manager" and PlayerManager then
        Mods.hook:set_object_path("PlayerManager", "get_player_info_by_avatar_type", function(orig2, self, avatar_type, ...)
            local player_info = sheet_player_info

            if player_info and player_info.avatar_type == avatar_type then
                return player_info
            end

            return orig2(self, avatar_type, ...)
        end, MOD_NAME .. ".PlayerManager.get_player_info_by_avatar_type", MOD_NAME)
    end

    if path == "lua/menu/result_sheet" and ResultSheet then
        Mods.hook:set_object_path("ResultSheet", "init", function(orig2, self, screen_end, index, score_info, player_info)
            sheet_player_info = player_info

            return orig2(self, screen_end, index, score_info, player_info)
        end, MOD_NAME .. ".ResultSheet.init", MOD_NAME)
    end

    -- Bound the override to the sheet-building pass so it can never reach a later lookup.
    if path == "lua/menu/screen_floor_end" and ScreenFloorEnd then
        Mods.hook:set_object_path("ScreenFloorEnd", "on_enter", function(orig2, self, ...)
            sheet_player_info = nil

            local first, second = orig2(self, ...)

            sheet_player_info = nil

            return first, second
        end, MOD_NAME .. ".ScreenFloorEnd.on_enter", MOD_NAME)
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)
