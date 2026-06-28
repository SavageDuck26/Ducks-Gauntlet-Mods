-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: ColosseumStones Configuration UI Module
-- =================================================================================================

local MOD_NAME = "ColosseumStonesUI"

ColosseumStones = ColosseumStones or {}
ColosseumStones.loaded = ColosseumStones.loaded or false
ColosseumStones.CONFIG = ColosseumStones.CONFIG or {
    enabled = true,
    replacement_chance = 1.0,
    harder_stones_enabled = false,
    stone_types = {
        exploding = true,
        freeze_nova = true,
        mortar = true,
        twister = true,
        beam = true,
        poison_launcher = true,
    },
    stone_weights = {
        exploding = 1,
        freeze_nova = 2,
        mortar = 1,
        twister = 3,
        beam = 3,
        poison_launcher = 1,
    },
}

local current_colosseumstones_config_widget = nil

function update_stone_spawners()
    if not ColosseumStones.spawners then
        return
    end
    
    local enabled_spawners = {}
    local base_spawners = {
        { short_path = "spawner_exploding", stone_type = "exploding" },
        { short_path = "spawner_freeze_nova", stone_type = "freeze_nova" },
        { short_path = "spawner_mortar", stone_type = "mortar" },
        { short_path = "spawner_twister", stone_type = "twister" },
        { short_path = "spawner_beam", stone_type = "beam" },
        { short_path = "spawner_poison_launcher", stone_type = "poison_launcher" }
    }
    
    for _, spawner in ipairs(base_spawners) do
        if ColosseumStones.CONFIG.stone_types[spawner.stone_type] then
            table.insert(enabled_spawners, {
                short_path = spawner.short_path,
                weight = ColosseumStones.CONFIG.stone_weights[spawner.stone_type] or 1
            })
        end
    end
    
    if #enabled_spawners == 0 then
        enabled_spawners = {{ short_path = "spawner_twister", weight = 3 }}
    end
    
    ColosseumStones.spawners = enabled_spawners
end

update_stone_spawners()

function ColosseumStones.load_config()
    update_stone_spawners()
end

function update_replacement_chance_display()
    if not current_colosseumstones_config_widget then
        return
    end
    
    if not current_colosseumstones_config_widget.get then
        return
    end
    
    local value_widget = current_colosseumstones_config_widget:get("replacement_chance_value")
    if value_widget and value_widget.set_text then
        value_widget:set_text(string.format("%.0f%%", ColosseumStones.CONFIG.replacement_chance * 100))
    end
end

function update_weight_displays()
    if not current_colosseumstones_config_widget then
        return
    end
    
    if not current_colosseumstones_config_widget.get then
        return
    end
    
    local weight_widgets = {
        "exploding_weight_value",
        "freeze_nova_weight_value", 
        "mortar_weight_value",
        "twister_weight_value",
        "beam_weight_value",
        "poison_launcher_weight_value"
    }
    
    local weight_values = {
        ColosseumStones.CONFIG.stone_weights.exploding,
        ColosseumStones.CONFIG.stone_weights.freeze_nova,
        ColosseumStones.CONFIG.stone_weights.mortar,
        ColosseumStones.CONFIG.stone_weights.twister,
        ColosseumStones.CONFIG.stone_weights.beam,
        ColosseumStones.CONFIG.stone_weights.poison_launcher
    }
    
    for i, widget_id in ipairs(weight_widgets) do
        local widget = current_colosseumstones_config_widget:get(widget_id)
        if widget and widget.set_text then
            widget:set_text(tostring(weight_values[i]))
        end
    end
end

function toggle_harder_stones()
    ColosseumStones.CONFIG.harder_stones_enabled = not ColosseumStones.CONFIG.harder_stones_enabled
    
    if current_colosseumstones_config_widget then
        local checkbox_widget = current_colosseumstones_config_widget:get("harder_stones_checkbox")
        if checkbox_widget then
            checkbox_widget:set_checked(ColosseumStones.CONFIG.harder_stones_enabled)
        end
    end
end

