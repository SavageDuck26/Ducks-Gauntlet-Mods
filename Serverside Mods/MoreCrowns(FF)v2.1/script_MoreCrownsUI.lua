-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: MoreCrowns Configuration UI Module
-- =================================================================================================

local MOD_NAME = "MoreCrownsUI"

MoreCrowns = MoreCrowns or {}
MoreCrowns.loaded = MoreCrowns.loaded or false
MoreCrowns.CONFIG = MoreCrowns.CONFIG or { enabled = true, drop_chance = 0.25, crown_pickup_ui = true }

-- Store reference to current config widget
local current_config_widget = nil

MoreCrowns.update_config = function()
    update_crown_chance_display()
    MoreCrowns.CONFIG.crown_pickup_ui = MoreCrowns.CONFIG.crown_pickup_ui
end

-- Function to update the crown chance display
local function update_crown_chance_display()
    if not current_config_widget then
        return
    end
    
    if not current_config_widget.get then
        return
    end
    
    local value_widget = current_config_widget:get("crown_chance_value")
    if value_widget and value_widget.set_text then
        value_widget:set_text(string.format("%.0f%%", MoreCrowns.CONFIG.drop_chance * 100))
    end
    
    -- Update description text too
    local description_widget = current_config_widget:get("crown_description")
    if description_widget and description_widget.set_text then
        description_widget:set_text(string.format("Set Crown Spawn Percentage.", MoreCrowns.CONFIG.drop_chance * 100))
    end
end

-- Function to show config overlay
function MoreCrowns.show_config()
    if current_config_widget then
        return -- Already showing
    end
    if not MoreCrowns.loaded then
        return -- Base mod not loaded
    end
    local config_overlay_ui = {
        css = "gui/default_css",
        id = "config_overlay_ui",
        position = "center",
        top_priority = 250,
        type = "container",
        size = {"100%", "100%"},
        children = {
            -- Semi-transparent background
            {
                alpha = 0.8,
                bg_img = "black",
                id = "config_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            -- Main config container
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {720, 400},
                type = "container",
                children = {
                    -- Title
                    {
                        id = "config_title",
                        type = "label",
                        text = "MoreCrowns Config",
                        font_size = 32,
                        color = "white",
                        position = {"center", "top + 30"},
                        text_align = "center"
                    },
                    -- Enable/Disable Crown Mod checkbox
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"center", "top + 60"},
                        children = {
                            {
                                text_align = "left",
                                type = "label",
                                text = "Enable MoreCrowns Mod:",
                                font_size = 18,
                                color = "white",
                                size = {200, 40}
                            },
                            {
                                checked = MoreCrowns.CONFIG.enabled,
                                id = "morecrowns_enabled_checkbox",
                                type = "checkbox",
                                size = {40, 40},
                                on = {
                                    clicked = function()
                                        MoreCrowns.CONFIG.enabled = not MoreCrowns.CONFIG.enabled
                                        MoreCrowns.hide_config()
                                        MoreCrowns.show_config()
                                    end
                                }
                            }
                        }
                    },
                    -- Instructions
                    {
                        id = "instructions",
                        type = "label",
                        text = "Select crown spawn rate:",
                        font_size = 20,
                        color = "white",
                        position = {"center", "top + 95"},
                        text_align = "center"
                    },
                    -- Crown spawn chance slider with percentage display
                    {
                        layout = "horizontal",
                        spacing = 15,
                        type = "container",
                        position = {"center", "top + 130"},
                        children = {
                            {
                                text_align = "left",
                                type = "label",
                                text = "Chance:",
                                font_size = 20,
                                color = "white",
                                size = {80, 50}
                            },
                            {
                                id = "crown_chance_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 0,
                                max = 1,
                                value = MoreCrowns.CONFIG.drop_chance,
                                size = {300, 48},
                                on = {
                                    changed = function(widget, value)
                                        MoreCrowns.CONFIG.drop_chance = value
                                        update_crown_chance_display()
                                    end
                                }
                            },
                            {
                                id = "crown_chance_value",
                                type = "label",
                                text = string.format("%.0f%%", MoreCrowns.CONFIG.drop_chance * 100),
                                font_size = 24,
                                color = "white",
                                size = {80, 40},
                                text_align = "left"
                            }
                        }
                    },
                    -- Description text
                    {
                        id = "crown_description",
                        type = "label",
                        text = string.format("%.0f%% chance - Set any percentage from 0%% to 100%%", MoreCrowns.CONFIG.drop_chance * 100),
                        font_size = 24,
                        color = "white",
                        position = {"center", "top + 200"},
                        text_align = "center"
                    },
                    -- Crown Pickup UI checkbox (compact layout)
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"center", "top + 240"},
                        children = {
                            {
                                text_align = "left",
                                type = "label",
                                text = "Show Crown Pickup UI:",
                                font_size = 18,
                                color = "white",
                                size = {180, 40}
                            },
                            {
                                checked = MoreCrowns.CONFIG.crown_pickup_ui,
                                id = "crown_pickup_ui_checkbox",
                                type = "checkbox",
                                size = {40, 40},
                                on = {
                                    clicked = function()
                                        MoreCrowns.CONFIG.crown_pickup_ui = not MoreCrowns.CONFIG.crown_pickup_ui
                                        MoreCrowns.hide_config()
                                        MoreCrowns.show_config()
                                    end
                                }
                            }
                        }
                    },
                    -- Back button
                    {
                        id = "config_back_button",
                        type = "button",
                        text = "Back",
                        font_size = 20,
                        color = "white",
                        position = {"center", "top + 300"},
                        size = {180, 50},
                        style = "button_standard",
                        on = {
                            clicked = function()
                                MoreCrowns.hide_config()
                            end
                        }
                    }
                }
            }
        }
    }
        
    -- Create the config overlay widget
    current_config_widget = GUI:load_proto(config_overlay_ui)
    
    -- Add it as a modal widget
    GUI:add_modal_widget(current_config_widget, GUI.MAIN_CONTROLLER)
end

-- Function to hide config overlay
function MoreCrowns.hide_config()
    if not current_config_widget then
        return -- Nothing to hide
    end
        
    -- Remove the modal widget
    GUI:remove_modal_widget(current_config_widget)
    
    -- Destroy the widget
    GUI:destroy_widget(current_config_widget)
    current_config_widget = nil
end

