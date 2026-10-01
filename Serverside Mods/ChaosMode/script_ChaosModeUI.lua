local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Chaos/Hell mode configuration UI"


local MOD_NAME = "ChaosModeConfig"

ChaosMode = ChaosMode or {}

local current_chaos_config_widget = nil

ChaosMode.CONFIG = ChaosMode.CONFIG or {
    mode = "chaos",
    prevent_backtrack_spawns = true,
    controlled_chaos = false,
    controlled_chaos_spawners = 0,
    bosses_enabled = false,
    boss_enabled = {},
    boss_count = {},
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

-- Each sub-boss slider caps how many of that sub-boss a single room can be given.
local BOSS_COUNT_MAX = 10

-- Refresh the live value labels (spawner stones and each sub-boss count).
function ChaosMode.update_config_displays()
    if not current_chaos_config_widget or not current_chaos_config_widget.get then
        return
    end

    local spawners_widget = current_chaos_config_widget:get("controlled_chaos_spawners_value")
    if spawners_widget and spawners_widget.set_text then
        spawners_widget:set_text(tostring(ChaosMode.CONFIG.controlled_chaos_spawners or 0))
    end

    for _, boss in ipairs(ChaosMode.boss_list or {}) do
        local widget = current_chaos_config_widget:get(boss.id .. "_count_value")
        if widget and widget.set_text then
            widget:set_text(tostring(ChaosMode.CONFIG.boss_count[boss.id] or 0))
        end
    end
end

-- One sub-boss row: on/off checkbox, name, and how many of that sub-boss to add per room.
local function create_boss_row(boss, x, y)
    return {
        layout = "horizontal",
        spacing = 8,
        type = "container",
        position = {x, y},
        children = {
            {
                checked = ChaosMode.CONFIG.boss_enabled[boss.id] ~= false,
                id = boss.id .. "_checkbox",
                type = "checkbox",
                size = {30, 30},
                on = {
                    clicked = function()
                        local enabled = ChaosMode.CONFIG.boss_enabled[boss.id] ~= false
                        ChaosMode.CONFIG.boss_enabled[boss.id] = not enabled
                        ChaosMode.hide_config()
                        ChaosMode.show_config()
                    end
                }
            },
            {
                text_align = "left",
                type = "label",
                text = boss.label,
                font_size = 16,
                color = "white",
                size = {150, 30}
            },
            {
                id = boss.id .. "_count_slider",
                type = "slider",
                inherit = "slider",
                min = 0,
                max = BOSS_COUNT_MAX + 0.1,
                value = ChaosMode.CONFIG.boss_count[boss.id] or 0,
                size = {130, 30},
                on = {
                    changed = function(widget, value)
                        ChaosMode.CONFIG.boss_count[boss.id] = math.max(0, math.min(BOSS_COUNT_MAX, math.floor(value + 0.5)))
                        ChaosMode.update_config_displays()
                    end
                }
            },
            {
                id = boss.id .. "_count_value",
                type = "label",
                text = tostring(ChaosMode.CONFIG.boss_count[boss.id] or 0),
                font_size = 16,
                color = "white",
                size = {24, 30}
            }
        }
    }
end

function ChaosMode.show_config()
    if current_chaos_config_widget then
        return
    end
    if not ChaosMode.loaded then
        return -- Base mod not loaded
    end

    local main_children = {
        -- Title
        {
            id = "chaos_config_title",
            type = "label",
            text = "ChaosMode Config",
            font_size = 30,
            color = "white",
            position = {"center", "top + 22"},
            text_align = "center"
        },
        -- Current mode display
        {
            id = "current_mode_label",
            type = "label",
            text = "Active Mode: " .. get_mode_display_name(),
            font_size = 20,
            color = get_mode_color(ChaosMode.CONFIG.mode),
            position = {"center", "top + 58"},
            text_align = "center"
        },
        -- Mode message
        {
            id = "status_message_label",
            type = "label",
            text = get_mode_message(),
            font_size = 18,
            color = get_mode_color(ChaosMode.CONFIG.mode),
            position = {"center", "top + 85"},
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
            position = {"center - 250", "top + 140"},
            size = {300, 46},
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
            position = {"center - 250", "top + 194"},
            size = {300, 46},
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
            position = {"center - 250", "top + 248"},
            size = {300, 46},
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
            position = {"center - 250", "top + 302"},
            size = {300, 46},
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
            id = "difficulty_info_1",
            type = "label",
            text = "Normal: 2k      Chaos: 500k",
            font_size = 16,
            color = "white",
            position = {"center - 250", "top + 368"},
            text_align = "center"
        },
        {
            id = "difficulty_info_2",
            type = "label",
            text = "Hell: 2M / 1M",
            font_size = 16,
            color = get_mode_color("hell"),
            position = {"center - 250", "top + 394"},
            text_align = "center"
        },
        {
            id = "difficulty_info_3",
            type = "label",
            text = "Limbo: 5M credits, plus a special present.",
            font_size = 16,
            color = get_mode_color("limbo"),
            position = {"center - 250", "top + 420"},
            text_align = "center"
        },
        -- Controlled Chaos: stop hallway spawning so the mode stays inside the rooms.
        {
            layout = "horizontal",
            spacing = 10,
            type = "container",
            position = {"center + 190", "top + 140"},
            children = {
                {
                    checked = ChaosMode.CONFIG.controlled_chaos == true,
                    id = "controlled_chaos_checkbox",
                    type = "checkbox",
                    size = {30, 30},
                    on = {
                        clicked = function()
                            ChaosMode.CONFIG.controlled_chaos = not (ChaosMode.CONFIG.controlled_chaos == true)
                            ChaosMode.hide_config()
                            ChaosMode.show_config()
                        end
                    }
                },
                {
                    text_align = "left",
                    type = "label",
                    text = "Controlled Chaos",
                    font_size = 20,
                    color = "yellow",
                    size = {320, 30}
                }
            }
        },
        {
            id = "controlled_chaos_hint",
            type = "label",
            text = "Keeps the chaos inside the rooms; hallways stay as Normal.",
            font_size = 13,
            color = "white",
            position = {"center + 190", "top + 172"},
            text_align = "center"
        },
        -- Spawner stones: extra copies of the spawner stones the level already uses.
        {
            layout = "horizontal",
            spacing = 10,
            type = "container",
            position = {"center + 190", "top + 198"},
            children = {
                {
                    text_align = "left",
                    type = "label",
                    text = "Spawner Stones:",
                    font_size = 18,
                    color = "yellow",
                    size = {170, 34}
                },
                {
                    id = "controlled_chaos_spawners_slider",
                    type = "slider",
                    inherit = "slider",
                    min = 0,
                    max = 10.1,
                    value = ChaosMode.CONFIG.controlled_chaos_spawners or 0,
                    size = {130, 34},
                    on = {
                        changed = function(widget, value)
                            ChaosMode.CONFIG.controlled_chaos_spawners = math.max(0, math.min(10, math.floor(value + 0.5)))
                            ChaosMode.update_config_displays()
                        end
                    }
                },
                {
                    id = "controlled_chaos_spawners_value",
                    type = "label",
                    text = tostring(ChaosMode.CONFIG.controlled_chaos_spawners or 0),
                    font_size = 18,
                    color = "white",
                    size = {30, 34}
                }
            }
        },
        -- Master toggle for the sub-bosses injected into room encounters.
        {
            layout = "horizontal",
            spacing = 10,
            type = "container",
            position = {"center + 190", "top + 238"},
            children = {
                {
                    checked = ChaosMode.CONFIG.bosses_enabled == true,
                    id = "bosses_enabled_checkbox",
                    type = "checkbox",
                    size = {30, 30},
                    on = {
                        clicked = function()
                            ChaosMode.CONFIG.bosses_enabled = not (ChaosMode.CONFIG.bosses_enabled == true)
                            ChaosMode.hide_config()
                            ChaosMode.show_config()
                        end
                    }
                },
                {
                    text_align = "left",
                    type = "label",
                    text = "Sub-Bosses",
                    font_size = 20,
                    color = "yellow",
                    size = {320, 30}
                }
            }
        },
        {
            id = "bosses_hint",
            type = "label",
            text = "Each slider is how many of that sub-boss can appear per room.",
            font_size = 14,
            color = "white",
            position = {"center + 190", "top + 264"},
            text_align = "center"
        },
    }

    -- Sub-boss rows are appended last; positions are absolute so draw order does not matter.
    for i, boss in ipairs(ChaosMode.boss_list or {}) do
        table.insert(main_children, create_boss_row(boss, "center + 190", "top + " .. (294 + (i - 1) * 40)))
    end

    -- Back button
    table.insert(main_children, {
        id = "chaos_back_button",
        type = "button",
        text = "Back",
        font_size = 20,
        color = "white",
        position = {"center", "bottom - 25"},
        size = {200, 45},
        style = "button_standard",
        on = {
            clicked = function()
                ChaosMode.hide_config()
            end
        }
    })

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
                size = {940, 600},
                type = "container",
                children = main_children
            }
        }
    }

    current_chaos_config_widget = GUI:load_proto(chaos_config_ui)
    GUI:add_modal_widget(current_chaos_config_widget, GUI.MAIN_CONTROLLER)
    -- Initialise the value labels to reflect the saved settings.
    ChaosMode.update_config_displays()
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

