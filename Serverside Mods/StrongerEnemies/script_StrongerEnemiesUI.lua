
local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "StrongerEnemies UI"


local MOD_NAME = "StrongerEnemiesUI"

StrongerEnemies = StrongerEnemies or {}
StrongerEnemies.loaded = StrongerEnemies.loaded or false

-- Config schema, grouped per enemy. Every slider is listed once and is placed automatically:
--   settings without a nightmare flag sit in the left (normal) column
--   settings with nightmare = true sit in the right (nightmare) column, on the same row
-- The enemy name always spans the left; if an enemy has no nightmare slider its right cell stays
-- empty. Adding a new ability is one entry here; the grid rebuilds itself.
-- The per-enemy checkbox toggles StrongerEnemies.CONFIG[<id>].enabled.
local ENEMY_DATA = {
    {
        id = "lich",
        name = "Lich",
        settings = {
            { key = "shadowdive_bomb_chance", label = "Shadowdive Bomb", default = 1.00 },
            { key = "storm_bomb_chance", label = "Storm Bomb", default = 0.12, nightmare = true },
        },
    },
    {
        id = "necromancer",
        name = "Necromancer",
        settings = {
            { key = "winter_orb_chance", label = "Orb of Winter", default = 0.50 },
            { key = "shield_chance", label = "Lightning Shield", default = 0.20 },
        },
    },
    {
        id = "mummy_bloated",
        name = "Bloated Mummy",
        settings = {
            { key = "acid_bomber_chance", label = "Acid Bomber", default = 0.10 },
            { key = "ice_bomber_chance", label = "Ice Bomber", default = 0.10 },
            { key = "fire_bomber_chance", label = "Fire Bomber", default = 0.10 },
        },
    },
    {
        id = "demon_heavy",
        name = "Eye Demon",
        settings = {
            { key = "super_nova_orb_chance", label = "Super Nova Orb", default = 1.00 },
            { key = "confusing_glare_shield_chance", label = "Confusing Glare Shield", default = 1.00 },
            { key = "demon_egg_orb_chance", label = "Demon Egg Orb", default = 1.00 },
            { key = "super_nova_hover_chance", label = "Hover Orb", default = 1.00, nightmare = true },
            { key = "super_nova_mortar_chance", label = "Mortar Barrage", default = 1.00, nightmare = true },
        },
    },
    {
        id = "spider_queen",
        name = "Spider Queen",
        settings = {
            { key = "spin_web_chance", label = "Spin Web", default = 1.00 },
            { key = "lay_eggs_chance", label = "Lay Eggs", default = 1.00 },
        },
    },
}

-- One row per enemy: the name spans the left, then each enemy's normal sliders sit in column 1 and
-- its nightmare sliders line up in column 2.
local COLUMN_X = { "left + 30", "left + 500" }
local CONTENT_START_Y = 142
local ENEMY_ROW_HEIGHT = 34
local SETTING_ROW_HEIGHT = 32
local GROUP_GAP = 8

local current_widget = nil

-- Rebuilds the panel so a toggled state shows immediately, mirroring the other mod UIs.
local function refresh()
    StrongerEnemies.hide_config()
    StrongerEnemies.show_config()
end

-- The per-enemy config table, created on demand so a missing section can still be shown.
local function enemy_config(enemy_id)
    local entry = StrongerEnemies.CONFIG[enemy_id]

    if not entry then
        entry = { enabled = true }
        StrongerEnemies.CONFIG[enemy_id] = entry
    end

    return entry
end

-- Splits one enemy's settings into the two columns, keeping the order they are listed in.
local function split_settings(enemy_data)
    local normal_settings = {}
    local nightmare_settings = {}

    for _, setting in ipairs(enemy_data.settings) do
        if setting.nightmare == true then
            table.insert(nightmare_settings, setting)
        else
            table.insert(normal_settings, setting)
        end
    end

    return normal_settings, nightmare_settings
end

local function create_toggle_row(label_text, checked, x_anchor, y_pos, on_clicked)
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

