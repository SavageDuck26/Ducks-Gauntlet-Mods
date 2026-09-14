
local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "1.3.1"
local MOD_DESCRIPTION = "Trials. Disables most inputs when not wearing the crown for the player with the mod."


local MOD_NAME, log_message = Mods.init_mod(nil, "mods/TheLaziestHero/TheLaziestHero.lua")
LazyHeroes = LazyHeroes or {}

-- Set to true by the "curse"/reverse variant so the hero is lazy when
-- WEARING the crown instead of when NOT wearing it.
LazyHeroes.is_cursed = false

-- Raw input fields a "lazy" player is still allowed to use (move / aim / interact).
LazyHeroes.allowed_inputs = {
    move      = true,
    move_raw  = true,
    aim_raw   = true,
    interact  = true,
    is_active = true,
    cursor    = true,
}

-- Returns true when the given avatar unit belongs to a player who is currently
-- "lazy" (i.e. not wearing the crown, or wearing it when cursed).
--
-- This reads the game's own per-player stats state (has_crown), and only ever
-- applies to the local player running this mod. Illusions and other players'
-- avatars are never "lazy", so their AI keeps attacking even after the hero
-- drops the crown.
LazyHeroes.is_lazy = function(avatar_unit)
    local player_info = PlayerManager:get_player_info_by_avatar(avatar_unit)

    if not player_info or not player_info.is_local_player then
        return false
    end

    local player_unit = player_info.player_unit
    local stats_state = player_unit and EntityAux.state_master(player_unit, "stats")
    local has_crown = stats_state and stats_state.has_crown

    if LazyHeroes.is_cursed then
        return not not has_crown
    else
        return not has_crown
    end
end

Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/ai_states/state_valkyrie" then
        Mods.hook:set_object_path("StateValkyrie", "block_should_enter", function(orig, component, unit, context, dt, ...)
            if LazyHeroes.is_lazy(unit) then return false end

            return orig(component, unit, context, dt, ...)
        end, MOD_NAME .. ".StateValkyrie.block_should_enter", MOD_NAME)
    end

    if path == "lua/ai_states/state_elf" then
        Mods.hook:set_object_path("StateElf", "read_attack_input", function(orig, component, unit, context, dt, ...)
            if LazyHeroes.is_lazy(unit) then
                local state = context.state
                local original_pressed = state.pressed.elf_special
                state.pressed.elf_special = false

                local result = orig(component, unit, context, dt, ...)

                state.pressed.elf_special = original_pressed
                return result
            end

            return orig(component, unit, context, dt, ...)
        end, MOD_NAME .. ".StateElf.read_attack_input", MOD_NAME)
    end

    if path == "lua/components/avatar_component" then
        -- Strip everything but move/aim/interact before the avatar's input
        -- handling runs, so blocked inputs never reach the held/pressed state
        -- or the state machine.
        Mods.hook:set_object_path("AvatarComponent", "update_masters", function(orig, self, entities, dt, ...)
            for unit, context in pairs(entities) do
                if LazyHeroes.is_lazy(unit) then
                    local input_data = context.state.input

                    if input_data and input_data.is_active then
                        for key in pairs(input_data) do
                            if not LazyHeroes.allowed_inputs[key] then
                                input_data[key] = nil
                            end
                        end
                    end
                end
            end

            return orig(self, entities, dt, ...)
        end, MOD_NAME .. ".AvatarComponent.update_masters", MOD_NAME)
    end

    if path == "lua/extensions/combo" then
        Mods.hook:set_object_path("Combo", "check_input", function(orig, self, unit, input_data, ...)
            if LazyHeroes.is_lazy(unit) and input_data then
                local filtered_input = {}

                for key, value in pairs(input_data) do
                    if key == "movement" or key == "interact" then
                        filtered_input[key] = value
                    end
                end

                return orig(self, unit, filtered_input, ...)
            end

            return orig(self, unit, input_data, ...)
        end, MOD_NAME .. ".Combo.check_input", MOD_NAME)
    end

    if path == "lua/ai_states/state_common_character" then
        Mods.hook:set_object_path("StateCommonCharacter", "check_extra_ability_input", function(orig, component, unit, context, dt, ...)
            if LazyHeroes.is_lazy(unit) then
                return
            end

            orig(component, unit, context, dt, ...)
        end, MOD_NAME .. ".StateCommonCharacter.check_extra_ability_input", MOD_NAME)
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)
