-- =================================================================================================
-- Author: Skapp, SavageDuck26 (More code here written by Skapp, added via merge request)
-- Version: 1.4
-- Purpose: Makes player outlines always visible through walls
-- =================================================================================================

local PATH = debug.getinfo(1, "S").source:gsub("^@", "")  -- Retrieve path and remove the "@" prefix
local MOD_NAME = PATH:match("([^/\\]+)[/\\][^/\\]+$") or "UnknownMod"  -- Extract the folder name
local mod_logger, log_message = Mods.logger.init_logger(MOD_NAME)

if _G.ModRegistry then
    _G.ModRegistry[MOD_NAME] = true
    log_message("INFO", "Registered with ModRegistry.")
else
    log_message("INFO", "ModRegistry not available, skipping.")
end

Outlines = Outlines or {}
Outlines.loaded = true

-- Saveable settings
Outlines.CONFIG = Outlines.CONFIG or {
    enabled = true,
    hide_player_names = false,
    opacity = 0.6,
    width = 0.05,
}

-- Set up require hook to patch modules when loaded
Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/components/avatar_component" then
        if AvatarComponent and AvatarComponent.update_slaves then
            local original_update_slaves = AvatarComponent.update_slaves

            AvatarComponent.update_slaves = function(self, entities, dt)
                original_update_slaves(self, entities, dt)

                if Outlines.CONFIG.enabled then
                    for unit, context in pairs(entities) do
                        local state = context.state
                        local settings = context.settings
                        local avatar_type = settings.avatar_type

                        state.outline_activation = Outlines.CONFIG.opacity
                        state.outline_boost_time = math.huge  -- Keep boost active forever
                        state.outline_see_through_alpha = 1  -- Fully visible (no see-through fading near exits)

                        local compensated_max_width = Outlines.CONFIG.width / math.sqrt(Outlines.CONFIG.opacity)
                        self:set_outline(unit, avatar_type, Outlines.CONFIG.opacity, compensated_max_width)
                    end
                end

                if Outlines.CONFIG.hide_player_names then
                    for unit, context in pairs(entities) do
                        local state = context.state
                        state.show_name = false
                    end
                end
            end
        end
    end
    -- ========================================================================================
    if path == "lua/ui/player_hud" then
        if PlayerHud and PlayerHud.init then
            local original_init = PlayerHud.init
            
            PlayerHud.init = function(self, game_client, player_go_id, avatar_type)
                original_init(self, game_client, player_go_id, avatar_type)

                if Outlines.CONFIG.hide_player_names then
                    local steam_name_text = self.widget_lookup.player_steam_name
                    if steam_name_text then
                        steam_name_text:set_text("")
                        steam_name_text:set_visible(false)
                    end
                end
            end
        end

        if PlayerHud and PlayerHud.update then
            local original_update = PlayerHud.update

            PlayerHud.update = function(self, dt)
                original_update(self, dt)
                
                if Outlines.CONFIG.hide_player_names then
                    local steam_name_text = self.widget_lookup.player_steam_name
                    if steam_name_text then
                        steam_name_text:set_visible(false)
                    end
                end
            end
        end
    end
    return result
end)
