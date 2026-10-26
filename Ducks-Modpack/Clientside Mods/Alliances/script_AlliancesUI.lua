
local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Alliances UI"

local MOD_NAME = "AlliancesUI"

Alliances = Alliances or {}

Alliances.unit_list = Alliances.unit_list or {}
Alliances.CONFIG = Alliances.CONFIG or { enabled = true, unit_enabled = {}, unit_weights = {} }

local current_alliances_config_widget = nil

-- Slider range. 1 is the most common spawn, 8 the rarest (see the weight note in script.lua).
local WEIGHT_MIN = 1
local WEIGHT_MAX = 7

function Alliances.update_weight_displays()
    if not current_alliances_config_widget or not current_alliances_config_widget.get then
        return
    end

    for _, unit in ipairs(Alliances.unit_list) do
        local widget = current_alliances_config_widget:get(unit.id .. "_weight_value")
        if widget and widget.set_text then
            widget:set_text(tostring(Alliances.CONFIG.unit_weights[unit.id] or unit.weight))
        end
    end
end

-- One unit row: enable checkbox, name, weight slider and weight value
local function create_unit_row(unit, x, y)
    return {
        layout = "horizontal",
        spacing = 8,
        type = "container",
        position = {x, y},
        children = {
            {
                checked = Alliances.CONFIG.unit_enabled[unit.id] ~= false,
                id = unit.id .. "_checkbox",
                type = "checkbox",
                size = {30, 30},
                on = {
                    clicked = function()
                        local enabled = Alliances.CONFIG.unit_enabled[unit.id] ~= false
                        Alliances.CONFIG.unit_enabled[unit.id] = not enabled
                        Alliances.rebuild_pools()
                        Alliances.hide_config()
                        Alliances.show_config()
                    end
                }
            },
            {
                text_align = "left",
                type = "label",
                text = unit.label,
                font_size = 16,
                color = "white",
                size = {140, 30}
            },
            {
                id = unit.id .. "_weight_slider",
                type = "slider",
                inherit = "slider",
                min = WEIGHT_MIN,
                max = WEIGHT_MAX + 0.1,
                value = Alliances.CONFIG.unit_weights[unit.id] or unit.weight,
                size = {100, 30},
                on = {
                    changed = function(widget, value)
                        Alliances.CONFIG.unit_weights[unit.id] = math.max(WEIGHT_MIN, math.min(WEIGHT_MAX, math.floor(value + 0.5)))
                        Alliances.rebuild_pools()
                        Alliances.update_weight_displays()
                    end
                }
            },
            {
                id = unit.id .. "_weight_value",
                type = "label",
                text = tostring(Alliances.CONFIG.unit_weights[unit.id] or unit.weight),
                font_size = 16,
                color = "white",
                size = {24, 30}
            }
        }
    }
end

-- Unit rows are laid out three columns wide, ten mobs per column.
local ROWS_PER_COLUMN = 10
local ROW_HEIGHT = 34
local FIRST_ROW_Y = 175
local FIRST_COLUMN_X = 40
local COLUMN_WIDTH = 340

local function create_alliances_config_ui()
    local unit_rows = {}

    for i, unit in ipairs(Alliances.unit_list) do
        local column = math.floor((i - 1) / ROWS_PER_COLUMN) + 1
        local row = (i - 1) % ROWS_PER_COLUMN + 1
        local x = "left + " .. (FIRST_COLUMN_X + (column - 1) * COLUMN_WIDTH)
        local y = "top + " .. (FIRST_ROW_Y + (row - 1) * ROW_HEIGHT)

        table.insert(unit_rows, create_unit_row(unit, x, y))
    end

    local main_children = {
        -- Title
        {
            id = "alliances_config_title",
            type = "label",
            text = "Alliances Config",
            font_size = 32,
            color = "white",
            position = {"center", "top + 30"},
            text_align = "center"
        },
        -- Master toggle for the whole mod
        {
            layout = "horizontal",
            spacing = 10,
            type = "container",
            position = {"center", "top + 90"},
            children = {
                { type = "label", text = "Enable Alliances Mod:", font_size = 24, color = "white", size = {290, 40} },
                {
                    checked = Alliances.CONFIG.enabled,
                    id = "alliances_enabled_checkbox",
                    type = "checkbox",
                    text = "Enabled",
                    color = "yellow",
                    font_size = 20,
                    size = {150, 40},
                    on = {
                        clicked = function()
                            Alliances.CONFIG.enabled = not Alliances.CONFIG.enabled
                            Alliances.hide_config()
                            Alliances.show_config()
                        end
                    }
                }
            }
        },
        {
            id = "alliances_instructions",
            type = "label",
            text = "Uncheck a mob to keep it out of the mix. Weight 1 is the most common, 7 the rarest.",
            font_size = 18,
            color = "white",
            position = {"center", "top + 140"},
            text_align = "center"
        },
        {
            id = "alliances_back_button",
            type = "button",
            text = "Back",
            font_size = 20,
            color = "white",
            position = {"center", "bottom - 35"},
            size = {200, 45},
            style = "button_standard",
            on = {
                clicked = function()
                    Alliances.hide_config()
                end
            }
        }
    }

    for _, row in ipairs(unit_rows) do
        table.insert(main_children, row)
    end

    return {
        css = "gui/default_css",
        id = "alliances_config_ui",
        position = "center",
        top_priority = 250,
        type = "container",
        size = {"100%", "100%"},
        children = {
            -- Semi-transparent background
            {
                alpha = 0.8,
                bg_img = "black",
                id = "alliances_config_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            -- Main config container
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {1060, 620},
                type = "container",
                children = main_children
            }
        }
    }
end

-- Function to show config overlay
function Alliances.show_config()
    if current_alliances_config_widget then
        return
    end
    if not Alliances.loaded then
        return -- Base mod not loaded
    end

    current_alliances_config_widget = GUI:load_proto(create_alliances_config_ui())
    GUI:add_modal_widget(current_alliances_config_widget, GUI.MAIN_CONTROLLER)
    -- Initialize the labels to reflect the current settings
    Alliances.update_weight_displays()
end

-- Function to hide config overlay
function Alliances.hide_config()
    if not current_alliances_config_widget then
        return
    end

    GUI:remove_modal_widget(current_alliances_config_widget)
    GUI:destroy_widget(current_alliances_config_widget)
    current_alliances_config_widget = nil
end
