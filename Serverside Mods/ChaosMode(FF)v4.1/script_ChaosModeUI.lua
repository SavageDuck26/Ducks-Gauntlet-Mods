-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Chaos/Hell mode configuration UI
-- =================================================================================================

local MOD_NAME = "ChaosModeConfig"

ChaosMode = ChaosMode or {}

local current_chaos_config_widget = nil
local current_mode_label_widget = nil

ChaosMode.CONFIG = ChaosMode.CONFIG or {
    mode = "chaos",
    prevent_backtrack_spawns = true,
}

ChaosMode.chaos_multiplier = ChaosMode.chaos_multiplier or 5000
ChaosMode.hell_multiplier_1 = ChaosMode.hell_multiplier_1 or 15000
ChaosMode.hell_multiplier_2 = ChaosMode.hell_multiplier_2 or 15000
ChaosMode.limbo_multiplier = ChaosMode.limbo_multiplier or 25000

ChaosMode.mode_names = ChaosMode.mode_names or {
    normal = "Normal",
    chaos = "ChaosMode",
    hell = "Welcome To Hell",
    limbo = "Limbo"
}

local function get_mode_display_name()
    return ChaosMode.mode_names[ChaosMode.CONFIG.mode] or "Unknown"
end

local function get_mode_message()
    local messages = {
        normal = "You're not chickening out are you?",
        chaos = "Spinning some chaos into the web.",
        hell = "The Inferno awaits your arrival, Dante.",
        limbo = "Abandon all hope, ye who enter here."
    }
    local current_mode = ChaosMode.CONFIG.mode
    local message = messages[current_mode] or "Unknown state"
    return message
end

local function get_mode_color(mode)
    local colors = {
        normal = "green",
        chaos = "yellow",
        hell = "red",
        limbo = "purple"
    }
    return colors[mode] or "white"
end

