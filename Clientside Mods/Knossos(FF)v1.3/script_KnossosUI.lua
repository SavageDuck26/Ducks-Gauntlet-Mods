-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Knossos mod configuration interface
-- =================================================================================================

local MOD_NAME = "KnossosUI"

Knossos = Knossos or {}
Knossos.loaded = true

Knossos.CONFIG = Knossos.CONFIG or {}

Knossos.CONFIG.enabled = (Knossos.CONFIG.enabled == nil) and true or Knossos.CONFIG.enabled
Knossos.CONFIG.mode = Knossos.CONFIG.mode or "Small"

local KNOSSOS_SETTINGS = {
    modes = {"Small", "Medium", "Large", "Massive", "Labyrinth"},
    current_mode_index = 1, -- Small by default
    descriptions = {
        Small = "Minimal branching.",
        Medium = "Balanced branching.",
        Large = "Expanded recursive branching.",
        Massive = "Extensive recursive branching. Randomized exit.",
        Labyrinth = "Unbarred maze-like recursive branching. Randomized exit."
    }
}

local current_overlay_widget = nil

local current_mode = Knossos.CONFIG.mode

for i, mode in ipairs(KNOSSOS_SETTINGS.modes) do
    if mode == current_mode then
        KNOSSOS_SETTINGS.current_mode_index = i
        break
    end
end

local function get_current_knossos_mode()
    return KNOSSOS_SETTINGS.modes[KNOSSOS_SETTINGS.current_mode_index]
end

local function get_mode_color(mode)
    local colors = {
        Small = "green",
        Medium = "yellow",
        Large = "orange",
        Massive = "red",
        Labyrinth = "purple"
    }
    return colors[mode] or "white"
end

function update_knossos_from_config()
    -- Find and set mode index
    for i, mode in ipairs(KNOSSOS_SETTINGS.modes) do
        if mode == Knossos.CONFIG.mode then
            KNOSSOS_SETTINGS.current_mode_index = i
            break
        end
    end
    
    apply_knossos_setting()
end

function apply_knossos_setting()
    local mode = get_current_knossos_mode()
    
    Knossos.CONFIG.mode = mode
    
    Knossos.is_enabled = Knossos.CONFIG.enabled
end

function select_knossos_mode(index)
    if index >= 1 and index <= #KNOSSOS_SETTINGS.modes then
        KNOSSOS_SETTINGS.current_mode_index = index
        local new_mode = get_current_knossos_mode()
        
        apply_knossos_setting()
        
        update_knossos_radio_buttons()
        
        if current_overlay_widget then
            local description_widget = current_overlay_widget:get("knossos_description")
            if description_widget then
                description_widget:set_text(KNOSSOS_SETTINGS.descriptions[new_mode])
            end
            
            local mode_label = current_overlay_widget:get("current_mode_label")
            if mode_label then
                mode_label:set_text("Active Mode: " .. new_mode)
                mode_label:set_color(get_mode_color(new_mode))
            end
        end
    end
end

function update_knossos_radio_buttons()
    if not current_overlay_widget then
        return
    end
    
    local radiobutton_ids = {"knossos_small", "knossos_medium", "knossos_large", "knossos_massive", "knossos_labyrinth"}
    
    for i, id in ipairs(radiobutton_ids) do
        local widget = current_overlay_widget:get(id)
        if widget then
            widget:set_checked(i == KNOSSOS_SETTINGS.current_mode_index)
        end
    end
end

function toggle_knossos_enabled()
    Knossos.CONFIG.enabled = not Knossos.CONFIG.enabled
    
    apply_knossos_setting()
    
    if current_overlay_widget then
        local checkbox_widget = current_overlay_widget:get("knossos_enabled_checkbox")
        if checkbox_widget then
            checkbox_widget:set_checked(Knossos.CONFIG.enabled)
        end
    end
end

