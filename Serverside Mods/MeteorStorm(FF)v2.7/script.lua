-- =================================================================================================
-- Author: SavageDuck26
-- Version: 2.7
-- Purpose: Adds lava levels meteors
-- =================================================================================================

local MOD_NAME = "MeteorStorm"

MeteorStorm = MeteorStorm or {}

MeteorStorm.loaded = true

-- Saveable settings
MeteorStorm.CONFIG = MeteorStorm.CONFIG or {
    difficulty = "Medium",
    friendly_fire = true,
    enabled = true,
}

local DIFFICULTY_CONFIGS = {
	Easy = { -- Easy (Half intensity)
		cooldown_min = 2,
		time_until_max = 60,
		cooldown_range_min = { [1] = 4, [4] = 4 },
		cooldown_range_max = { [1] = 8, [4] = 8 },
		RAD_SETTING = 2.5,
	},
	Medium = { -- Medium (Normal intensity)
		cooldown_min = 1,
		time_until_max = 30,
		cooldown_range_min = { [1] = 2, [4] = 2 },
		cooldown_range_max = { [1] = 4, [4] = 4 },
		RAD_SETTING = 2.75,
		
	},
	Hard = { -- Hard (Double intensity)
		cooldown_min = 0.5,
		time_until_max = 15,
		cooldown_range_min = { [1] = 1, [4] = 1 },
		cooldown_range_max = { [1] = 2, [4] = 2 },
		RAD_SETTING = 3,
	},
	Impossible = { -- Impossible (Quadruple intensity)
		cooldown_min = 0.25,
		time_until_max = 7.5,
		cooldown_range_min = { [1] = 0.4, [4] = 0.4 },
		cooldown_range_max = { [1] = 0.8, [4] = 0.8 },
		RAD_SETTING = 3.25,
	},
	Hell = { -- Hell (Octuple intensity)
		cooldown_min = 0.1,
		time_until_max = 3.5,
		cooldown_range_min = { [1] = 0.2, [4] = 0.2 },
		cooldown_range_max = { [1] = 0.4, [4] = 0.4 },
		RAD_SETTING = 3.5,
	},
}

MeteorStorm.difficulty_configs = DIFFICULTY_CONFIGS

local function get_current_config()
	local difficulty = MeteorStorm.CONFIG.difficulty or "Medium"
	return DIFFICULTY_CONFIGS[difficulty] or DIFFICULTY_CONFIGS.Medium
end

local function get_friendly_fire_setting()
	local ff = MeteorStorm.CONFIG.friendly_fire
	if ff == nil then
		return true
	end
	return ff
end

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)
	
	-- Check if mod is enabled
	local is_enabled = MeteorStorm.CONFIG.enabled
	if not is_enabled then
		return result
	end
	
	if path == "lua/settings/ai_settings" and AIFloorSettings and result then
		local config = get_current_config()
		
		local lava_endless_firebomb_settings = {
			spawn_interval_min = {
				[1] = 10,
				[4] = 10,
			},
			spawn_interval_max = {
				[1] = 15,
				[4] = 15,
			},
			count_min = {
				[1] = 4,
				[4] = 8,
			},
			count_max = {
				[1] = 15,
				[4] = 30,
			},
			monsters = {},
			spawn_firebombs = {
				cooldown_min = config.cooldown_min,
				time_until_max = config.time_until_max,
				cooldown_range_min = config.cooldown_range_min,
				cooldown_range_max = config.cooldown_range_max,
			},
		}
		AIFloorSettings.lava_endless_01_temple = lava_endless_firebomb_settings
		AIFloorSettings.lava_endless_02_demon = lava_endless_firebomb_settings
		AIFloorSettings.lava_endless_03_temple_mixed = lava_endless_firebomb_settings
		AIFloorSettings.lava_endless_04_demon_mixed = lava_endless_firebomb_settings
	end

	if path == "gameobjects/procedural_floors/firebomb" and result then
		local config = get_current_config()
		local friendly_fire = get_friendly_fire_setting()
		
		local event = result.abilities.firebomb_explode.events and result.abilities.firebomb_explode.events[1]
		if event then
			event.friendly_fire = friendly_fire
			event.radius = config.RAD_SETTING
		end
	end
	return result
end)

local TEXT_CONFIG = {
	Easy = "I'm too young to die!",
	Medium = "Big fan of classics huh?",
	Hard = "A little spice can be nice.",
	Impossible = "Someone's got a death wish.",
	Hell = "I'm a big fan of whatever's wrong with you."
}

MeteorStorm.text_config = TEXT_CONFIG