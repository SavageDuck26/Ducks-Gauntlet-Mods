-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.2
-- Purpose: Random floor every endless level.
-- =================================================================================================

EnduranceMode = EnduranceMode or {}
EnduranceMode.loaded = true
EnduranceMode.enabled = false
EnduranceMode.chosen_difficulty = nil -- set when player confirms difficulty for Endurance runs

local MOD_NAME = "EnduranceMode"

local ENDURANCE_DEATH_SPAWN_STEP = 6 -- Spawn Death every X floors
local ENDURANCE_SPAWN_FLOOR_OFFSET = 56 -- Makes levels act like the Endless floor equivalent
local ENDURANCE_SPAWN_SCALE = 1.0 -- Don't touch, multiplies this ^^^

local next_floors = {
    -- Crypt
    "crypt_endless_01_slaves",
    "crypt_endless_02_fancy",
    "crypt_endless_03_slaves_mixed",
    "crypt_endless_04_fancy_mixed",

    -- Caves
    "caves_endless_01_spider",
    "caves_endless_02_ruins",
    "caves_endless_03_spider_mixed",
    "caves_endless_04_ruins_mixed",

    -- Lava
    "lava_endless_01_temple",
    "lava_endless_02_demon",
    "lava_endless_03_temple_mixed",
    "lava_endless_04_demon_mixed",

    -- NO CAMPAIGN FLOORS WORK HERE
    -- NO "START" FLOORS ALLOWED HERE
}

local get_random_next_floor = function()
    local next_floor = next_floors[math.random(1, #next_floors)]

    return next_floor
end

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/managers/endless_server" then
        Mods.hook:set(MOD_NAME, "EndlessServer.get_floor", function(orig, floor_index)
            if not EnduranceMode.enabled then
                return orig(floor_index)
            end

            local level = orig(floor_index)
            if EnduranceMode.enabled then
                level.floor_id = get_random_next_floor()
            end
            
            return level
        end)

        Mods.hook:set(MOD_NAME, "EndlessServer.check_permanent_rules", function(orig, self, rules)
            if not EnduranceMode.enabled then
                return orig(self, rules)
            end

            local orig_result = orig(self, rules)

            local chosen_difficulty = EnduranceMode.chosen_difficulty or (DifficultyManager and DifficultyManager:difficulty_setting())
            if not chosen_difficulty then
                return orig_result
            end

            local diff_str = nil
            if type(chosen_difficulty) == "number" then
                diff_str = ALL_DIFFICULTY_CLASSES[chosen_difficulty]
            else
                diff_str = tostring(chosen_difficulty)
            end

            local diff_index = (DIFFICULTY_CLASSES_LOOKUP and DIFFICULTY_CLASSES_LOOKUP[diff_str]) or nil
            if not diff_str or not diff_index then
                return orig_result
            end

            if DifficultyManager and DifficultyManager.set_difficulty_setting then
                DifficultyManager:set_difficulty_setting(diff_str)
            end

            if NetworkHost and NetworkHost.set_difficulty then
                NetworkHost:set_difficulty(diff_str)
            end

            if self._network_router and self._network_router.transmit_to_all_others then
                self._network_router:transmit_to_all_others("from_server_set_difficulty", diff_index)
            end
            return orig_result
        end)

        Mods.hook:set(MOD_NAME, "EndlessServer.change_dungeon", function(orig, self, seed, floor_id)
            local a, b = orig(self, seed, floor_id)

            if EnduranceMode.enabled then
                local offset = ENDURANCE_SPAWN_FLOOR_OFFSET or 56
                local scale = ENDURANCE_SPAWN_SCALE or 1

                local floor_for_spawn = (self._floor_index or 1) + offset
                local adjusted_mult = 1 + (floor_for_spawn - 1) * 2 / 10
                adjusted_mult = adjusted_mult * scale

                if ProceduralSpawningManager and ProceduralSpawningManager.set_encounter_credits_multiplier then
                    ProceduralSpawningManager:set_encounter_credits_multiplier(adjusted_mult)
                else
                    -- Nothing
                end
            end

            return a, b
        end)

        Mods.hook:set(MOD_NAME, "EndlessServer.should_spawn_death", function(orig, self)
            if not EnduranceMode.enabled then
                return orig(self)
            end

            local floor = self._floor_index or 1
            if floor % ENDURANCE_DEATH_SPAWN_STEP == 0 then
                local rules = EndlessServer.get_floor_rules(self._floor_index)                
                return rules.death
            else
                return
            end
        end)
    end

	if path == "lua/menu/screen_main_menu" then
		Mods.hook:set(MOD_NAME, "ScreenMainMenu.rebuild_ui", function (orig, self)
			orig(self)

			local endurance_level_proto = {
				id = "start_endurance_online",
				style = "title_large",
				type = "button",
				text = "Endurance",
				color = "cadetblue",
				font_size = 72,
				on = {
					selected = function()
						self:show_tooltip("Endurance")
					end,
				},
			}

			local endurance_level_widget = GUI:load_proto(endurance_level_proto)
			self.widget:get("buttons_online"):add_child(endurance_level_widget)
		end)

		Mods.hook:set(MOD_NAME, "ScreenMainMenu.widget_clicked", function (orig, self, widget, user_name)
			local id = widget.id
			if id == "start_endurance_online" then
                PopupHostOptions.show(GUI.MAIN_CONTROLLER, function()
                    local chosen = DifficultyManager:difficulty_setting() or DIFFICULTY_DEFAULT

                    EnduranceMode.chosen_difficulty = chosen
                    EnduranceMode.enabled = true

                    self:start_game(GAME_TYPE_ENDLESS, true)
                end, true)
			else
                EnduranceMode.enabled = false
				orig(self, widget, user_name)
			end
		end)
	end

    return result
end)

-- When 0 coins and all people dies, game does not end.
-- Hell lava floors have their own meteors system (meteors mod does not affected there)
-- And a weird bug happened only once, Players spots when entering next floor maybe not correct.