local function create_knossos_config_overlay_ui()
    return {
        css = "gui/default_css",
        id = "knossos_config_overlay_ui",
        position = "center",
        top_priority = 250,
        type = "container",
        size = {"100%", "100%"},
        children = {
            -- Semi-transparent background
            {
                alpha = 0.8,
                bg_img = "black",
                id = "knossos_config_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            -- Main config container
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {750, 400},
                type = "container",
                children = {
                    -- Title
                    {
                        id = "knossos_config_title",
                        type = "label",
                        text = "Knossos Config",
                        font_size = 32,
                        color = "white",
                        position = {"center", "top + 30"},
                        text_align = "center"
                    },
                    -- Enabled checkbox (top middle)
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"center", "top + 75"},
                        children = {
                            {
                                checked = Knossos.CONFIG.enabled,
                                id = "knossos_enabled_checkbox",
                                type = "checkbox",
                                text = "Enabled",
                                size = {120, 40},
                                font_size = 20,
                                on = {
                                    clicked = function()
                                        toggle_knossos_enabled()
                                    end
                                }
                            }
                        }
                    },
                    -- Instructions
                    {
                        id = "knossos_instructions",
                        type = "label",
                        text = "Select dungeon generation mode:",
                        font_size = 20,
                        color = "white",
                        position = {"center", "top + 130"},
                        text_align = "center"
                    },
                    -- Mode radio button group
                    {
                        layout = "horizontal",
                        spacing = 12,
                        type = "container",
                        position = {"center", "top + 175"},
                        children = {
                            {
                                checked = (KNOSSOS_SETTINGS.current_mode_index == 1),
                                id = "knossos_small",
                                type = "radiobutton",
                                text = "Small",
                                size = {100, 50},
                                font_size = 18,
                                on = {
                                    clicked = function()
                                        select_knossos_mode(1)
                                    end
                                }
                            },
                            {
                                checked = (KNOSSOS_SETTINGS.current_mode_index == 2),
                                id = "knossos_medium",
                                type = "radiobutton", 
                                text = "Medium",
                                size = {110, 50},
                                font_size = 18,
                                on = {
                                    clicked = function()
                                        select_knossos_mode(2)
                                    end
                                }
                            },
                            {
                                checked = (KNOSSOS_SETTINGS.current_mode_index == 3),
                                id = "knossos_large",
                                type = "radiobutton",
                                text = "Large",
                                size = {100, 50},
                                font_size = 18,
                                on = {
                                    clicked = function()
                                        select_knossos_mode(3)
                                    end
                                }
                            },
                            {
                                checked = (KNOSSOS_SETTINGS.current_mode_index == 4),
                                id = "knossos_massive",
                                type = "radiobutton",
                                text = "Massive",
                                size = {110, 50},
                                font_size = 18,
                                on = {
                                    clicked = function()
                                        select_knossos_mode(4)
                                    end
                                }
                            },
                            {
                                checked = (KNOSSOS_SETTINGS.current_mode_index == 5),
                                id = "knossos_labyrinth",
                                type = "radiobutton",
                                text = "Labyrinth",
                                size = {120, 50},
                                font_size = 18,
                                on = {
                                    clicked = function()
                                        select_knossos_mode(5)
                                    end
                                }
                            }
                        }
                    },
                    -- Current mode display
                    {
                        id = "current_mode_label",
                        type = "label",
                        text = "Active Mode: " .. get_current_knossos_mode(),
                        font_size = 22,
                        color = get_mode_color(get_current_knossos_mode()),
                        position = {"center", "top + 240"},
                        text_align = "center"
                    },
                    -- Description text
                    {
                        id = "knossos_description",
                        type = "label",
                        text = KNOSSOS_SETTINGS.descriptions[get_current_knossos_mode()],
                        font_size = 22,
                        color = "white",
                        position = {"center", "top + 280"},
                        text_align = "center"
                    },
                    -- Back button
                    {
                        id = "knossos_config_back_button",
                        type = "button",
                        text = "Back",
                        font_size = 20,
                        color = "white",
                        position = {"center", "top + 340"},
                        size = {180, 50},
                        style = "button_standard",
                        on = {
                            clicked = function()
                                Knossos.hide_config()
                            end
                        }
                    }
                }
            }
        }
    }
end

function Knossos.show_config()
    if current_overlay_widget then
        return -- Already showing
    end
    if not Knossos.loaded then
        return
    end
    
    current_overlay_widget = GUI:load_proto(create_knossos_config_overlay_ui())
    
    GUI:add_modal_widget(current_overlay_widget, GUI.MAIN_CONTROLLER)
end

function Knossos.hide_config()
    if not current_overlay_widget then
        return
    end
        
    GUI:remove_modal_widget(current_overlay_widget)
    
    current_overlay_widget:destroy()
    current_overlay_widget = nil
end

function Knossos.load_config()
    update_knossos_from_config()
end

apply_knossos_setting()

