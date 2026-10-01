
local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "1.1.0"
local MOD_DESCRIPTION = "Modifies dialogue trigger cooldowns and optional dialogue availability"

local MOD_NAME, log_message = Mods.init_mod()
DialogueFrequency = DialogueFrequency or {}
DialogueFrequency.loaded = true

DialogueFrequency.CONFIG = DialogueFrequency.CONFIG or {
    cooldown_multiplier = 1.0,
    remove_optional_types = false
}

local current_config_widget = nil

local function deep_copy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for k, v in pairs(orig) do
            copy[k] = deep_copy(v)
        end
    else
        copy = orig
    end
    return copy
end

local DEFAULT_CONFIG = {
    cooldown_multiplier = 1.0,
    remove_optional_types = false
}

function DialogueFrequency.reset_to_defaults()
    DialogueFrequency.CONFIG = deep_copy(DEFAULT_CONFIG)
end

function DialogueFrequency.load_config()
    if not DialogueFrequency.CONFIG then
        DialogueFrequency.CONFIG = deep_copy(DEFAULT_CONFIG)
    end
end

local MULTIPLIER_MIN = 0.10
local MULTIPLIER_MAX = 5.00

local function update_multiplier_display()
    if not current_config_widget then return end
    local widget = current_config_widget:get("multiplier_value_label")
    if widget and widget.set_text then
        widget:set_text(string.format("%.2fx", DialogueFrequency.CONFIG.cooldown_multiplier))
    end
end

local function create_config_ui()
    local cfg = DialogueFrequency.CONFIG or deep_copy(DEFAULT_CONFIG)
    
    return {
        css = "gui/default_css",
        id = "dialoguefrequency_config_overlay_ui",
        position = "center",
        top_priority = 250,
        type = "container",
        size = {"100%", "100%"},
        children = {
            {
                alpha = 0.85,
                bg_img = "black",
                id = "dialoguefrequency_config_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {750, 500},
                type = "container",
                children = {
                    -- Title
                    {
                        id = "config_title",
                        type = "label",
                        text = "Dialogue Frequency",
                        font_size = 36,
                        color = "cadetblue",
                        position = {"center", "top + 40"},
                        text_align = "center"
                    },
                    {
                        id = "config_description",
                        type = "label",
                        text = "Adjust how often hero dialogue plays",
                        font_size = 20,
                        color = "white",
                        position = {"center", "top + 85"},
                        text_align = "center"
                    },
                    
                    -- Cooldown Multiplier Section
                    {
                        id = "multiplier_section_title",
                        type = "label",
                        text = "Cooldown Multiplier",
                        font_size = 26,
                        color = "yellow",
                        position = {"center", "top + 150"},
                        text_align = "center"
                    },
                    {
                        id = "multiplier_description",
                        type = "label",
                        text = "Higher values = longer wait between dialogue",
                        font_size = 18,
                        color = "gray",
                        position = {"center", "top + 180"},
                        text_align = "center"
                    },
                    -- Slider with value display
                    {
                        layout = "horizontal",
                        spacing = 25,
                        type = "container",
                        position = {"center", "top + 225"},
                        children = {
                            {
                                id = "multiplier_slider",
                                type = "slider",
                                inherit = "slider",
                                min = MULTIPLIER_MIN,
                                max = MULTIPLIER_MAX,
                                value = cfg.cooldown_multiplier,
                                step = 0.01,
                                size = {400, 50},
                                on = {
                                    changed = function(widget, value)
                                        DialogueFrequency.CONFIG.cooldown_multiplier = value
                                        update_multiplier_display()
                                    end
                                }
                            },
                            {
                                id = "multiplier_value_label",
                                type = "label",
                                text = string.format("%.2fx", cfg.cooldown_multiplier),
                                font_size = 26,
                                color = "white",
                                size = {80, 50},
                                text_align = "center"
                            }
                        }
                    },
                    
                    -- Optional Dialogue Section
                    {
                        id = "optional_section_title",
                        type = "label",
                        text = "Remove Optional Dialogue",
                        font_size = 26,
                        color = "yellow",
                        position = {"center", "top + 310"},
                        text_align = "center"
                    },
                    {
                        id = "optional_description",
                        type = "label",
                        text = "Removes food comments, idle chatter, etc.",
                        font_size = 18,
                        color = "gray",
                        position = {"center", "top + 340"},
                        text_align = "center"
                    },
                    {
                        layout = "horizontal",
                        spacing = 15,
                        type = "container",
                        position = {"center", "top + 380"},
                        children = {
                            {
                                checked = cfg.remove_optional_types,
                                id = "remove_optional_checkbox",
                                type = "checkbox",
                                size = {36, 36},
                                on = {
                                    clicked = function()
                                        if DialogueFrequency.CONFIG then
                                            DialogueFrequency.CONFIG.remove_optional_types = not DialogueFrequency.CONFIG.remove_optional_types
                                        end
                                    end
                                }
                            },
                            {
                                type = "label",
                                text = "Enabled",
                                font_size = 22,
                                color = "white",
                                size = {120, 36},
                                text_align = "left"
                            }
                        }
                    },
                    
                    -- Back Button
                    {
                        id = "back_button",
                        type = "button",
                        text = "Back",
                        font_size = 26,
                        color = "white",
                        position = {"center", "bottom - 20"},
                        size = {220, 55},
                        style = "button_standard",
                        on = {
                            clicked = function()
                                DialogueFrequency.hide_config()
                            end
                        }
                    }
                }
            }
        }
    }
