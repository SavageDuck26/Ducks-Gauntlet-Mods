-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: MeteorStorm mod configuration interface
-- =================================================================================================

local MOD_NAME = "MeteorStormUI"

-- Ensure MeteorStorm namespace exists
MeteorStorm = MeteorStorm or {}

-- Initialize default settings if not already set by main script
MeteorStorm.CONFIG = MeteorStorm.CONFIG or { difficulty = "Medium", friendly_fire = true, enabled = true }

-- MeteorStorm configuration data
local METEORSTORM_SETTINGS = {
    difficulties = {"Easy", "Medium", "Hard", "Impossible", "Hell"},
    current_difficulty_index = 2, -- Medium by default
    friendly_fire = true,
    enabled = true,
    descriptions = {
        Easy = "I'm too young to die! - Half intensity meteors",
        Medium = "Big fan of classics huh? - Normal intensity meteors", 
        Hard = "A little spice can be nice - Double intensity meteors",
        Impossible = "Someone's got a death wish - Quadruple intensity meteors",
        Hell = "I'm a big fan of whatever's wrong with you - Octuple intensity meteors"
    }
}

-- Local variable for current overlay widget
local current_overlay_widget = nil

-- Initialize current settings from MeteorStorm namespace
local current_difficulty = MeteorStorm.CONFIG.difficulty
local current_friendly_fire = MeteorStorm.CONFIG.friendly_fire
local current_enabled = MeteorStorm.CONFIG.enabled
METEORSTORM_SETTINGS.friendly_fire = current_friendly_fire
METEORSTORM_SETTINGS.enabled = current_enabled

-- Find current difficulty index
for i, difficulty in ipairs(METEORSTORM_SETTINGS.difficulties) do
    if difficulty == current_difficulty then
        METEORSTORM_SETTINGS.current_difficulty_index = i
        break
    end
end

-- Get current difficulty setting
local function get_current_meteorstorm_difficulty()
    return METEORSTORM_SETTINGS.difficulties[METEORSTORM_SETTINGS.current_difficulty_index]
end

-- Function to sync from config structure (used when loading from JSON)
function MeteorStorm.load_config()
    -- Update internal METEORSTORM_SETTINGS from MeteorStorm namespace
    METEORSTORM_SETTINGS.friendly_fire = MeteorStorm.CONFIG.friendly_fire
    METEORSTORM_SETTINGS.enabled = (MeteorStorm.CONFIG.enabled == nil) and true or MeteorStorm.CONFIG.enabled
    
    -- Find and set difficulty index
    for i, difficulty in ipairs(METEORSTORM_SETTINGS.difficulties) do
        if difficulty == MeteorStorm.CONFIG.difficulty then
            METEORSTORM_SETTINGS.current_difficulty_index = i
            break
        end
    end
    
    -- Apply the settings
    apply_meteorstorm_setting()
end

-- Legacy alias for backwards compatibility
update_meteorstorm_from_config = MeteorStorm.load_config

-- Apply MeteorStorm settings
function apply_meteorstorm_setting()
    local difficulty = get_current_meteorstorm_difficulty()
    local friendly_fire = METEORSTORM_SETTINGS.friendly_fire
    local enabled = METEORSTORM_SETTINGS.enabled
        
    -- Update MeteorStorm namespace
    MeteorStorm.CONFIG.difficulty = difficulty
    MeteorStorm.CONFIG.friendly_fire = friendly_fire
    MeteorStorm.CONFIG.enabled = enabled
end

-- Handle enabled toggle with auto-apply
function toggle_meteorstorm_enabled()
    METEORSTORM_SETTINGS.enabled = not METEORSTORM_SETTINGS.enabled
    
    -- Auto-apply the setting immediately
    apply_meteorstorm_setting()
    
    -- Update checkbox display
    if current_overlay_widget then
        local checkbox_widget = current_overlay_widget:get("enabled_checkbox")
        if checkbox_widget then
            checkbox_widget:set_checked(METEORSTORM_SETTINGS.enabled)
        end
    end