function ChaosMode.show_config()
    if current_chaos_config_widget then
        return
    end
    if not ChaosMode.loaded then
        return -- Base mod not loaded
    end
    
    local chaos_config_ui = {
        css = "gui/default_css",
        id = "chaos_config_ui",
        position = "center",
        top_priority = 250,
        type = "container",
        size = {"100%", "100%"},
        children = {
            {
                alpha = 0.7,
                bg_img = "black",
                id = "chaos_config_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {650, 500},
                type = "container",
                children = {
                    -- Title
                    {
                        id = "chaos_config_title",
                        type = "label",
                        text = "ChaosMode Config",
                        font_size = 32,
                        color = "white",
                        position = {"center", "top + 30"},
                        text_align = "center"
                    },
                    -- Current mode display
                    {
                        id = "current_mode_label",
                        type = "label",
                        text = "Active Mode: " .. get_mode_display_name(),
                        font_size = 22,
                        color = get_mode_color(ChaosMode.CONFIG.mode),
                        position = {"center", "top + 75"},
                        text_align = "center"
                    },
                    -- Mode message
                    {
                        id = "status_message_label",
                        type = "label",
                        text = get_mode_message(),
                        font_size = 22,
                        color = get_mode_color(ChaosMode.CONFIG.mode),
                        position = {"center", "top + 350"},
                        text_align = "center"
                    },
                    -- Normal Mode button
                    {
                        id = "normal_mode_button",
                        type = "button",
                        text = "Normal Mode",
                        font_size = 20,
                        color = get_mode_color(ChaosMode.CONFIG.mode == "normal" and "normal" or nil),
                        color_pressed = get_mode_color(ChaosMode.CONFIG.mode == "normal" and "normal" or nil),
                        color_selected = get_mode_color(ChaosMode.CONFIG.mode == "normal" and "normal" or nil),
                        position = {"center", "center - 125"},
                        size = {300, 50},
                        style = "button_standard",
                        on = {
                            clicked = function()
                                ChaosMode.CONFIG.mode = "normal"
                                ChaosMode.hide_config()
                                ChaosMode.show_config()
                            end
                        }
                    },
                    -- Chaos Mode button
                    {
                        id = "chaos_mode_button",
                        type = "button",
                        text = "Chaos Mode",
                        font_size = 20,
                        color = get_mode_color(ChaosMode.CONFIG.mode == "chaos" and "chaos" or nil),
                        color_pressed = get_mode_color(ChaosMode.CONFIG.mode == "chaos" and "chaos" or nil),
                        color_selected = get_mode_color(ChaosMode.CONFIG.mode == "chaos" and "chaos" or nil),
                        position = {"center", "center - 60"},
                        size = {300, 50},
                        style = "button_standard",
                        on = {
                            clicked = function()
                                ChaosMode.CONFIG.mode = "chaos"
                                ChaosMode.hide_config()
                                ChaosMode.show_config()
                            end
                        }
                    },
                    -- Hell Mode button
                    {
                        id = "hell_mode_button",
                        type = "button",
                        text = "Welcome To Hell",
                        font_size = 20,
                        color = get_mode_color(ChaosMode.CONFIG.mode == "hell" and "hell" or nil),
                        color_pressed = get_mode_color(ChaosMode.CONFIG.mode == "hell" and "hell" or nil),
                        color_selected = get_mode_color(ChaosMode.CONFIG.mode == "hell" and "hell" or nil),
                        position = {"center", "center + 5"},
                        size = {300, 50},
                        style = "button_standard",
                        on = {
                            clicked = function()
                                ChaosMode.CONFIG.mode = "hell"
                                ChaosMode.hide_config()
                                ChaosMode.show_config()
                            end
                        }
                    },
                    -- Limbo Mode button
                    {
                        id = "limbo_mode_button",
                        type = "button",
                        text = "Limbo",
                        font_size = 20,
                        color = get_mode_color(ChaosMode.CONFIG.mode == "limbo" and "limbo" or nil),
                        color_pressed = get_mode_color(ChaosMode.CONFIG.mode == "limbo" and "limbo" or nil),
                        color_selected = get_mode_color(ChaosMode.CONFIG.mode == "limbo" and "limbo" or nil),
                        position = {"center", "center + 70"},
                        size = {300, 50},
                        style = "button_standard",
                        on = {
                            clicked = function()
                                ChaosMode.CONFIG.mode = "limbo"
                                ChaosMode.hide_config()
                                ChaosMode.show_config()
                            end
                        }
                    },
                    -- Difficulty info
                    {
                        id = "difficulty_info_normal",
                        type = "label",
                        text = "Normal: 2k",
                        font_size = 18,
                        color = get_mode_color("normal"),
                        position = {"center - 140", "center + 145"},
                        text_align = "left"
                    },
                    {
                        id = "difficulty_info_chaos",
                        type = "label",
                        text = "Chaos: 500k",
                        font_size = 18,
                        color = get_mode_color("chaos"),
                        position = {"center - 20", "center + 145"},
                        text_align = "left"
                    },
                    {
                        id = "difficulty_info_hell",
                        type = "label",
                        text = "Hell: 2M/1M",
                        font_size = 18,
                        color = get_mode_color("hell"),
                        position = {"center + 95", "center + 145"},
                        text_align = "left"
                    },
                    {
                        id = "difficulty_info_2",
                        type = "label",
                        text = "Limbo: 5M Spawn Credits, and a special present just for you.",
                        font_size = 18,
                        color = get_mode_color("limbo"),
                        position = {"center", "center + 170"},
                        text_align = "center"
                    },
                    -- Back button
                    {
                        id = "chaos_back_button",
                        type = "button",
                        text = "Back",
                        font_size = 20,
                        color = "white",
                        position = {"center", "bottom - 20"},
                        size = {200, 45},
                        style = "button_standard",
                        on = {
                            clicked = function()
                                ChaosMode.hide_config()
                            end
                        }
                    }
                }
            }
        }
    }
    
    current_chaos_config_widget = GUI:load_proto(chaos_config_ui)
    GUI:add_modal_widget(current_chaos_config_widget, GUI.MAIN_CONTROLLER)
end

-- Function to hide chaos config overlay
function ChaosMode.hide_config()
    if not current_chaos_config_widget then
        return
    end
    
    GUI:remove_modal_widget(current_chaos_config_widget)
    GUI:destroy_widget(current_chaos_config_widget)
    current_chaos_config_widget = nil
end