end

function DialogueFrequency.show_config()
    if current_config_widget then
        return
    end
    current_config_widget = GUI:load_proto(create_config_ui())
    GUI:add_modal_widget(current_config_widget, GUI.MAIN_CONTROLLER)
end

function DialogueFrequency.hide_config()
    if not current_config_widget then
        return
    end
    GUI:remove_modal_widget(current_config_widget)
    current_config_widget:destroy()
    current_config_widget = nil
end

local scaled_triggers = {}
local scaled_multiplier = nil

local function get_scaled_trigger(trigger_id, trigger)
    local multiplier = (DialogueFrequency.CONFIG and DialogueFrequency.CONFIG.cooldown_multiplier) or 1

    if scaled_multiplier ~= multiplier then
        scaled_triggers = {}
        scaled_multiplier = multiplier
    end

    local scaled = scaled_triggers[trigger_id]

    if scaled then
        return scaled
    end

    -- Copy rather than edit the loaded settings table: on_script_reload rebuilds it, and a shared
    -- table would end up scaled twice.
    scaled = {}

    for key, value in pairs(trigger) do
        scaled[key] = value
    end

    if scaled.cooldown then
        scaled.cooldown = scaled.cooldown * multiplier
    end

    if scaled.fork_cooldown then
        scaled.fork_cooldown = scaled.fork_cooldown * multiplier
    end

    scaled_triggers[trigger_id] = scaled

    return scaled
end

Mods.hook:set_object_path("VO_Manager", "get_trigger", function(orig, self, trigger_id)
    local trigger = orig(self, trigger_id)

    if not trigger then
        return trigger
    end

    local config = DialogueFrequency.CONFIG

    -- nil reads as "no such trigger" to _can_play and vo_server, which is what removal means here.
    if config and config.remove_optional_types and trigger.type == "optional" then
        return nil
    end

    return get_scaled_trigger(trigger_id, trigger)
end, MOD_NAME .. ".VO_Manager.get_trigger", MOD_NAME)

-- The trigger table is re-required here, so the cached copies are stale.
Mods.hook:set_object_path("VO_Manager", "on_script_reload", function(orig, self, ...)
    orig(self, ...)

    scaled_triggers = {}
    scaled_multiplier = nil
end, MOD_NAME .. ".VO_Manager.on_script_reload", MOD_NAME)
