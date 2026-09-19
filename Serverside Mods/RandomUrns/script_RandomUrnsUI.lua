
local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "RandomUrns UI"

local MOD_NAME = "RandomUrnsUI"

RandomUrns = RandomUrns or {}

RandomUrns.loaded = RandomUrns.loaded or false

RandomUrns.gold_drops = RandomUrns.gold_drops or {}

-- Settings stored directly on RandomUrns
RandomUrns.CONFIG = RandomUrns.CONFIG or { drop_chance_small = 0.01, drop_chance_big = 0.20, small_props_enabled = true, big_props_enabled = true, drop_types = {}, drop_weights = {} }

local current_randomurns_config_widget = nil

function RandomUrns.load_config()
    -- Pre-5.1 saves kept a single drop_chance for the small props
    if RandomUrns.CONFIG.drop_chance ~= nil then
        RandomUrns.CONFIG.drop_chance_small = RandomUrns.CONFIG.drop_chance
        RandomUrns.CONFIG.drop_chance = nil
    end

    RandomUrns.update_drop_tables()
end

-- Refresh the weight number labels (called after a slider moves or a reload)
function RandomUrns.update_weight_displays()
    if not current_randomurns_config_widget or not current_randomurns_config_widget.get then
        return
    end

    for _, entry in ipairs(RandomUrns.drop_table) do
        local widget = current_randomurns_config_widget:get(entry.id .. "_weight_value")
        if widget and widget.set_text then
            widget:set_text(tostring(RandomUrns.CONFIG.drop_weights[entry.id] or 1))
        end
    end
end

-- One drop row: enable checkbox, name, weight slider and weight value
local function create_drop_row(entry, x, y)
    return {
        layout = "horizontal",
        spacing = 12,
        type = "container",
        position = {x, y},
        children = {
            {
                checked = RandomUrns.CONFIG.drop_types[entry.id],
                id = entry.id .. "_checkbox",
                type = "checkbox",
                size = {35, 35},
                on = {
                    clicked = function()
                        RandomUrns.CONFIG.drop_types[entry.id] = not RandomUrns.CONFIG.drop_types[entry.id]
                        RandomUrns.update_drop_tables()
                        RandomUrns.hide_config()
                        RandomUrns.show_config()
                    end
                }
            },
            {
                text_align = "left",
                type = "label",
                text = entry.label,
                font_size = 18,
                color = "white",
                size = {175, 35}
            },
            {
                type = "label",
                text = "Weight:",
                font_size = 16,
                color = "yellow",
                size = {60, 35}
            },
            {
                id = entry.id .. "_weight_slider",
                type = "slider",
                inherit = "slider",
                min = 1,
                max = 4.1,
                value = RandomUrns.CONFIG.drop_weights[entry.id] or 1,
                size = {120, 35},
                on = {
                    changed = function(widget, value)
                        RandomUrns.CONFIG.drop_weights[entry.id] = math.max(1, math.min(4, math.floor(value + 0.5)))
                        RandomUrns.update_drop_tables()
                        RandomUrns.update_weight_displays()
                    end
                }
            },
            {
                id = entry.id .. "_weight_value",
                type = "label",
                text = tostring(RandomUrns.CONFIG.drop_weights[entry.id] or 1),
                font_size = 18,
                color = "white",
                size = {30, 35}
            }
        }
    }
end