local function create_colosseumstones_config_ui()
    return {
        css = "gui/default_css",
        id = "colosseumstones_config_ui",
        position = "center",
        top_priority = 250,
        type = "container",
        size = {"100%", "100%"},
        children = {
            -- Semi-transparent background
            {
                alpha = 0.8,
                bg_img = "black",
                id = "colosseumstones_config_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            -- Main config container
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {800, 600},
                type = "container",
                children = {
                    -- Title
                    {
                        id = "colosseumstones_config_title",
                        type = "label",
                        text = "ColosseumStones Config",
                        font_size = 32,
                        color = "white",
                        position = {"center", "top + 30"},
                        text_align = "center"
                    },
                    -- Replacement Chance Section
                    {
                        id = "replacement_chance_title",
                        type = "label",
                        text = "Replacement Chance:",
                        font_size = 22,
                        color = "yellow",
                        position = {"left + 50", "top + 80"},
                        text_align = "left"
                    },
                    -- Replacement chance slider with percentage display
                    {
                        layout = "horizontal",
                        spacing = 15,
                        type = "container",
                        position = {"left + 25", "top + 120"},
                        children = {
                            {
                                id = "replacement_chance_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 0,
                                max = 1,
                                value = ColosseumStones.CONFIG.replacement_chance,
                                size = {350, 55},
                                on = {
                                    changed = function(widget, value)
                                        -- Round to hundredths place
                                        local rounded_value = math.floor(value * 100 + 0.5) / 100
                                        ColosseumStones.CONFIG.replacement_chance = rounded_value
                                        update_stone_spawners()
                                        update_replacement_chance_display()
                                    end
                                }
                            },
                            {
                                id = "replacement_chance_value",
                                type = "label",
                                text = string.format("%.0f%%", ColosseumStones.CONFIG.replacement_chance * 100),
                                font_size = 26,
                                color = "white",
                                size = {90, 55},
                                text_align = "left"
                            }
                        }
                    },
                    -- Harder Stones Checkbox (positioned to the right)
                    {
                        layout = "horizontal",
                        spacing = 15,
                        type = "container",
                        position = {"right - 30", "top + 120"},
                        children = {
                            {
                                checked = ColosseumStones.CONFIG.harder_stones_enabled,
                                id = "harder_stones_checkbox",
                                type = "checkbox",
                                size = {35, 35},
                                on = {
                                    clicked = function()
                                        toggle_harder_stones()
                                    end
                                }
                            },
                            {
                                type = "label",
                                text = "Harder Stones",
                                font_size = 20,
                                color = (ColosseumStones.CONFIG.harder_stones_enabled and "red" or "yellow"),
                                size = {150, 35},
                                text_align = "left"
                            }
                        }
                    },
                    -- Available Stone Types Section
                    {
                        id = "stone_types_title",
                        type = "label",
                        text = "Available Stone Types:",
                        font_size = 20,
                        color = "yellow",
                        position = {"center", "top + 190"},
                        text_align = "center"
                    },
                    -- Exploding checkbox and weight slider
                    {
                        layout = "horizontal",
                        spacing = 15,
                        type = "container",
                        position = {"center", "top + 220"},
                        children = {
                            {
                                checked = ColosseumStones.CONFIG.stone_types.exploding,
                                id = "exploding_checkbox",
                                type = "checkbox",
                                size = {35, 35},
                                on = {
                                    clicked = function()
                                        ColosseumStones.CONFIG.stone_types.exploding = not ColosseumStones.CONFIG.stone_types.exploding
                                        update_stone_spawners()
                                        ColosseumStones.hide_config()
                                        ColosseumStones.show_config()
                                    end
                                }
                            },
                            {
                                text_align = "left",
                                type = "label",
                                text = "Exploding",
                                font_size = 18,
                                color = "white",
                                size = {110, 35}
                            },
                            {
                                type = "label",
                                text = "Weight:",
                                font_size = 16,
                                color = "yellow",
                                size = {60, 35}
                            },
                            {
                                id = "exploding_weight_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 1,
                                max = 4.1,
                                value = ColosseumStones.CONFIG.stone_weights.exploding,
                                size = {140, 35},
                                on = {
                                    changed = function(widget, value)
                                        ColosseumStones.CONFIG.stone_weights.exploding = math.max(1, math.min(4, math.floor(value + 0.5)))
                                        update_stone_spawners()
                                        update_weight_displays()
                                    end
                                }
                            },
                            {
                                id = "exploding_weight_value",
                                type = "label",
                                text = tostring(ColosseumStones.CONFIG.stone_weights.exploding),
                                font_size = 18,
                                color = "white",
                                size = {30, 35}
                            }
                        }
                    },
                    -- Freeze Nova checkbox and weight slider
                    {
                        layout = "horizontal",
                        spacing = 15,
                        type = "container",
                        position = {"center", "top + 255"},
                        children = {
                            {
                                checked = ColosseumStones.CONFIG.stone_types.freeze_nova,
                                id = "freeze_nova_checkbox",
                                type = "checkbox",
                                size = {35, 35},
                                on = {
                                    clicked = function()
                                        ColosseumStones.CONFIG.stone_types.freeze_nova = not ColosseumStones.CONFIG.stone_types.freeze_nova
                                        update_stone_spawners()
                                        ColosseumStones.hide_config()
                                        ColosseumStones.show_config()
                                    end
                                }
                            },
                            {
                                text_align = "left",
                                type = "label",
                                text = "Freeze Nova",
                                font_size = 18,
                                color = "white",
                                size = {110, 35}
                            },
                            {
                                type = "label",
                                text = "Weight:",
                                font_size = 16,
                                color = "yellow",
                                size = {60, 35}
                            },
                            {
                                id = "freeze_nova_weight_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 1,
                                max = 4.1,
                                value = ColosseumStones.CONFIG.stone_weights.freeze_nova,
                                size = {140, 35},
                                on = {
                                    changed = function(widget, value)
                                        ColosseumStones.CONFIG.stone_weights.freeze_nova = math.max(1, math.min(4, math.floor(value + 0.5)))
                                        update_stone_spawners()
                                        update_weight_displays()
                                    end
                                }
                            },
                            {
                                id = "freeze_nova_weight_value",
                                type = "label",
                                text = tostring(ColosseumStones.CONFIG.stone_weights.freeze_nova),
                                font_size = 18,
                                color = "white",
                                size = {30, 35}
                            }
                        }
                    },
                    -- Mortar checkbox and weight slider
                    {
                        layout = "horizontal",
                        spacing = 15,
                        type = "container",
                        position = {"center", "top + 290"},
                        children = {
                            {
                                checked = ColosseumStones.CONFIG.stone_types.mortar,
                                id = "mortar_checkbox",
                                type = "checkbox",
                                size = {35, 35},
                                on = {
                                    clicked = function()
                                        ColosseumStones.CONFIG.stone_types.mortar = not ColosseumStones.CONFIG.stone_types.mortar
                                        update_stone_spawners()
                                        ColosseumStones.hide_config()
                                        ColosseumStones.show_config()
                                    end
                                }
                            },
                            {
                                text_align = "left",
                                type = "label",
                                text = "Mortar",
                                font_size = 18,
                                color = "white",
                                size = {110, 35}
                            },
                            {
                                type = "label",
                                text = "Weight:",
                                font_size = 16,
                                color = "yellow",
                                size = {60, 35}
                            },
                            {
                                id = "mortar_weight_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 1,
                                max = 4.1,
                                value = ColosseumStones.CONFIG.stone_weights.mortar,
                                size = {140, 35},
                                on = {
                                    changed = function(widget, value)
                                        ColosseumStones.CONFIG.stone_weights.mortar = math.max(1, math.min(4, math.floor(value + 0.5)))
                                        update_stone_spawners()
                                        update_weight_displays()
                                    end
                                }
                            },
                            {
                                id = "mortar_weight_value",
                                type = "label",
                                text = tostring(ColosseumStones.CONFIG.stone_weights.mortar),
                                font_size = 18,
                                color = "white",
                                size = {30, 35}
                            }
                        }
                    },
                    -- Twister checkbox and weight slider
                    {
                        layout = "horizontal",
                        spacing = 15,
                        type = "container",
                        position = {"center", "top + 325"},
                        children = {
                            {
                                checked = ColosseumStones.CONFIG.stone_types.twister,
                                id = "twister_checkbox",
                                type = "checkbox",
                                size = {35, 35},
                                on = {
                                    clicked = function()
                                        ColosseumStones.CONFIG.stone_types.twister = not ColosseumStones.CONFIG.stone_types.twister
                                        update_stone_spawners()
                                        ColosseumStones.hide_config()
                                        ColosseumStones.show_config()
                                    end
                                }
                            },
                            {
                                text_align = "left",
                                type = "label",
                                text = "Twister",
                                font_size = 18,
                                color = "white",
                                size = {110, 35}
                            },
                            {
                                type = "label",
                                text = "Weight:",
                                font_size = 16,
                                color = "yellow",
                                size = {60, 35}
                            },
                            {
                                id = "twister_weight_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 1,
                                max = 4.1,
                                value = ColosseumStones.CONFIG.stone_weights.twister,
                                size = {140, 35},
                                on = {
                                    changed = function(widget, value)
                                        ColosseumStones.CONFIG.stone_weights.twister = math.max(1, math.min(4, math.floor(value + 0.5)))
                                        update_stone_spawners()
                                        update_weight_displays()
                                    end
                                }
                            },
                            {
                                id = "twister_weight_value",
                                type = "label",
                                text = tostring(ColosseumStones.CONFIG.stone_weights.twister),
                                font_size = 18,
                                color = "white",
                                size = {30, 35}
                            }
                        }
                    },
                    -- Beam checkbox and weight slider
                    {
                        layout = "horizontal",
                        spacing = 15,
                        type = "container",
                        position = {"center", "top + 360"},
                        children = {
                            {
                                checked = ColosseumStones.CONFIG.stone_types.beam,
                                id = "beam_checkbox",
                                type = "checkbox",
                                size = {35, 35},
                                on = {
                                    clicked = function()
                                        ColosseumStones.CONFIG.stone_types.beam = not ColosseumStones.CONFIG.stone_types.beam
                                        update_stone_spawners()
                                        ColosseumStones.hide_config()
                                        ColosseumStones.show_config()
                                    end
                                }
                            },
                            {
                                text_align = "left",
                                type = "label",
                                text = "Beam",
                                font_size = 18,
                                color = "white",
                                size = {110, 35}
                            },
                            {
                                type = "label",
                                text = "Weight:",
                                font_size = 16,
                                color = "yellow",
                                size = {60, 35}
                            },
                            {
                                id = "beam_weight_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 1,
                                max = 4.1,
                                value = ColosseumStones.CONFIG.stone_weights.beam,
                                size = {140, 35},
                                on = {
                                    changed = function(widget, value)
                                        ColosseumStones.CONFIG.stone_weights.beam = math.max(1, math.min(4, math.floor(value + 0.5)))
                                        update_stone_spawners()
                                        update_weight_displays()
                                    end
                                }
                            },
                            {
                                id = "beam_weight_value",
                                type = "label",
                                text = tostring(ColosseumStones.CONFIG.stone_weights.beam),
                                font_size = 18,
                                color = "white",
                                size = {30, 35}
                            }
                        }
                    },
                    -- Poison Launcher checkbox and weight slider
                    {
                        layout = "horizontal",
                        spacing = 15,
                        type = "container",
                        position = {"center", "top + 395"},
                        children = {
                            {
                                checked = ColosseumStones.CONFIG.stone_types.poison_launcher,
                                id = "poison_launcher_checkbox",
                                type = "checkbox",
                                size = {35, 35},
                                on = {
                                    clicked = function()
                                        ColosseumStones.CONFIG.stone_types.poison_launcher = not ColosseumStones.CONFIG.stone_types.poison_launcher
                                        update_stone_spawners()
                                        ColosseumStones.hide_config()
                                        ColosseumStones.show_config()
                                    end
                                }
                            },
                            {
                                text_align = "left",
                                type = "label",
                                text = "Poison Launcher",
                                font_size = 18,
                                color = "white",
                                size = {110, 35}
                            },
                            {
                                type = "label",
                                text = "Weight:",
                                font_size = 16,
                                color = "yellow",
                                size = {60, 35}
                            },
                            {
                                id = "poison_launcher_weight_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 1,
                                max = 4.1,
                                value = ColosseumStones.CONFIG.stone_weights.poison_launcher,
                                size = {140, 35},
                                on = {
                                    changed = function(widget, value)
                                        ColosseumStones.CONFIG.stone_weights.poison_launcher = math.max(1, math.min(4, math.floor(value + 0.5)))
                                        update_stone_spawners()
                                        update_weight_displays()
                                    end
                                }
                            },
                            {
                                id = "poison_launcher_weight_value",
                                type = "label",
                                text = tostring(ColosseumStones.CONFIG.stone_weights.poison_launcher),
                                font_size = 18,
                                color = "white",
                                size = {30, 35}
                            }
                        }
                    },
                    -- Instructions
                    {
                        id = "instructions",
                        type = "label",
                        text = "Choose replacement chance and which stone types can spawn.",
                        font_size = 22,
                        color = "white",
                        position = {"center", "top + 460"},
                        text_align = "center"
                    },
                    {
                        id = "instructions",
                        type = "label",
                        text = "Higher Weights decreases spawn chance.",
                        font_size = 22,
                        color = "white",
                        position = {"center", "top + 490"},
                        text_align = "center"
                    },
                    -- Back button
                    {
                        id = "colosseumstones_back_button",
                        type = "button",
                        text = "Back",
                        font_size = 20,
                        color = "white",
                        position = {"center", "bottom - 20"},
                        size = {200, 45},
                        style = "button_standard",
                        on = {
                            clicked = function()
                                ColosseumStones.hide_config()
                            end
                        }
                    }
                }
            }
        }
    }
end

function ColosseumStones.show_config()
    if current_colosseumstones_config_widget then
        return
    end
    if not ColosseumStones.loaded then
        return
    end
    
    current_colosseumstones_config_widget = GUI:load_proto(create_colosseumstones_config_ui())
    GUI:add_modal_widget(current_colosseumstones_config_widget, GUI.MAIN_CONTROLLER)
end

function ColosseumStones.hide_config()
    if not current_colosseumstones_config_widget then
        return
    end
    
    GUI:remove_modal_widget(current_colosseumstones_config_widget)
    GUI:destroy_widget(current_colosseumstones_config_widget)
    current_colosseumstones_config_widget = nil
end