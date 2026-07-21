-- =================================================================================================
-- Author: SavageDuck26, Skapp
-- Purpose: Avatar loadout hooks for Doppelgangers mod
-- =================================================================================================

local MOD_NAME = "DoppelLoudout"

-- Global loadout toggle (set by main script)
loadout_toggle = loadout_toggle ~= false -- default to true unless set false

-- Hook the require function to modify classes after they're loaded
Mods.hook:set(MOD_NAME .. "_loadout", "require", function(orig, path, ...)
    local result = orig(path, ...)
    -- Only run loadout code if loadout_toggle is true
    if loadout_toggle and path == "lua/menu/avatar_loadout" and AvatarLoadout then
        -- print("[" .. MOD_NAME .. "] avatar_loadout.lua loaded - ensuring duplicate character assignment works")
        -- Store the original assign_next_hero function
        local original_assign_next_hero = AvatarLoadout.assign_next_hero
        -- Override assign_next_hero to remove the duplicate check but keep the core logic
        AvatarLoadout.assign_next_hero = function(self, controller_name, direction)
            local position = self.team_preview.positions[self.index]
            local hero = position.hero
            local hero_index = AvatarSettings.avatar_lookup[hero.name]
            for i = 1, #AvatarSettings.avatars do
                local index = math.wrap_index(hero_index + direction * i, #AvatarSettings.avatars)
                local new_hero_name = AvatarSettings.avatars[index]
                -- print("[" .. MOD_NAME .. "] Trying to assign hero: " .. new_hero_name .. " at index: " .. index)
                -- Always allow assignment (remove is_assigned check, but keep logic for current hero)
                local new_hero = self.team_preview:assign_hero_to_pos(position, new_hero_name)
                if new_hero then
                    -- print("[" .. MOD_NAME .. "] Successfully assigned hero: " .. new_hero_name)
                    self.current_state:set_selection(index)
                    break
                else
                    -- print("[" .. MOD_NAME .. "] Failed to assign hero: " .. new_hero_name)
                end
            end
            self:update_current_gold_widget()
        end
    end
    return result
end)

