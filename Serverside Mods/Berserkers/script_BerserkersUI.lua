local MOD_NAME = "BerserkersUI"

-- Ensure Berserkers table exists (should be loaded from script.lua first)
Berserkers = Berserkers or {}
Berserkers.ui_loaded = Berserkers.ui_loaded or false

local current_widget = nil

-- Function to create enemy config row
local function create_enemy_row(enemy_data, y_pos)
    local enemy_id = enemy_data.id
    local config = Berserkers.CONFIG.enemies[enemy_id] or { juggernaut = true, berserker = true }
    
    return {
        layout = "horizontal",
        spacing = 15,
        type = "container",
        position = {"left + 100", y_pos},
        children = {
            {
                type = "label",
                text = enemy_data.name,
                font_size = 18,
                color = "white",
                size = {240, 40},
                text_align = "left"
            },
            {
                checked = config.juggernaut,
                id = enemy_id .. "_juggernaut_checkbox",
                type = "checkbox",
                text = "Juggernaut",
                color = "green",
                font_size = 16,
                size = {180, 40},
                on = {
                    clicked = function()
                        Berserkers.CONFIG.enemies[enemy_id].juggernaut = not Berserkers.CONFIG.enemies[enemy_id].juggernaut
                        Berserkers.hide_config()
                        Berserkers.show_config()
                    end
                }
            },
            {
                checked = config.berserker,
                id = enemy_id .. "_berserker_checkbox",
                type = "checkbox",
                text = "Berserker",
                color = "purple",
                font_size = 16,
                size = {180, 40},
                on = {
                    clicked = function()
                        Berserkers.CONFIG.enemies[enemy_id].berserker = not Berserkers.CONFIG.enemies[enemy_id].berserker
                        Berserkers.hide_config()
                        Berserkers.show_config()
                    end
                }
            }
        }
    }
end

local function create_config_ui()
    local enemy_rows = {}
    local start_y = 270
    
    local header = {
        layout = "horizontal",
        spacing = 15,
        type = "container",
        position = {"left + 65", "top + 230"},
        children = {
            { type = "label", text = "Enemies", font_size = 20, color = "yellow", size = {240, 40}, text_align = "left" },
            { type = "label", text = "Enable Juggernaut", font_size = 20, color = "yellow", size = {180, 40}, text_align = "center" },
            { type = "label", text = "Enable Berserker", font_size = 20, color = "yellow", size = {180, 40}, text_align = "center" }
        }
    }
    
    for i, enemy_data in ipairs(Berserkers.enemy_list) do
        table.insert(enemy_rows, create_enemy_row(enemy_data, "top + " .. (start_y + (i-1) * 45)))
    end
    
    local main_children = {
        {
            id = "berserkers_title",
            type = "label",
            text = "Berserkers Configuration",
            font_size = 36,
            color = "white",
            position = {"center", "top + 30"},
            text_align = "center"
        },
        {
            layout = "horizontal",
            spacing = 10,
            type = "container",
            position = {"center", "top + 85"},
            children = {
                { type = "label", text = "Enable Berserkers Mod:", font_size = 24, color = "white", size = {270, 40} },
                {
                    checked = Berserkers.CONFIG.enabled,
                    id = "berserkers_enabled_checkbox",
                    type = "checkbox",
                    text = "Enabled",
                    color = "yellow",
                    font_size = 20,
                    size = {150, 40},
                    on = {
                        clicked = function()
                            Berserkers.CONFIG.enabled = not Berserkers.CONFIG.enabled
                            Berserkers.hide_config()
                            Berserkers.show_config()
                        end
                    }
                }
            }
        },
        {
            layout = "horizontal",
            spacing = 10,
            type = "container",
            position = {"left + 80", "top + 135"},
            children = {
                { type = "label", text = "Juggernaut Chance:", font_size = 20, color = "white", size = {200, 50} },
                {
                    id = "juggernaut_chance_slider",
                    type = "slider",
                    inherit = "slider",
                    min = 0,
                    max = 1,
                    value = Berserkers.CONFIG.juggernaut_chance,
                    size = {400, 50},
                    on = {
                        changed = function(widget, value)
                            Berserkers.CONFIG.juggernaut_chance = math.floor(value * 100 + 0.5) / 100
                            local label = current_widget:get("juggernaut_chance_label")
                            if label and label.set_text then
                                label:set_text(string.format("%.0f%%", Berserkers.CONFIG.juggernaut_chance * 100))
                            end
                        end
                    }
                },
                {
                    id = "juggernaut_chance_label",
                    type = "label",
                    text = string.format("%.0f%%", Berserkers.CONFIG.juggernaut_chance * 100),
                    font_size = 20,
                    color = "white",
                    size = {60, 50},
                    text_align = "left"
                }
            }
        },
        {
            layout = "horizontal",
            spacing = 10,
            type = "container",
            position = {"left + 80", "top + 195"},
            children = {
                { type = "label", text = "Berserker Chance:", font_size = 20, color = "white", size = {200, 50} },
                {
                    id = "berserker_chance_slider",
                    type = "slider",
                    inherit = "slider",
                    min = 0,
                    max = 1,
                    value = Berserkers.CONFIG.berserker_chance,
                    size = {400, 50},
                    on = {
                        changed = function(widget, value)
                            Berserkers.CONFIG.berserker_chance = math.floor(value * 100 + 0.5) / 100
                            local label = current_widget:get("berserker_chance_label")
                            if label and label.set_text then
                                label:set_text(string.format("%.0f%%", Berserkers.CONFIG.berserker_chance * 100))
                            end
                        end
                    }
                },
                {
                    id = "berserker_chance_label",
                    type = "label",
                    text = string.format("%.0f%%", Berserkers.CONFIG.berserker_chance * 100),
                    font_size = 20,
                    color = "white",
                    size = {60, 50},
                    text_align = "left"
                }
            }
        },
        header,
        {
            id = "instructions",
            type = "label",
            text = "Enable or disable Juggernaut and Berserker modes for each enemy type.",
            font_size = 20,
            color = "white",
            position = {"center", "bottom - 80"},
            text_align = "center"
        },
        {
            id = "berserkers_back_button",
            type = "button",
            text = "Back",
            font_size = 24,
            color = "white",
            position = {"center", "bottom - 30"},
            size = {200, 50},
            style = "button_standard",
            on = { clicked = function() Berserkers.hide_config() end }
        }
    }
    
    for _, row in ipairs(enemy_rows) do
        table.insert(main_children, row)
    end
    
    return {
        css = "gui/default_css",
        type = "container",
        size = {"100%", "100%"},
        children = {
            { alpha = 0.7, bg_img = "black", id = "berserkers_overlay_background", position = {"center", "top"}, size = {"100%", "100%"} },
            { bg_img = "menu_standard_background_stone", position = {"center", "center"}, size = {900, 900}, type = "container", children = main_children }
        }
    }
end

function Berserkers.show_config()
    if current_widget then return end
    current_widget = GUI:load_proto(create_config_ui())
    GUI:add_modal_widget(current_widget, GUI.MAIN_CONTROLLER)
end

function Berserkers.hide_config()
    if not current_widget then return end
    GUI:remove_modal_widget(current_widget)
    GUI:destroy_widget(current_widget)
    current_widget = nil
end