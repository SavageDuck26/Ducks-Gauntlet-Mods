
local MOD_AUTHOR = "SavageDuck26/Skapp"
local MOD_DESCRIPTION = "Lobby: every slot may pick the same hero."


local MOD_NAME, log_message = Mods.init_mod()

Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    -- The lobby treats a hero as unavailable once another slot holds it: screen_lobby force-
    -- reselects anyone carrying a hero that is locked elsewhere. get_locked_hero_named is the
    -- query behind that gate, so answering nil lifts it. Auto-assign still hands a joining
    -- player a free hero through is_assigned, and lobby_logic's slot-swap simply stops
    -- auto-clearing the second copy - which is exactly what this mod wants.
    if path == "lua/menu/team_preview" and TeamPreview then
        Mods.hook:set_object_path("TeamPreview", "get_locked_hero_named", function(orig, self, name)
            return nil
        end, MOD_NAME .. ".TeamPreview.get_locked_hero_named", MOD_NAME)
    end

    -- Cycling a lobby hero with the loadout arrows asks is_assigned first and skips every
    -- hero already on the board, so a duplicate can never be reached that way. Re-walk the
    -- same circle without the check.
    if path == "lua/menu/avatar_loadout" and AvatarLoadout then
        Mods.hook:set_object_path("AvatarLoadout", "assign_next_hero", function(orig, self, controller_name, direction)
            local position = self.team_preview.positions[self.index]
            local hero_index = AvatarSettings.avatar_lookup[position.hero.name]

            for i = 1, #AvatarSettings.avatars do
                local index = math.wrap_index(hero_index + direction * i, #AvatarSettings.avatars)
                local new_hero = self.team_preview:assign_hero_to_pos(position, AvatarSettings.avatars[index])

                if new_hero then
                    self.current_state:set_selection(index)

                    break
                end
            end

            self:update_current_gold_widget()
        end, MOD_NAME .. ".AvatarLoadout.assign_next_hero", MOD_NAME)
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)
