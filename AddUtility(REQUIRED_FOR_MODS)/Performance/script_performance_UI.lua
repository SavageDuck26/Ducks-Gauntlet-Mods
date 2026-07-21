-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Performance UI
-- =================================================================================================

local MOD_NAME = "PerformanceUI"

PerformanceChanges = PerformanceChanges or {}
PerformanceChanges.loaded = true

local current_overlay_widget = nil

-- Default Config Values
local DEFAULT_CONFIG = {
    culling = {
        mode = "default",
        cull_distance = 50,
        uncull_distance = 40,
        enemy_cull_multiplier = 3,
        fraction_per_frame = 0.20
    },
    ai = {
        max_monsters = 300,
        max_spawns_per_frame = 4,
        disable_ai_culling = true
    },
    fps = {
        unlock_fps = false,
        target_fps = 60
    },
    visuals = {
        max_decals = 512,
        decal_fade_time = 1.0,
        emissive_fade_time = 3.0
    },
    gibs = {
        fast_despawn = true,
        despawn_wait_time = 1.0,
        decay_duration = 1.5,
        gib_light_wait = 0.1,
        gib_light_fade = 0.2
    }
}

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

function PerformanceChanges.reset_to_defaults()
    PerformanceChanges.CONFIG = deep_copy(DEFAULT_CONFIG)
end

function PerformanceChanges.load_config()
    if not PerformanceChanges.CONFIG then
        PerformanceChanges.CONFIG = deep_copy(DEFAULT_CONFIG)
    end
end

-- Culling Settings
local CULLING_MODES = {"disabled", "relaxed", "default"}
local CULLING_MODE_INDEX = 2  -- relaxed by default

local function get_culling_mode_index()
    if PerformanceChanges.CONFIG then
        for i, mode in ipairs(CULLING_MODES) do
            if mode == PerformanceChanges.CONFIG.culling.mode then
                return i
            end
        end
    end
    return 2
end

local function get_culling_mode_color(mode)
    local colors = {
        disabled = "red",
        relaxed = "yellow",
        default = "green"
    }
    return colors[mode] or "white"
end

-- Decal Settings
local DECAL_OPTIONS = {128, 256, 512, 1024}
local DECAL_INDEX = 4  -- 1024 by default

local function get_decal_index()
    if PerformanceChanges.CONFIG then
        for i, val in ipairs(DECAL_OPTIONS) do
            if val == PerformanceChanges.CONFIG.visuals.max_decals then
                return i
            end
        end
    end
    return 4
end

-- Update Functions
local function update_culling_radio_buttons()
    if not current_overlay_widget then return end
    
    local radio_ids = {"culling_disabled", "culling_relaxed", "culling_default"}
    local current_index = get_culling_mode_index()
    
    for i, id in ipairs(radio_ids) do
        local widget = current_overlay_widget:get(id)
        if widget then
            widget:set_checked(i == current_index)
        end
    end
end

local function update_decal_radio_buttons()
    if not current_overlay_widget then return end
    
    local radio_ids = {"decal_128", "decal_256", "decal_512", "decal_1024"}
    local current_index = get_decal_index()
    
    for i, id in ipairs(radio_ids) do
        local widget = current_overlay_widget:get(id)
        if widget then
            widget:set_checked(i == current_index)
        end
    end
end

local function update_slider_display(id, value, format)
    if not current_overlay_widget then return end
    local widget = current_overlay_widget:get(id)
    if widget and widget.set_text then
        widget:set_text(string.format(format or "%.1f", value))
    end
end

-- Selection Functions
local function select_culling_mode(index)
    if index >= 1 and index <= #CULLING_MODES then
        CULLING_MODE_INDEX = index
        local mode = CULLING_MODES[index]
        if PerformanceChanges.CONFIG then
            PerformanceChanges.CONFIG.culling.mode = mode
        end
        update_culling_radio_buttons()
        
        if current_overlay_widget then
            local label = current_overlay_widget:get("culling_mode_label")
            if label then
                label:set_text("Mode: " .. mode)
                label:set_color(get_culling_mode_color(mode))
            end
        end
    end
