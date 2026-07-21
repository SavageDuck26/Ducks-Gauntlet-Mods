-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.2
-- Purpose: Trials. Disables most inputs when not wearing the crown for the player with the mod.
-- =================================================================================================

local MOD_NAME = "TheLaziestHero"

LazyHeroes = {}

LazyHeroes.is_lazy_fucker = nil
LazyHeroes.is_cursed = false

LazyHeroes.has_crown = false

LazyHeroes.set_lazy_status = function(wearing_crown)
    LazyHeroes.has_crown = wearing_crown
    
    if LazyHeroes.is_cursed then
        -- Cursed: lazy when WEARING crown
        LazyHeroes.is_lazy_fucker = wearing_crown
    else
        -- Normal: lazy when NOT wearing crown
        LazyHeroes.is_lazy_fucker = not wearing_crown
    end
end

local relic_inputs = {
	"relic_1",
	"relic_2",
	"relic_3",
}

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "gui/screen_main_menu_ui" and result then
        LazyHeroes.set_lazy_status(false)  -- Initialize: no crown yet
    end
    
    if path == "gameobjects/treasures/crown/crown" then

    end

    if path == "lua/components/treasure_component" then
        Mods.hook:set(MOD_NAME, "StatsComponent.command_master", function(orig, self, unit, context, command_name, data, ...)
            local result = orig(self, unit, context, command_name, data, ...)

            if command_name == "treasure_picked_up" then
                local treasure_unit = data
                local treasure_settings = LuaSettingsManager:get_settings_by_unit(treasure_unit).treasure
                local treasure_id = treasure_settings.id

                if treasure_id == "crown" then
                    LazyHeroes.set_lazy_status(true)  -- Crown picked up
                end
            elseif command_name == "treasure_dropped" then
                local treasure_unit = data
                local treasure_settings = LuaSettingsManager:get_settings_by_unit(treasure_unit).treasure
                local treasure_id = treasure_settings.id

                if treasure_id == "crown" then
                    LazyHeroes.set_lazy_status(false)  -- Crown dropped
                end
            end
        end)

        Mods.hook:set(MOD_NAME, "TreasureComponent.unlink_with_force", function(orig, self, treasure_unit, carrier, ...)
            orig(self, treasure_unit, carrier, ...)

            local settings = LuaSettingsManager:get_settings_by_unit(treasure_unit)
            if settings and settings.treasure and settings.treasure.id == "crown" then
                LazyHeroes.set_lazy_status(false)  -- Crown dropped
            end
            
        end)
    end

    if path == "lua/ai_states/state_valkyrie" then
        Mods.hook:set(MOD_NAME, "StateValkyrie.block_should_enter", function(orig, component, unit, context, dt, ...)
            if LazyHeroes.is_lazy_fucker then return false end

            return orig(component, unit, context, dt, ...)
        end)
    end

    if path == "lua/ai_states/state_elf" then
        Mods.hook:set(MOD_NAME, "StateElf.read_attack_input", function(orig, component, unit, context, dt, ...)
            if LazyHeroes.is_lazy_fucker then
                local state = context.state
                local original_pressed = state.pressed.elf_special
                state.pressed.elf_special = false
                
                local result = orig(component, unit, context, dt, ...)
                
                state.pressed.elf_special = original_pressed
                return result
            end
            
            return orig(component, unit, context, dt, ...)
        end)
    end

    if path == "lua/components/avatar_component" then
        Mods.hook:set(MOD_NAME, "AvatarComponent.on_avatar_exiting_floor", function(orig, self, avatar_unit, player_go_id, ...)
            orig(self, avatar_unit, player_go_id, ...)

            LazyHeroes.set_lazy_status(false)  -- Exiting floor, crown lost
        end)

        -- Maybe Wiz issue here
        Mods.hook:set(MOD_NAME, "AvatarComponent.update_masters", function(orig, self, entities, dt, ...)
            orig(self, entities, dt, ...)

            if LazyHeroes.is_lazy_fucker then
                for unit, context in pairs(entities) do
                    local state = context.state
                    local input_data = state.input

                    if input_data and input_data.is_active then
                        local allowed_inputs = {
                            move = input_data.move,
                            move_raw = input_data.move_raw,
                            aim_raw = input_data.aim_raw,
                            interact = input_data.interact,
                            is_active = input_data.is_active,
                            cursor = input_data.cursor
                        }

                        for key, value in pairs(input_data) do
                            if not allowed_inputs[key] then
                                input_data[key] = nil
                            end
                        end
                    end
                end
            end
        end)
    end

    if path == "lua/extensions/combo" then
        Mods.hook:set(MOD_NAME, "Combo.check_input", function(orig, self, unit, input_data, ...)
            if LazyHeroes.is_lazy_fucker and input_data then
                local filtered_input = {}
                
                for key, value in pairs(input_data) do
                    if key == "movement" or key == "interact" then
                        filtered_input[key] = value
                    end
                end
                
                return orig(self, unit, filtered_input, ...)
            else
                return orig(self, unit, input_data, ...)
            end
        end)
    end

    if path == "lua/ai_states/state_common_character" then
        Mods.hook:set(MOD_NAME, "StateCommonCharacter.check_extra_ability_input", function(orig, component, unit, context, dt, ...)
            if LazyHeroes.is_lazy_fucker then return end
            
            orig(component, unit, context, dt, ...)
        end)
    end

    return result
end)
