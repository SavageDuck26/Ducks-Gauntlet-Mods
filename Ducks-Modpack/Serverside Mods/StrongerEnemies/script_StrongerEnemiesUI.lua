local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "StrongerEnemies UI"

local MOD_NAME = "StrongerEnemiesUI"

StrongerEnemies = StrongerEnemies or {}
StrongerEnemies.loaded = StrongerEnemies.loaded or false

-- Enemy display order. The ability rows come from StrongerEnemies.ABILITY_OPTIONS
-- (script_main.lua), so a new extra is one entry there and no UI edit at all.
local ENEMY_ORDER = {
    { id = "lich", name = "Lich" },
    { id = "necromancer", name = "Necromancer" },
    { id = "mummy_bloated", name = "Bloated Mummy" },
    { id = "demon_heavy", name = "Eye Demon" },
    { id = "spider_queen", name = "Spider Queen" },
}

-- Two balanced columns; every block ends well above the instructions at the bottom.
local COLUMN_X = { "left + 24", "left + 552" }
local PANEL_WIDTH = 1080
local PANEL_HEIGHT = 820
local CONTENT_START_Y = 140
local ENEMY_HEADER_HEIGHT = 38
local ABILITY_ROW_HEIGHT = 30
local GROUP_GAP = 10

local current_widget = nil

-- Rebuilds the panel so a toggled state shows immediately, mirroring the other mod UIs.
local function refresh()
    StrongerEnemies.hide_config()
    StrongerEnemies.show_config()
end

local function create_toggle_row(label_text, checkbox_id, checked, x_anchor, y_pos, on_clicked)
    return {
        layout = "horizontal",
        spacing = 10,
        type = "container",
        position = {x_anchor, "top + " .. y_pos},
        children = {
            {
                type = "label",
                text = label_text,
                font_size = 20,
                color = "yellow",
                size = {290, 40},
                text_align = "left"
            },
            {
                checked = checked,
                id = checkbox_id,
                type = "checkbox",
                text = "Enabled",
                color = "white",
                font_size = 18,
                size = {150, 40},
                on = {
                    clicked = on_clicked
                }
            },
        }
    }
end

local function create_enemy_header(enemy, x_anchor, y_pos)
    local config = StrongerEnemies.get_enemy_config(enemy.id)

    return {
        layout = "horizontal",
        spacing = 10,
        type = "container",
        position = {x_anchor, "top + " .. y_pos},
        children = {
            {
                type = "label",
                text = enemy.name,
                font_size = 20,
                color = "yellow",
                size = {330, 34},
                text_align = "left"
            },
            {
                checked = config.enabled ~= false,
                id = enemy.id .. "_enabled",
                type = "checkbox",
                size = {30, 30},
                on = {
                    clicked = function()
                        config.enabled = config.enabled == false
                        refresh()
                    end
                }
            },
        }
    }
end

local function create_ability_row(enemy, option, x_anchor, y_pos)
    local ability = StrongerEnemies.get_ability_option(enemy.id, option.id)
    local chance = ability.chance or option.default_chance
    local label_id = enemy.id .. "_" .. option.id .. "_label"

    return {
        layout = "horizontal",
        spacing = 8,
        type = "container",
        position = {x_anchor, "top + " .. y_pos},
        children = {
            {
                checked = ability.enabled ~= false,
                id = enemy.id .. "_" .. option.id .. "_enabled",
                type = "checkbox",
                size = {26, 26},
                on = {
                    clicked = function()
                        ability.enabled = ability.enabled == false
                        refresh()
                    end
                }
            },
            {
                type = "label",
                text = option.label,
                font_size = 14,
                color = "white",
                size = {150, 28},
                text_align = "left"
            },
            {
                type = "label",
                text = option.extra,
                font_size = 14,
                color = "cadetblue",
                size = {115, 28},
                text_align = "left"
            },
            {
                id = enemy.id .. "_" .. option.id .. "_slider",
                type = "slider",
                inherit = "slider",
                min = 0,
                max = 1,
                value = chance,
                size = {125, 26},
                on = {
                    changed = function(widget, value)
                        local rounded_value = math.floor(value * 100 + 0.5) / 100
                        ability.chance = rounded_value

                        if current_widget then
                            local label_widget = current_widget:get(label_id)

                            if label_widget and label_widget.set_text then
                                label_widget:set_text(string.format("%.0f%%", rounded_value * 100))
                            end
                        end
                    end
                }
            },
            {
                id = label_id,
                type = "label",
                text = string.format("%.0f%%", chance * 100),
                font_size = 14,
                color = "white",
                size = {44, 28},
                text_align = "left"
            },
        }
    }