end

-- Handle difficulty selection with auto-apply
function select_meteorstorm_difficulty(index)
    if index >= 1 and index <= #METEORSTORM_SETTINGS.difficulties then
        METEORSTORM_SETTINGS.current_difficulty_index = index
        local new_difficulty = get_current_meteorstorm_difficulty()
        
        -- Auto-apply the setting immediately
        apply_meteorstorm_setting()
        
        -- Update the radio buttons visual state
        update_meteorstorm_radio_buttons()
        
        -- Update description display
        if current_overlay_widget then
            local description_widget = current_overlay_widget:get("meteorstorm_description")
            if description_widget then
                description_widget:set_text(METEORSTORM_SETTINGS.descriptions[new_difficulty])
            end
        end
    end
end

-- Function to update radio button appearance
function update_meteorstorm_radio_buttons()
    if not current_overlay_widget then
        return
    end
    
    -- Update radiobutton states
    local radiobutton_ids = {"meteorstorm_easy", "meteorstorm_medium", "meteorstorm_hard", "meteorstorm_impossible", "meteorstorm_hell"}
    
    for i, id in ipairs(radiobutton_ids) do
        local widget = current_overlay_widget:get(id)
        if widget then
            widget:set_checked(i == METEORSTORM_SETTINGS.current_difficulty_index)
        end
    end
end

-- Handle friendly fire toggle with auto-apply
function toggle_meteorstorm_friendly_fire()
    METEORSTORM_SETTINGS.friendly_fire = not METEORSTORM_SETTINGS.friendly_fire
    
    -- Auto-apply the setting immediately
    apply_meteorstorm_setting()
    
    -- Update checkbox display
    if current_overlay_widget then
        local checkbox_widget = current_overlay_widget:get("friendly_fire_checkbox")
        if checkbox_widget then
            checkbox_widget:set_checked(METEORSTORM_SETTINGS.friendly_fire)
        end
    end
end

