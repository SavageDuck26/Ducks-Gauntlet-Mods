-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Outlines Configuration UI Module
-- =================================================================================================

local MOD_NAME = "OutlinesUI"

Outlines = Outlines or {}

local current_outlines_config_widget = nil

-- Function to update opacity display
local function update_opacity_display()
    if not current_outlines_config_widget then
        return
    end
    
    if not current_outlines_config_widget.get then
        return
    end
    
    local value_widget = current_outlines_config_widget:get("opacity_value")
    if value_widget and value_widget.set_text then
        value_widget:set_text(string.format("%.1f", Outlines.CONFIG.opacity))
    end
end

-- Function to update width display
local function update_width_display()
    if not current_outlines_config_widget then
        return
    end
    
    if not current_outlines_config_widget.get then
        return
    end
    
    local value_widget = current_outlines_config_widget:get("width_value")
    if value_widget and value_widget.set_text then
        value_widget:set_text(string.format("%.3f", Outlines.CONFIG.width))
    end
end

-- Function to show config overlay
local function show_outlines_config()
    if current_outlines_config_widget then
        return
    end
    if not Outlines.loaded then
        return
    end
    local outlines_config_ui = {
        css = "gui/default_css",
        id = "outlines_config_ui",
        position = "center",
        top_priority = 250,
        type = "container",
        size = {"100%", "100%"},
        children = {
            -- Semi-transparent background
            {
                alpha = 0.8,
                bg_img = "black",
                id = "outlines_config_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            -- Main config container
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {700, 500},
                type = "container",
                children = {
                    -- Title
                    {
                        id = "outlines_config_title",
                        type = "label",
                        text = "Outlines Config",
                        font_size = 32,
                        color = "white",
                        position = {"center", "top + 30"},
                        text_align = "center"
                    },
                    -- Enable Outlines checkbox
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"center", "top + 100"},
                        children = {
                            {
                                checked = Outlines.CONFIG.enabled,
                                id = "enable_outlines_checkbox",
                                type = "checkbox",
                                size = {25, 25},
                                on = {
                                    clicked = function()
                                        Outlines.CONFIG.enabled = not Outlines.CONFIG.enabled
                                        Outlines.hide_config()
                                        Outlines.show_config()
                                    end
                                }
                            },
                            {
                                text_align = "left",
                                type = "label",
                                text = "Enable Outlines",
                                font_size = 20,
                                color = "white",
                                size = {180, 25}
                            }
                        }
                    },
                    -- Hide Player Names checkbox
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"center", "top + 150"},
                        children = {
                            {
                                checked = Outlines.CONFIG.hide_player_names,
                                id = "hide_names_checkbox",
                                type = "checkbox",
                                size = {25, 25},
                                on = {
                                    clicked = function()
                                        Outlines.CONFIG.hide_player_names = not Outlines.CONFIG.hide_player_names
                                        Outlines.hide_config()
                                        Outlines.show_config()
                                    end
                                }
                            },
                            {
                                text_align = "left",
                                type = "label",
                                text = "Hide Player Names",
                                font_size = 20,
                                color = "white",
                                size = {180, 25}
                            }
                        }
                    },
                    -- Outline Opacity Section
                    {
                        id = "opacity_title",
                        type = "label",
                        text = "Outline Opacity:",
                        font_size = 22,
                        color = "yellow",
                        position = {"left + 80", "top + 210"},
                        text_align = "left"
                    },
                    -- Opacity slider with value display
                    {
                        layout = "horizontal",
                        spacing = 15,
                        type = "container",
                        position = {"left + 80", "top + 250"},
                        children = {
                            {
                                id = "opacity_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 0.1,
                                max = 1.0,
                                value = Outlines.CONFIG.opacity,
                                size = {300, 48},
                                on = {
                                    changed = function(widget, value)
                                        -- Round to hundredths place
                                        local rounded_value = math.floor(value * 100 + 0.5) / 100
                                        Outlines.CONFIG.opacity = rounded_value
                                        update_opacity_display()
                                    end
                                }
                            },
                            {
                                id = "opacity_value",
                                type = "label",
                                text = string.format("%.1f", Outlines.CONFIG.opacity),
                                font_size = 20,
                                color = "white",
                                size = {60, 40},
                                text_align = "left"
                            }
                        }
                    },
                    -- Outline Width Section
                    {
                        id = "width_title",
                        type = "label",
                        text = "Outline Width:",
                        font_size = 22,
                        color = "yellow",
                        position = {"left + 80", "top + 310"},
                        text_align = "left"
                    },
                    -- Width slider with value display
                    {
                        layout = "horizontal",
                        spacing = 15,
                        type = "container",
                        position = {"left + 80", "top + 350"},
                        children = {
                            {
                                id = "width_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 0.01,
                                max = 0.2,
                                value = Outlines.CONFIG.width,
                                size = {300, 48},
                                on = {
                                    changed = function(widget, value)
                                        -- Round to hundredths place
                                        local rounded_value = math.floor(value * 100 + 0.5) / 100
                                        Outlines.CONFIG.width = rounded_value
                                        update_width_display()
                                    end
                                }
                            },
                            {
                                id = "width_value",
                                type = "label",
                                text = string.format("%.3f", Outlines.CONFIG.width),
                                font_size = 20,
                                color = "white",
                                size = {80, 40},
                                text_align = "left"
                            }
                        }
                    },
                    -- Back button
                    {
                        id = "outlines_back_button",
                        type = "button",
                        text = "Back",
                        font_size = 20,
                        color = "white",
                        position = {"center", "bottom - 40"},
                        size = {200, 45},
                        style = "button_standard",
                        on = {
                            clicked = function()
                                Outlines.hide_config()
                            end
                        }
                    }
                }
            }
        }
    }
    
    current_outlines_config_widget = GUI:load_proto(outlines_config_ui)
    GUI:add_modal_widget(current_outlines_config_widget, GUI.MAIN_CONTROLLER)
end

-- Make the show function globally accessible
Outlines.show_config = show_outlines_config

-- Function to hide config overlay
local function hide_outlines_config()
    if not current_outlines_config_widget then
        return
    end
    
    GUI:remove_modal_widget(current_outlines_config_widget)
    GUI:destroy_widget(current_outlines_config_widget)
    current_outlines_config_widget = nil
end

Outlines.hide_config = hide_outlines_config