local function create_randomurns_config_ui()
    -- Two columns: consumables/orbs on the left, gold and keys on the right.
    local drop_rows = {}
    for i, entry in ipairs(RandomUrns.drop_table) do
        local x = (i <= 6) and "center - 250" or "center + 250"
        local row = (i <= 6) and i or (i - 6)
        table.insert(drop_rows, create_drop_row(entry, x, "top + " .. (225 + (row - 1) * 35)))
    end

    local main_children = {
        -- Title
        {
            id = "randomurns_config_title",
            type = "label",
            text = "RandomUrns Config",
            font_size = 32,
            color = "white",
            position = {"center", "top + 30"},
            text_align = "center"
        },
        -- Small Prop Drop Chance toggle and slider
        {
            layout = "horizontal",
            spacing = 20,
            type = "container",
            position = {"center", "top + 72"},
            children = {
                {
                    type = "label",
                    text = "Small Prop Drop Chance:",
                    font_size = 22,
                    color = "yellow",
                    size = {280, 55},
                    text_align = "left"
                },
                {
                    checked = RandomUrns.CONFIG.small_props_enabled,
                    id = "small_props_enabled_checkbox",
                    type = "checkbox",
                    text = "Enabled",
                    color = "white",
                    font_size = 20,
                    size = {140, 40},
                    on = {
                        clicked = function()
                            RandomUrns.CONFIG.small_props_enabled = not RandomUrns.CONFIG.small_props_enabled
                            RandomUrns.hide_config()
                            RandomUrns.show_config()
                        end
                    }
                },
                {
                    id = "urns_dropchance_slider",
                    type = "slider",
                    inherit = "slider",
                    min = 0,
                    max = 1,
                    value = RandomUrns.CONFIG.drop_chance_small or 0.01,
                    size = {320, 55},
                    on = {
                        changed = function(widget, value)
                            local rounded_value = math.floor(value * 100 + 0.5) / 100
                            RandomUrns.CONFIG.drop_chance_small = rounded_value
                            local value_label = current_randomurns_config_widget and current_randomurns_config_widget:get("urns_dropchance_value")
                            if value_label and value_label.set_text then
                                value_label:set_text(string.format("%d%%", math.floor((rounded_value or 0) * 100 + 0.5)))
                            end
                        end
                    }
                },
                {
                    id = "urns_dropchance_value",
                    type = "label",
                    text = string.format("%d%%", math.floor(((RandomUrns.CONFIG.drop_chance_small or 0.01) * 100) + 0.5)),
                    font_size = 24,
                    color = "white",
                    size = {80, 55},
                    text_align = "left"
                }
            }
        },
        -- Big Prop Drop Chance toggle and slider
        {
            layout = "horizontal",
            spacing = 20,
            type = "container",
            position = {"center", "top + 132"},
            children = {
                {
                    type = "label",
                    text = "Big Prop Drop Chance:",
                    font_size = 22,
                    color = "yellow",
                    size = {280, 55},
                    text_align = "left"
                },
                {
                    checked = RandomUrns.CONFIG.big_props_enabled,
                    id = "big_props_enabled_checkbox",
                    type = "checkbox",
                    text = "Enabled",
                    color = "white",
                    font_size = 20,
                    size = {140, 40},
                    on = {
                        clicked = function()
                            RandomUrns.CONFIG.big_props_enabled = not RandomUrns.CONFIG.big_props_enabled
                            RandomUrns.hide_config()
                            RandomUrns.show_config()
                        end
                    }
                },
                {
                    id = "big_dropchance_slider",
                    type = "slider",
                    inherit = "slider",
                    min = 0,
                    max = 1,
                    value = RandomUrns.CONFIG.drop_chance_big or 0.20,
                    size = {320, 55},
                    on = {
                        changed = function(widget, value)
                            local rounded_value = math.floor(value * 100 + 0.5) / 100
                            RandomUrns.CONFIG.drop_chance_big = rounded_value
                            local value_label = current_randomurns_config_widget and current_randomurns_config_widget:get("big_dropchance_value")
                            if value_label and value_label.set_text then
                                value_label:set_text(string.format("%d%%", math.floor((rounded_value or 0) * 100 + 0.5)))
                            end
                        end
                    }
                },
                {
                    id = "big_dropchance_value",
                    type = "label",
                    text = string.format("%d%%", math.floor(((RandomUrns.CONFIG.drop_chance_big or 0.20) * 100) + 0.5)),
                    font_size = 24,
                    color = "white",
                    size = {80, 55},
                    text_align = "left"
                }
            }
        },
        -- Drop pool title
        {
            id = "drop_pool_title",
            type = "label",
            text = "Drop Pool:",
            font_size = 24,
            color = "yellow",
            position = {"center", "top + 195"},
            text_align = "center"
        },

        -- Instructions
        {
            id = "instructions",
            type = "label",
            text = "Big Props: boxes, barrels, vases, spider eggs, urns and goldrocks.",
            font_size = 20,
            color = "white",
            position = {"center", "top + 455"},
            text_align = "center"
        },
        {
            id = "instructions",
            type = "label",
            text = "Small Props: every other smashable. Weight 1 is the most common drop, 4 the rarest.",
            font_size = 20,
            color = "white",
            position = {"center", "top + 485"},
            text_align = "center"
        },
        -- Back button
        {
            id = "randomurns_back_button",
            type = "button",
            text = "Back",
            font_size = 20,
            color = "white",
            position = {"center", "bottom - 40"},
            size = {200, 45},
            style = "button_standard",
            on = {
                clicked = function()
                    RandomUrns.hide_config()
                end
            }
        }
    }

    for _, row in ipairs(drop_rows) do
        table.insert(main_children, row)
    end

    return {
        css = "gui/default_css",
        id = "randomurns_config_ui",
        position = "center",
        top_priority = 250,
        type = "container",
        size = {"100%", "100%"},
        children = {
            -- Semi-transparent background
            {
                alpha = 0.8,
                bg_img = "black",
                id = "randomurns_config_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            -- Main config container
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {1000, 600},
                type = "container",
                children = main_children
            }
        }
    }
end

-- Function to show config overlay
function RandomUrns.show_config()
    if current_randomurns_config_widget then
        return
    end
    if not RandomUrns.loaded then
        return -- Base mod not loaded
    end

    current_randomurns_config_widget = GUI:load_proto(create_randomurns_config_ui())
    GUI:add_modal_widget(current_randomurns_config_widget, GUI.MAIN_CONTROLLER)
    -- Initialize the labels to reflect the current settings
    local value_label = current_randomurns_config_widget and current_randomurns_config_widget:get("urns_dropchance_value")
    if value_label and value_label.set_text then
        value_label:set_text(string.format("%d%%", math.floor(((RandomUrns.CONFIG.drop_chance_small or 0.01) * 100) + 0.5)))
    end

    local big_value_label = current_randomurns_config_widget and current_randomurns_config_widget:get("big_dropchance_value")
    if big_value_label and big_value_label.set_text then
        big_value_label:set_text(string.format("%d%%", math.floor(((RandomUrns.CONFIG.drop_chance_big or 0.20) * 100) + 0.5)))
    end
    RandomUrns.update_weight_displays()
end

-- Function to hide config overlay
function RandomUrns.hide_config()
    if not current_randomurns_config_widget then
        return
    end

    GUI:remove_modal_widget(current_randomurns_config_widget)
    GUI:destroy_widget(current_randomurns_config_widget)
    current_randomurns_config_widget = nil
end