end

-- One enemy block: its name + enable box, then one row per ability. Returns the rows and next y.
local function create_enemy_block(enemy, x_anchor, y_pos)
    local options = StrongerEnemies.ABILITY_OPTIONS[enemy.id] or {}
    local rows = { create_enemy_header(enemy, x_anchor, y_pos) }
    local row_y = y_pos + ENEMY_HEADER_HEIGHT

    for _, option in ipairs(options) do
        rows[#rows + 1] = create_ability_row(enemy, option, x_anchor, row_y)
        row_y = row_y + ABILITY_ROW_HEIGHT
    end

    return rows, row_y + GROUP_GAP
end


local function create_config_ui()
    local children = {
        {
            id = "stronger_enemies_title",
            type = "label",
            text = "StrongerEnemies Configuration",
            font_size = 32,
            color = "white",
            position = {"center", "top + 22"},
            text_align = "center"
        },
        create_toggle_row("Enable StrongerEnemies:", "stronger_enemies_enabled_checkbox", StrongerEnemies.CONFIG.enabled ~= false, COLUMN_X[1], 66, function()
            StrongerEnemies.CONFIG.enabled = StrongerEnemies.CONFIG.enabled == false
            refresh()
        end),
        {
            id = "stronger_enemies_instructions",
            type = "label",
            text = "Tick an ability to let that cast also fire the extra beside it, then set its chance.",
            font_size = 16,
            color = "white",
            position = {"center", "bottom - 58"},
            text_align = "center"
        },
        {
            id = "stronger_enemies_back_button",
            type = "button",
            text = "Back",
            font_size = 24,
            color = "white",
            position = {"center", "bottom - 8"},
            size = {200, 46},
            style = "button_standard",
            on = {
                clicked = function()
                    StrongerEnemies.hide_config()
                end
            }
        }
    }

    -- Greedy balance: each enemy block goes to whichever column currently ends higher.
    local column_y = { CONTENT_START_Y, CONTENT_START_Y }

    for _, enemy in ipairs(ENEMY_ORDER) do
        local column = column_y[1] <= column_y[2] and 1 or 2
        local rows, next_y = create_enemy_block(enemy, COLUMN_X[column], column_y[column])

        column_y[column] = next_y

        for _, row in ipairs(rows) do
            table.insert(children, row)
        end
    end

    return {
        css = "gui/default_css",
        type = "container",
        size = {"100%", "100%"},
        children = {
            -- Semi-transparent background
            {
                alpha = 0.7,
                bg_img = "black",
                id = "stronger_enemies_overlay_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            -- Main config container
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {PANEL_WIDTH, PANEL_HEIGHT},
                type = "container",
                children = children
            }
        }
    }
end

function StrongerEnemies.show_config()
    if current_widget then
        return
    end

    current_widget = GUI:load_proto(create_config_ui())
    GUI:add_modal_widget(current_widget, GUI.MAIN_CONTROLLER)
end

function StrongerEnemies.hide_config()
    if not current_widget then
        return
    end

    GUI:remove_modal_widget(current_widget)
    GUI:destroy_widget(current_widget)
    current_widget = nil
end