local function create_enemy_header(enemy_id, name, x_anchor, y_pos)
    return {
        layout = "horizontal",
        spacing = 10,
        type = "container",
        position = {x_anchor, "top + " .. y_pos},
        children = {
            {
                type = "label",
                text = name,
                font_size = 20,
                color = "yellow",
                size = {320, 34},
                text_align = "left"
            },
            {
                checked = enemy_config(enemy_id).enabled,
                id = enemy_id .. "_enabled",
                type = "checkbox",
                size = {32, 32},
                on = {
                    clicked = function()
                        enemy_config(enemy_id).enabled = not enemy_config(enemy_id).enabled
                        refresh()
                    end
                }
            },
        }
    }
end

local function create_setting_row(enemy_id, setting, x_anchor, y_pos)
    local entry = enemy_config(enemy_id)
    local chance_value = entry[setting.key] or setting.default

    return {
        layout = "horizontal",
        spacing = 6,
        type = "container",
        position = {x_anchor, "top + " .. y_pos},
        children = {
            {
                type = "label",
                text = setting.label .. ":",
                font_size = 15,
                color = "white",
                size = {210, 32},
                text_align = "left"
            },
            {
                id = enemy_id .. "_" .. setting.key .. "_slider",
                type = "slider",
                inherit = "slider",
                min = 0,
                max = 1,
                value = chance_value,
                size = {150, 30},
                on = {
                    changed = function(widget, value)
                        local rounded_value = math.floor(value * 100 + 0.5) / 100
                        entry[setting.key] = rounded_value

                        if current_widget then
                            local label_widget = current_widget:get(enemy_id .. "_" .. setting.key .. "_label")

                            if label_widget and label_widget.set_text then
                                label_widget:set_text(string.format("%.0f%%", rounded_value * 100))
                            end
                        end
                    end
                }
            },
            {
                id = enemy_id .. "_" .. setting.key .. "_label",
                type = "label",
                text = string.format("%.0f%%", chance_value * 100),
                font_size = 16,
                color = "white",
                size = {50, 32},
                text_align = "left"
            },
        }
    }
end

-- Builds one enemy: a full-width name row, then a shared row per setting with the normal slider on
-- the left and the nightmare slider (if any) on the right. Returns the rows and the next free y.
local function create_enemy_block(enemy_data, y_pos)
    local rows = {}
    local normal_settings, nightmare_settings = split_settings(enemy_data)

    table.insert(rows, create_enemy_header(enemy_data.id, enemy_data.name, COLUMN_X[1], y_pos))

    local settings_y = y_pos + ENEMY_ROW_HEIGHT
    local row_count = math.max(#normal_settings, #nightmare_settings)

    for i = 1, row_count do
        if normal_settings[i] then
            table.insert(rows, create_setting_row(enemy_data.id, normal_settings[i], COLUMN_X[1], settings_y))
        end

        if nightmare_settings[i] then
            table.insert(rows, create_setting_row(enemy_data.id, nightmare_settings[i], COLUMN_X[2], settings_y))
        end

        settings_y = settings_y + SETTING_ROW_HEIGHT
    end

    return rows, settings_y + GROUP_GAP
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
        create_toggle_row("Enable StrongerEnemies:", StrongerEnemies.CONFIG.enabled, COLUMN_X[1], 66, function()
            StrongerEnemies.CONFIG.enabled = not StrongerEnemies.CONFIG.enabled
            refresh()
        end),
        create_toggle_row("Nightmare Mode (HARD):", StrongerEnemies.CONFIG.nightmare_mode, COLUMN_X[2], 66, function()
            StrongerEnemies.CONFIG.nightmare_mode = not StrongerEnemies.CONFIG.nightmare_mode
            refresh()
        end),
        {
            id = "normal_header",
            type = "label",
            text = "Normal",
            font_size = 22,
            color = "cadetblue",
            position = {COLUMN_X[1], "top + 108"},
            text_align = "left"
        },
        {
            id = "nightmare_header",
            type = "label",
            text = "Nightmare",
            font_size = 22,
            color = "cadetblue",
            position = {COLUMN_X[2], "top + 108"},
            text_align = "left"
        },
        {
            id = "stronger_enemies_instructions",
            type = "label",
            text = "Set how often each enemy tops a cast with something extra. Nightmare sliders have no effect when Nightmare Mode is off.",
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

    local current_y = CONTENT_START_Y

    for _, enemy_data in ipairs(ENEMY_DATA) do
        local rows, next_y = create_enemy_block(enemy_data, current_y)
        current_y = next_y

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
                size = {1000, 820},
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
