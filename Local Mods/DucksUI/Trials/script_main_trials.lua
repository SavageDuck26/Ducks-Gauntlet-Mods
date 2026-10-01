
local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Trials Config menu for the Trials mods"


local MOD_NAME, log_message = Mods.init_mod()

TrialsUI = TrialsUI or {}
TrialsUI.loaded = true

-- Saveable settings (persisted by the DucksUI menu through mod_settings.json). The trial mods read
-- these to decide whether their behaviour is active.
TrialsUI.CONFIG = TrialsUI.CONFIG or {
    deadmanshand = {
        enabled = true,
    },
    peacemonger = {
        enabled = true,
    },
    laziesthero = {
        enabled = true,
        cursed = false,
    },
}

-- The trial mods call this to gate their behaviour. A missing config reads as enabled, so a mod
-- still works if TrialsUI is not loaded.
TrialsUI.is_enabled = function (trial)
    local entry = TrialsUI.CONFIG and TrialsUI.CONFIG[trial]

    if entry and entry.enabled == false then
        return false
    end

    return true
end

TrialsUI.is_cursed = function (trial)
    local entry = TrialsUI.CONFIG and TrialsUI.CONFIG[trial]

    return entry ~= nil and entry.cursed == true
end

-- One entry per trial: the column title and the toggles shown underneath it.
local TRIAL_DATA = {
    {
        id = "deadmanshand",
        name = "DeadMansHand",
        toggles = {
            { key = "enabled", label = "Trial Enabled", default = true },
        },
    },
    {
        id = "peacemonger",
        name = "Peacemonger",
        toggles = {
            { key = "enabled", label = "Trial Enabled", default = true },
        },
    },
    {
        id = "laziesthero",
        name = "TheLaziestHero",
        toggles = {
            { key = "enabled", label = "Trial Enabled", default = true },
            { key = "cursed", label = "Cursed Enabled", default = false },
        },
    },
}

local COLUMN_X = { "left + 60", "left + 340", "left + 620" }
local COLUMN_HEADER_Y = 100
local TOGGLE_START_Y = 145
local TOGGLE_ROW_HEIGHT = 42

local current_widget = nil

-- Rebuilds the panel so a toggled state shows immediately, mirroring the other mod UIs.
local function refresh()
    TrialsUI.hide_config()
    TrialsUI.show_config()
end

-- The per-trial config table, created on demand so a missing section can still be shown.
local function trial_config(trial_id)
    local entry = TrialsUI.CONFIG[trial_id]

    if not entry then
        entry = {}
        TrialsUI.CONFIG[trial_id] = entry
    end

    return entry
end

local function get_toggle_value(trial_id, toggle)
    local entry = trial_config(trial_id)

    if entry[toggle.key] == nil then
        entry[toggle.key] = toggle.default
    end

    return entry[toggle.key]
end

local function create_toggle_row(label_text, checked, x_anchor, y_pos, on_clicked)
    return {
        layout = "horizontal",
        spacing = 10,
        type = "container",
        position = {x_anchor, "top + " .. y_pos},
        children = {
            {
                checked = checked,
                type = "checkbox",
                text = label_text,
                color = "white",
                font_size = 20,
                size = {250, 36},
                on = {
                    clicked = on_clicked
                }
            },
        }
    }
end

local function create_column_children(trial_data, column_index)
    local children = {
        {
            id = trial_data.id .. "_header",
            type = "label",
            text = trial_data.name,
            font_size = 22,
            color = "yellow",
            position = {COLUMN_X[column_index], "top + " .. COLUMN_HEADER_Y},
            text_align = "left"
        },
    }

    local y = TOGGLE_START_Y

    for _, toggle in ipairs(trial_data.toggles) do
        local trial_id = trial_data.id

        table.insert(children, create_toggle_row(toggle.label, get_toggle_value(trial_id, toggle), COLUMN_X[column_index], y, function()
            local entry = trial_config(trial_id)
            entry[toggle.key] = not entry[toggle.key]
            refresh()
        end))

        y = y + TOGGLE_ROW_HEIGHT
    end

    return children
end

local function create_config_ui()
    local children = {
        {
            id = "trials_title",
            type = "label",
            text = "Trials Config",
            font_size = 34,
            color = "white",
            position = {"center", "top + 30"},
            text_align = "center"
        },
    }

    for column_index, trial_data in ipairs(TRIAL_DATA) do
        for _, child in ipairs(create_column_children(trial_data, column_index)) do
            table.insert(children, child)
        end
    end

    table.insert(children, {
        id = "trials_back_button",
        type = "button",
        text = "Back",
        font_size = 24,
        color = "white",
        position = {"center", "bottom - 20"},
        size = {200, 50},
        style = "button_standard",
        on = {
            clicked = function()
                TrialsUI.hide_config()
            end
        }
    })

    return {
        css = "gui/default_css",
        type = "container",
        size = {"100%", "100%"},
        children = {
            -- Semi-transparent background
            {
                alpha = 0.7,
                bg_img = "black",
                id = "trials_overlay_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            -- Main config container
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {900, 400},
                type = "container",
                children = children
            }
        }
    }
end

function TrialsUI.show_config()
    if current_widget then
        return
    end

    current_widget = GUI:load_proto(create_config_ui())
    GUI:add_modal_widget(current_widget, GUI.MAIN_CONTROLLER)
end

function TrialsUI.hide_config()
    if not current_widget then
        return
    end

    GUI:remove_modal_widget(current_widget)
    GUI:destroy_widget(current_widget)
    current_widget = nil
end