end

local function select_decal_option(index)
    if index >= 1 and index <= #DECAL_OPTIONS then
        DECAL_INDEX = index
        local value = DECAL_OPTIONS[index]
        if PerformanceChanges.CONFIG then
            PerformanceChanges.CONFIG.visuals.max_decals = value
        end
        update_decal_radio_buttons()
    end
end

-- Create UI
local function create_performance_config_ui()
    local cfg = PerformanceChanges.CONFIG or {
        culling = {mode = "relaxed", cull_distance = 50, uncull_distance = 40, enemy_cull_multiplier = 3, fraction_per_frame = 0.20},
        ai = {max_monsters = 300, max_spawns_per_frame = 4, disable_ai_culling = true},
        fps = {unlock_fps = true, target_fps = 120},
        visuals = {max_decals = 1024, decal_fade_time = 1.0, emissive_fade_time = 3.0},
        gibs = {fast_despawn = true, despawn_wait_time = 1.0, decay_duration = 1.5, gib_light_wait = 0.1, gib_light_fade = 0.2}
    }
    
    CULLING_MODE_INDEX = get_culling_mode_index()
    DECAL_INDEX = get_decal_index()
    
    return {
        css = "gui/default_css",
        id = "performance_config_overlay_ui",
        position = "center",
        top_priority = 250,
        type = "container",
        size = {"100%", "100%"},
        children = {
            -- Semi-transparent background
            {
                alpha = 0.8,
                bg_img = "black",
                id = "performance_config_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            -- Main config container
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {1400, 750},
                type = "container",
                children = {
                    -- Title
                    {
                        id = "performance_config_title",
                        type = "label",
                        text = "Performance Config",
                        font_size = 32,
                        color = "cadetblue",
                        position = {"center", "top + 20"},
                        text_align = "center"
                    },
                    
                    -- CULLING SECTION (Left Column)
                    {
                        id = "culling_section_title",
                        type = "label",
                        text = "Culling Settings",
                        font_size = 24,
                        color = "yellow",
                        position = {"left + 50", "top + 70"},
                        text_align = "left"
                    },
                    -- Culling mode radio buttons
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"left + 50", "top + 110"},
                        children = {
                            {
                                checked = (CULLING_MODE_INDEX == 1),
                                id = "culling_disabled",
                                type = "radiobutton",
                                text = "Disabled",
                                size = {110, 40},
                                font_size = 16,
                                on = { clicked = function() select_culling_mode(1) end }
                            },
                            {
                                checked = (CULLING_MODE_INDEX == 2),
                                id = "culling_relaxed",
                                type = "radiobutton",
                                text = "Relaxed",
                                size = {110, 40},
                                font_size = 16,
                                on = { clicked = function() select_culling_mode(2) end }
                            },
                            {
                                checked = (CULLING_MODE_INDEX == 3),
                                id = "culling_default",
                                type = "radiobutton",
                                text = "Default",
                                size = {110, 40},
                                font_size = 16,
                                on = { clicked = function() select_culling_mode(3) end }
                            }
                        }
                    },
                    {
                        id = "culling_mode_label",
                        type = "label",
                        text = "Mode: " .. cfg.culling.mode,
                        font_size = 18,
                        color = get_culling_mode_color(cfg.culling.mode),
                        position = {"left + 50", "top + 160"},
                        text_align = "left"
                    },
                    
                    -- AI SECTION (Middle-Left Column)
                    {
                        id = "ai_section_title",
                        type = "label",
                        text = "AI Settings",
                        font_size = 24,
                        color = "yellow",
                        position = {"left + 400", "top + 70"},
                        text_align = "left"
                    },
                    -- Max Monsters slider
                    {
                        type = "label",
                        text = "Max Monsters:",
                        font_size = 18,
                        color = "white",
                        position = {"left + 400", "top + 110"},
                        text_align = "left"
                    },
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"left + 400", "top + 140"},
                        children = {
                            {
                                id = "ai_max_monsters_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 50,
                                max = 500,
                                value = cfg.ai.max_monsters,
                                size = {200, 40},
                                on = {
                                    changed = function(widget, value)
                                        local rounded = math.floor(value + 0.5)
                                        if PerformanceChanges.CONFIG then
                                            PerformanceChanges.CONFIG.ai.max_monsters = rounded
                                        end
                                        update_slider_display("ai_max_monsters_value", rounded, "%d")
                                    end
                                }
                            },
                            {
                                id = "ai_max_monsters_value",
                                type = "label",
                                text = string.format("%d", cfg.ai.max_monsters),
                                font_size = 18,
                                color = "white",
                                size = {60, 40},
                                text_align = "left"
                            }
                        }
                    },
                    -- Spawns per frame slider
                    {
                        type = "label",
                        text = "Spawns Per Frame:",
                        font_size = 18,
                        color = "white",
                        position = {"left + 400", "top + 190"},
                        text_align = "left"
                    },
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"left + 400", "top + 220"},
                        children = {
                            {
                                id = "ai_spawns_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 1,
                                max = 10,
                                value = cfg.ai.max_spawns_per_frame,
                                size = {200, 40},
                                on = {
                                    changed = function(widget, value)
                                        local rounded = math.floor(value + 0.5)
                                        if PerformanceChanges.CONFIG then
                                            PerformanceChanges.CONFIG.ai.max_spawns_per_frame = rounded
                                        end
                                        update_slider_display("ai_spawns_value", rounded, "%d")
                                    end
                                }
                            },
                            {
                                id = "ai_spawns_value",
                                type = "label",
                                text = string.format("%d", cfg.ai.max_spawns_per_frame),
                                font_size = 18,
                                color = "white",
                                size = {40, 40},
                                text_align = "left"
                            }
                        }
                    },
                    -- Disable AI Culling checkbox
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"left + 400", "top + 270"},
                        children = {
                            {
                                checked = cfg.ai.disable_ai_culling,
                                id = "ai_disable_culling_checkbox",
                                type = "checkbox",
                                size = {25, 25},
                                on = {
                                    clicked = function()
                                        if PerformanceChanges.CONFIG then
                                            PerformanceChanges.CONFIG.ai.disable_ai_culling = not PerformanceChanges.CONFIG.ai.disable_ai_culling
                                        end
                                    end
                                }
                            },
                            {
                                type = "label",
                                text = "Disable AI Culling",
                                font_size = 18,
                                color = "white",
                                size = {150, 25},
                                text_align = "left"
                            }
                        }
                    },
                    
                    -- FPS SECTION (Middle-Right Column)
                    {
                        id = "fps_section_title",
                        type = "label",
                        text = "FPS Settings",
                        font_size = 24,
                        color = "yellow",
                        position = {"left + 750", "top + 70"},
                        text_align = "left"
                    },
                    -- Unlock FPS checkbox
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"left + 750", "top + 110"},
                        children = {
                            {
                                checked = cfg.fps.unlock_fps,
                                id = "fps_unlock_checkbox",
                                type = "checkbox",
                                size = {25, 25},
                                on = {
                                    clicked = function()
                                        if PerformanceChanges.CONFIG then
                                            PerformanceChanges.CONFIG.fps.unlock_fps = not PerformanceChanges.CONFIG.fps.unlock_fps
                                        end
                                    end
                                }
                            },
                            {
                                type = "label",
                                text = "Unlock FPS",
                                font_size = 18,
                                color = "white",
                                size = {120, 25},
                                text_align = "left"
                            }
                        }
                    },
                    -- Target FPS slider
                    {
                        type = "label",
                        text = "Target FPS (when locked):",
                        font_size = 18,
                        color = "white",
                        position = {"left + 750", "top + 150"},
                        text_align = "left"
                    },
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"left + 750", "top + 180"},
                        children = {
                            {
                                id = "fps_target_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 30,
                                max = 300,
                                value = cfg.fps.target_fps,
                                size = {200, 40},
                                on = {
                                    changed = function(widget, value)
                                        local rounded = math.floor(value + 0.5)
                                        if PerformanceChanges.CONFIG then
                                            PerformanceChanges.CONFIG.fps.target_fps = rounded
                                        end
                                        update_slider_display("fps_target_value", rounded, "%d")
                                    end
                                }
                            },
                            {
                                id = "fps_target_value",
                                type = "label",
                                text = string.format("%d", cfg.fps.target_fps),
                                font_size = 18,
                                color = "white",
                                size = {60, 40},
                                text_align = "left"
                            }
                        }
                    },
                    
                    -- VISUALS SECTION (Right Column)
                    {
                        id = "visuals_section_title",
                        type = "label",
                        text = "Visual Settings",
                        font_size = 24,
                        color = "yellow",
                        position = {"left + 1050", "top + 70"},
                        text_align = "left"
                    },
                    -- Max Decals radio buttons
                    {
                        type = "label",
                        text = "Max Decals:",
                        font_size = 18,
                        color = "white",
                        position = {"left + 1050", "top + 110"},
                        text_align = "left"
                    },
                    {
                        layout = "horizontal",
                        spacing = 5,
                        type = "container",
                        position = {"left + 1050", "top + 140"},
                        children = {
                            {
                                checked = (DECAL_INDEX == 1),
                                id = "decal_128",
                                type = "radiobutton",
                                text = "128",
                                size = {70, 35},
                                font_size = 14,
                                on = { clicked = function() select_decal_option(1) end }
                            },
                            {
                                checked = (DECAL_INDEX == 2),
                                id = "decal_256",
                                type = "radiobutton",
                                text = "256",
                                size = {70, 35},
                                font_size = 14,
                                on = { clicked = function() select_decal_option(2) end }
                            },
                            {
                                checked = (DECAL_INDEX == 3),
                                id = "decal_512",
                                type = "radiobutton",
                                text = "512",
                                size = {70, 35},
                                font_size = 14,
                                on = { clicked = function() select_decal_option(3) end }
                            },
                            {
                                checked = (DECAL_INDEX == 4),
                                id = "decal_1024",
                                type = "radiobutton",
                                text = "1024",
                                size = {70, 35},
                                font_size = 14,
                                on = { clicked = function() select_decal_option(4) end }
                            }
                        }
                    },
                    -- Decal Fade Time slider
                    {
                        type = "label",
                        text = "Decal Fade Time:",
                        font_size = 18,
                        color = "white",
                        position = {"left + 1050", "top + 190"},
                        text_align = "left"
                    },
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"left + 1050", "top + 220"},
                        children = {
                            {
                                id = "visuals_decal_fade_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 0.1,
                                max = 5.0,
                                value = cfg.visuals.decal_fade_time,
                                size = {180, 40},
                                on = {
                                    changed = function(widget, value)
                                        local rounded = math.floor(value * 10 + 0.5) / 10
                                        if PerformanceChanges.CONFIG then
                                            PerformanceChanges.CONFIG.visuals.decal_fade_time = rounded
                                        end
                                        update_slider_display("visuals_decal_fade_value", rounded, "%.1fs")
                                    end
                                }
                            },
                            {
                                id = "visuals_decal_fade_value",
                                type = "label",
                                text = string.format("%.1fs", cfg.visuals.decal_fade_time),
                                font_size = 18,
                                color = "white",
                                size = {50, 40},
                                text_align = "left"
                            }
                        }
                    },
                    -- Emissive Fade Time slider
                    {
                        type = "label",
                        text = "Emissive Fade Time:",
                        font_size = 18,
                        color = "white",
                        position = {"left + 1050", "top + 270"},
                        text_align = "left"
                    },
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"left + 1050", "top + 300"},
                        children = {
                            {
                                id = "visuals_emissive_fade_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 0.5,
                                max = 10.0,
                                value = cfg.visuals.emissive_fade_time,
                                size = {180, 40},
                                on = {
                                    changed = function(widget, value)
                                        local rounded = math.floor(value * 10 + 0.5) / 10
                                        if PerformanceChanges.CONFIG then
                                            PerformanceChanges.CONFIG.visuals.emissive_fade_time = rounded
                                        end
                                        update_slider_display("visuals_emissive_fade_value", rounded, "%.1fs")
                                    end
                                }
                            },
                            {
                                id = "visuals_emissive_fade_value",
                                type = "label",
                                text = string.format("%.1fs", cfg.visuals.emissive_fade_time),
                                font_size = 18,
                                color = "white",
                                size = {50, 40},
                                text_align = "left"
                            }
                        }
                    },
                    
                    -- GIBS SECTION (Bottom Section)
                    {
                        id = "gibs_section_title",
                        type = "label",
                        text = "Gibs/Corpse Settings",
                        font_size = 24,
                        color = "yellow",
                        position = {"left + 50", "top + 380"},
                        text_align = "left"
                    },
                    -- Fast Despawn checkbox
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"left + 50", "top + 420"},
                        children = {
                            {
                                checked = cfg.gibs.fast_despawn,
                                id = "gibs_fast_despawn_checkbox",
                                type = "checkbox",
                                size = {25, 25},
                                on = {
                                    clicked = function()
                                        if PerformanceChanges.CONFIG then
                                            PerformanceChanges.CONFIG.gibs.fast_despawn = not PerformanceChanges.CONFIG.gibs.fast_despawn
                                        end
                                    end
                                }
                            },
                            {
                                type = "label",
                                text = "Fast Despawn",
                                font_size = 18,
                                color = "white",
                                size = {130, 25},
                                text_align = "left"
                            }
                        }
                    },
                    -- Despawn Wait Time slider
                    {
                        type = "label",
                        text = "Despawn Wait:",
                        font_size = 18,
                        color = "white",
                        position = {"left + 50", "top + 470"},
                        text_align = "left"
                    },
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"left + 50", "top + 500"},
                        children = {
                            {
                                id = "gibs_despawn_wait_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 0.1,
                                max = 5.0,
                                value = cfg.gibs.despawn_wait_time,
                                size = {180, 40},
                                on = {
                                    changed = function(widget, value)
                                        local rounded = math.floor(value * 10 + 0.5) / 10
                                        if PerformanceChanges.CONFIG then
                                            PerformanceChanges.CONFIG.gibs.despawn_wait_time = rounded
                                        end
                                        update_slider_display("gibs_despawn_wait_value", rounded, "%.1fs")
                                    end
                                }
                            },
                            {
                                id = "gibs_despawn_wait_value",
                                type = "label",
                                text = string.format("%.1fs", cfg.gibs.despawn_wait_time),
                                font_size = 18,
                                color = "white",
                                size = {50, 40},
                                text_align = "left"
                            }
                        }
                    },
                    -- Decay Duration slider
                    {
                        type = "label",
                        text = "Decay Duration:",
                        font_size = 18,
                        color = "white",
                        position = {"left + 50", "top + 550"},
                        text_align = "left"
                    },
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"left + 50", "top + 580"},
                        children = {
                            {
                                id = "gibs_decay_duration_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 0.5,
                                max = 10.0,
                                value = cfg.gibs.decay_duration,
                                size = {180, 40},
                                on = {
                                    changed = function(widget, value)
                                        local rounded = math.floor(value * 10 + 0.5) / 10
                                        if PerformanceChanges.CONFIG then
                                            PerformanceChanges.CONFIG.gibs.decay_duration = rounded
                                        end
                                        update_slider_display("gibs_decay_duration_value", rounded, "%.1fs")
                                    end
                                }
                            },
                            {
                                id = "gibs_decay_duration_value",
                                type = "label",
                                text = string.format("%.1fs", cfg.gibs.decay_duration),
                                font_size = 18,
                                color = "white",
                                size = {50, 40},
                                text_align = "left"
                            }
                        }
                    },
                    -- Gib Light Wait slider
                    {
                        type = "label",
                        text = "Gib Light Wait:",
                        font_size = 18,
                        color = "white",
                        position = {"left + 350", "top + 470"},
                        text_align = "left"
                    },
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"left + 350", "top + 500"},
                        children = {
                            {
                                id = "gibs_light_wait_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 0.01,
                                max = 1.0,
                                value = cfg.gibs.gib_light_wait,
                                size = {180, 40},
                                on = {
                                    changed = function(widget, value)
                                        local rounded = math.floor(value * 100 + 0.5) / 100
                                        if PerformanceChanges.CONFIG then
                                            PerformanceChanges.CONFIG.gibs.gib_light_wait = rounded
                                        end
                                        update_slider_display("gibs_light_wait_value", rounded, "%.2fs")
                                    end
                                }
                            },
                            {
                                id = "gibs_light_wait_value",
                                type = "label",
                                text = string.format("%.2fs", cfg.gibs.gib_light_wait),
                                font_size = 18,
                                color = "white",
                                size = {60, 40},
                                text_align = "left"
                            }
                        }
                    },
                    -- Gib Light Fade slider
                    {
                        type = "label",
                        text = "Gib Light Fade:",
                        font_size = 18,
                        color = "white",
                        position = {"left + 350", "top + 550"},
                        text_align = "left"
                    },
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"left + 350", "top + 580"},
                        children = {
                            {
                                id = "gibs_light_fade_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 0.01,
                                max = 2.0,
                                value = cfg.gibs.gib_light_fade,
                                size = {180, 40},
                                on = {
                                    changed = function(widget, value)
                                        local rounded = math.floor(value * 100 + 0.5) / 100
                                        if PerformanceChanges.CONFIG then
                                            PerformanceChanges.CONFIG.gibs.gib_light_fade = rounded
                                        end
                                        update_slider_display("gibs_light_fade_value", rounded, "%.2fs")
                                    end
                                }
                            },
                            {
                                id = "gibs_light_fade_value",
                                type = "label",
                                text = string.format("%.2fs", cfg.gibs.gib_light_fade),
                                font_size = 18,
                                color = "white",
                                size = {60, 40},
                                text_align = "left"
                            }
                        }
                    },
                    
                    -- INFO TEXT
                    {
                        id = "performance_info",
                        type = "label",
                        text = "Note: Some settings require game restart to take full effect. Settings auto-save on menu exit.",
                        font_size = 16,
                        color = "gray",
                        position = {"center", "bottom - 85"},
                        text_align = "center"
                    },
                    
                    -- Reset to Defaults button
                    {
                        id = "performance_reset_button",
                        type = "button",
                        text = "Reset to Defaults",
                        font_size = 18,
                        color = "orange",
                        position = {"center - 150", "bottom - 30"},
                        size = {200, 50},
                        style = "button_standard",
                        on = {
                            clicked = function()
                                PerformanceChanges.reset_to_defaults()
                                PerformanceChanges.hide_config()
                                PerformanceChanges.show_config()
                            end
                        }
                    },
                    
                    -- Back button
                    {
                        id = "performance_back_button",
                        type = "button",
                        text = "Back",
                        font_size = 20,
                        color = "white",
                        position = {"center + 150", "bottom - 30"},
                        size = {200, 50},
                        style = "button_standard",
                        on = {
                            clicked = function()
                                PerformanceChanges.hide_config()
                            end
                        }
                    }
                }
            }
        }
    }
end

-- Show/Hide Functions
function PerformanceChanges.show_config()
    if current_overlay_widget then
        return
    end
    
    current_overlay_widget = GUI:load_proto(create_performance_config_ui())
    GUI:add_modal_widget(current_overlay_widget, GUI.MAIN_CONTROLLER)
end

function PerformanceChanges.hide_config()
    if not current_overlay_widget then
        return
    end
    
    GUI:remove_modal_widget(current_overlay_widget)
    current_overlay_widget:destroy()
    current_overlay_widget = nil
end