-- Function to create MeteorStorm config overlay UI definition
local function create_meteorstorm_config_overlay_ui()
    return {
        css = "gui/default_css",
        id = "meteorstorm_config_overlay_ui",
        position = "center",
        top_priority = 250,
        type = "container",
        size = {"100%", "100%"},
        children = {
            -- Semi-transparent background
            {
                alpha = 0.8,
                bg_img = "black",
                id = "meteorstorm_config_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            -- Main config container
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {720, 400},
                type = "container",
                children = {
                    -- Enabled checkbox (top left)
                    {
                        layout = "horizontal",
                        spacing = 8,
                        type = "container",
                        position = {"left + 20", "top + 20"},
                        children = {
                            {
                                checked = METEORSTORM_SETTINGS.enabled,
                                id = "enabled_checkbox",
                                type = "checkbox",
                                text = "Enabled",
                                size = {120, 40},
                                font_size = 18,
                                on = {
                                    clicked = function()
                                        toggle_meteorstorm_enabled()
                                    end
                                }
                            }
                        }
                    },
                    -- Title
                    {
                        id = "meteorstorm_config_title",
                        type = "label",
                        text = "MeteorStorm Config",
                        font_size = 32,
                        color = "white",
                        position = {"center", "top + 30"},
                        text_align = "center"
                    },
                    -- Instructions
                    {
                        id = "meteorstorm_instructions",
                        type = "label",
                        text = "Select meteor storm difficulty:",
                        font_size = 20,
                        color = "white",
                        position = {"center", "top + 80"},
                        text_align = "center"
                    },
                    -- Difficulty radio button group
                    {
                        layout = "horizontal",
                        spacing = 12,
                        type = "container",
                        position = {"center", "top + 130"},
                        children = {
                            {
                                text_align = "left",
                                type = "label",
                                text = "Difficulty:",
                                font_size = 20,
                                color = "white",
                                size = {80, 50}
                            },
                            {
                                checked = (METEORSTORM_SETTINGS.current_difficulty_index == 1),
                                id = "meteorstorm_easy",
                                type = "radiobutton",
                                text = "Easy",
                                size = {90, 50},
                                font_size = 18,
                                on = {
                                    clicked = function()
                                        select_meteorstorm_difficulty(1)
                                    end
                                }
                            },
                            {
                                checked = (METEORSTORM_SETTINGS.current_difficulty_index == 2),
                                id = "meteorstorm_medium",
                                type = "radiobutton", 
                                text = "Medium",
                                size = {100, 50},
                                font_size = 18,
                                on = {
                                    clicked = function()
                                        select_meteorstorm_difficulty(2)
                                    end
                                }
                            },
                            {
                                checked = (METEORSTORM_SETTINGS.current_difficulty_index == 3),
                                id = "meteorstorm_hard",
                                type = "radiobutton",
                                text = "Hard",
                                size = {90, 50},
                                font_size = 18,
                                on = {
                                    clicked = function()
                                        select_meteorstorm_difficulty(3)
                                    end
                                }
                            },
                            {
                                checked = (METEORSTORM_SETTINGS.current_difficulty_index == 4),
                                id = "meteorstorm_impossible",
                                type = "radiobutton",
                                text = "Impossible",
                                size = {120, 50},
                                font_size = 18,
                                on = {
                                    clicked = function()
                                        select_meteorstorm_difficulty(4)
                                    end
                                }
                            },
                            {
                                checked = (METEORSTORM_SETTINGS.current_difficulty_index == 5),
                                id = "meteorstorm_hell",
                                type = "radiobutton",
                                text = "Hell",
                                size = {85, 50},
                                font_size = 18,
                                on = {
                                    clicked = function()
                                        select_meteorstorm_difficulty(5)
                                    end
                                }
                            }
                        }
                    },
                    -- Friendly Fire checkbox (compact layout)
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"center", "top + 240"},
                        children = {
                            {
                                text_align = "left",
                                type = "label",
                                text = "Friendly Fire:",
                                font_size = 18,
                                color = "white",
                                size = {120, 40}
                            },
                            {
                                checked = METEORSTORM_SETTINGS.friendly_fire,
                                id = "friendly_fire_checkbox",
                                type = "checkbox",
                                text = "Enabled",
                                size = {100, 40},
                                font_size = 16,
                                on = {
                                    clicked = function()
                                        toggle_meteorstorm_friendly_fire()
                                    end
                                }
                            }
                        }
                    },
                    -- Description text
                    {
                        id = "meteorstorm_description",
                        type = "label",
                        text = METEORSTORM_SETTINGS.descriptions[get_current_meteorstorm_difficulty()],
                        font_size = 22,
                        color = "white",
                        position = {"center", "top + 200"},
                        text_align = "center"
                    },
                    -- Back button
                    {
                        id = "meteorstorm_config_back_button",
                        type = "button",
                        text = "Back",
                        font_size = 20,
                        color = "white",
                        position = {"center", "top + 300"},
                        size = {180, 50},
                        style = "button_standard",
                        on = {
                            clicked = function()
                                MeteorStorm.hide_config()
                            end
                        }
                    }
                }
            }
        }
    }
end

-- Function to show the MeteorStorm config overlay
function MeteorStorm.show_config()
    if current_overlay_widget then
        return -- Already showing
    end
    if not MeteorStorm.loaded then
        return
    end
    
    current_overlay_widget = GUI:load_proto(create_meteorstorm_config_overlay_ui())
    
    GUI:add_modal_widget(current_overlay_widget, GUI.MAIN_CONTROLLER)
end

function MeteorStorm.hide_config()
    if not current_overlay_widget then
        return -- Nothing to hide
    end
        
    GUI:remove_modal_widget(current_overlay_widget)
    
    current_overlay_widget:destroy()
    current_overlay_widget = nil
end

apply_meteorstorm_setting()
