
local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "3.6.0"
local MOD_DESCRIPTION = "Main mod menu overlay system"


local MOD_NAME, log_message = Mods.init_mod()
-- Initialize DucksUI global namespace
DucksUI = DucksUI or {}
DucksUI.loaded = true

-- Resolve a mod callback given as a (possibly dotted) global function name.
local function resolve_callback(func_name)
    if type(func_name) ~= "string" or func_name == "" then
        return nil
    end

    -- Accept both "Namespace.show_config" and "Namespace.show_config()".
    func_name = func_name:gsub("%s*%(%s*%)%s*$", "")

    local current = _G
    for part in string.gmatch(func_name, "[^.]+") do
        if type(current) ~= "table" then
            return nil
        end
        current = rawget(current, part)
        if current == nil then
            return nil
        end
    end

    if type(current) == "function" then
        return current
    end
    return nil
end


-- Back-button compatibility. In the menu input map the pad's circle button and the keyboard's Esc
-- both arrive as the input named "back", so one handler covers both.
local function set_back_handler(widget, go_back)
    local function handle()
        go_back()
        return true
    end

    for _, input_name in ipairs({"back", "cancel"}) do
        widget:set_on_pressed(input_name, handle)
        -- Storing the handler is not enough: the GUI registers them when a modal is added, and a
        -- nested menu was added by the mod that owns it before we got here. Register it ourselves.
        -- Registering twice is harmless; the GUI keeps widgets in a set.
        GUI:register_on_pressed(widget, input_name)
    end
end

-- The top of the GUI's modal stack: whatever the player is looking at.
local function top_modal()
    local top = nil
    for _, widget in GUI:modal_widget_iterator() do
        top = widget
    end
    return top
end

-- The config menus opened from the main overlay belong to other mods, so DucksUI closes them the
-- way it opened them: through the mod's own function. Every mod pairs show_X with hide_X, and
-- calling hide_X is what clears its "already open" state -- taking the widget off the stack from
-- here would leave that panel impossible to reopen.
local open_panel_hide = nil

local function close_open_panel()
    if not open_panel_hide then
        return false
    end

    local hide = open_panel_hide
    open_panel_hide = nil
    hide()

    return true
end

-- "Alliances.show_config" -> "Alliances.hide_config"
local function hide_name_of(callback_name)
    if type(callback_name) ~= "string" then
        return nil
    end

    return (callback_name:gsub("show", "hide", 1))
end


-- List of mod namespaces whose CONFIG is a player setting and should round-trip through
-- mod_settings.json. A namespace left out is silently neither saved nor applied, and a name that
-- matches no global does nothing, so this list has to be kept honest. Deliberately absent: the
-- Performance*, PerformanceCulling and PerformancePause tunables, Duckmode's RenderDistance and
-- CustomColosseums -- runtime knobs, a dev switch and a per-session level choice, not saved settings.
local REGISTERED_MODS = {
    "Alliances",
    "Berserkers",
    "ChaosMode",
    "ColosseumStones",
    "DialogueFrequency",
    "GraveTrappers",
    "Knossos",
    "MeteorStorm",
    "MoreCrowns",
    "RandomUrns",
    "StrongerEnemies",
    "Summoners",
    "TrialsUI",
}

-- Each mod's CONFIG as it shipped, captured by the first import before any saved value is merged
-- in. The Default preset restores these. Captured lazily because the mods load after DucksUI and a
-- mod's CONFIG does not exist until its own script has run.
local mod_defaults = {}

local current_overlay_widget = nil

-- Some of those panels rebuild themselves when a checkbox is clicked: the mod hides its widget and
-- shows a fresh one, so a handler attached to the old widget dies with it. Watching for panels being
-- added, rather than attaching once, means a rebuilt panel gets the handler too. Sliders only change
-- values, which is why they were never affected.
Mods.hook:set_object_path("GUI", "add_modal_widget",
    function (orig, self, widget, user_name)
        local result = orig(self, widget, user_name)

        if open_panel_hide and widget ~= current_overlay_widget then
            set_back_handler(widget, close_open_panel)
        end

        return result
    end, MOD_NAME .. ".GUI.add_modal_widget", MOD_NAME)


-- Check if a mod's show_config is available by safely checking the global
local function is_mod_config_available(global_name, func_name)
    local mod_table = rawget(_G, global_name)
    if not mod_table then return false end
    if func_name and type(mod_table) == "table" then
        return type(mod_table[func_name]) == "function"
    end
    -- For direct global functions (e.g. show_endlessshop_config)
    return type(mod_table) == "function"
end

local function create_duck_overlay_ui()
    local all_buttons_config = {
        {id = "alliances_config", text = "Alliances Config", callback = "Alliances.show_config()", global = "Alliances", func = "show_config"},
        {id = "berserkers_config", text = "Berserkers Config", callback = "Berserkers.show_config()", global = "Berserkers", func = "show_config"},
        {id = "chaosmode_config", text = "ChaosMode Config", callback = "ChaosMode.show_config()", global = "ChaosMode", func = "show_config"},
        {id = "colosseum_stones_config", text = "ColosseumStones Config", callback = "ColosseumStones.show_config()", global = "ColosseumStones", func = "show_config"},
        {id = "dialogue_freq_config", text = "DialogueFrequency Config", callback = "DialogueFrequency.show_config()", global = "DialogueFrequency", func = "show_config"},
        {id = "endless_shop_config", text = "EndlessShop Config", callback = "_G.show_endlessshop_config", global = "show_endlessshop_config", func = nil},
        {id = "gravetrappers_config", text = "GraveTrappers Config", callback = "GraveTrappers.show_config()", global = "GraveTrappers", func = "show_config"},
        {id = "knossos_config", text = "Knossos Config", callback = "Knossos.show_config()", global = "Knossos", func = "show_config"},
        {id = "meteor_storm_config", text = "MeteorStorm Config", callback = "MeteorStorm.show_config()", global = "MeteorStorm", func = "show_config"},
        {id = "more_crowns_config", text = "MoreCrowns Config", callback = "MoreCrowns.show_config()", global = "MoreCrowns", func = "show_config"},
        {id = "performance_config", text = "Performance Config", callback = "PerformanceChanges.show_config()", global = "PerformanceChanges", func = "show_config"},
        {id = "randomurns_config", text = "RandomUrns Config", callback = "RandomUrns.show_config()", global = "RandomUrns", func = "show_config"},
        {id = "stronger_enemies_config", text = "StrongerEnemies Config", callback = "StrongerEnemies.show_config()", global = "StrongerEnemies", func = "show_config"},
        {id = "summoners_config", text = "Summoners Config", callback = "Summoners.show_config()", global = "Summoners", func = "show_config"},
        {id = "trials_config", text = "Trials Config", callback = "TrialsUI.show_config()", global = "TrialsUI", func = "show_config"},
    }
    
    -- Filter to only include buttons whose mod is actually loaded
    local buttons_config = {}
    for _, btn in ipairs(all_buttons_config) do
        if is_mod_config_available(btn.global, btn.func) then
            table.insert(buttons_config, btn)
        end
    end
    
    local buttons_per_row = 4
    local button_width = 300
    local button_height = 60
    local horizontal_spacing = 20
    local vertical_spacing = 15
    local start_y = 120
    
    -- Calculate total width needed for centering
    local total_row_width = (button_width * buttons_per_row) + (horizontal_spacing * (buttons_per_row - 1))
    local start_x = -total_row_width / 2 + button_width / 2
    
    local button_children = {}
    
    for i, btn_config in ipairs(buttons_config) do
        local row = math.floor((i - 1) / buttons_per_row)
        local col = (i - 1) % buttons_per_row
        
        local x_pos = start_x + (col * (button_width + horizontal_spacing))
        local y_pos = start_y + (row * (button_height + vertical_spacing))
        
        table.insert(button_children, {
            id = btn_config.id,
            type = "button",
            text = btn_config.text,
            font_size = 22,
            color = "white",
            position = {"center + " .. x_pos, "top + " .. y_pos},
            size = {button_width, button_height},
            style = "button_standard",
            on = {
                clicked = function()
                    local func_name = btn_config.callback
                    local func = func_name and resolve_callback(func_name)
                    if func then
                        open_panel_hide = resolve_callback(hide_name_of(func_name))
                        local ok2, result = pcall(func)
                        if ok2 and type(result) == "function" then
                            pcall(result)
                        end
                        -- Whatever that mod just put on screen is now on top of our overlay, so
                        -- give it the same back handling. Where a mod has no hide_X to pair with,
                        -- there is nothing to call, and its own Back button stays the way out.
                        if open_panel_hide then
                            local panel = top_modal()
                            if panel and panel ~= current_overlay_widget then
                                set_back_handler(panel, close_open_panel)
                            end
                        end
                    end
                end
            }
        })
    end
    
    -- Build the complete children array
    local main_children = {
        -- Title
        {
            id = "overlay_title",
            type = "label",
            text = "Duck's Mods Menu",
            font_size = 36,
            color = "cadetblue",
            position = {"center", "top + 30"},
            text_align = "center"
        }
    }
    
    -- Add all button children
    for _, btn in ipairs(button_children) do
        table.insert(main_children, btn)
    end
    
    -- Add back button
    table.insert(main_children, {
        id = "back_button",
        type = "button",
        text = "Back",
        font_size = 24,
        color = "white",
        position = {"center", "bottom - 30"},
        size = {200, 50},
        style = "button_standard",
        on = {
            clicked = function()
                hide_duck_overlay()
            end
        }
    })
    table.insert(main_children, {
        id = "mod_presets",
        type = "button",
        text = "Presets",
        font_size = 26,
        color = "cadetblue",
        position = {"top + 20", "left + 20"},
        size = {225, 60},
        style = "button_standard",
        on = {
            clicked = function()
                show_presets_overlay()
            end
        }
    })
    -- Description
    table.insert(main_children, {
        id = "description",
        type = "label",
        text = "SavageDuck26's Mod Configs. Settings Auto-save on menu exit. Other Configs in progress...",
        font_size = 24,
        color = "cadetblue",
        position = {"center", "top + 80"},
        text_align = "center",
    })
    table.insert(main_children, {
        id = "description_funny",
        type = "label",
        text = "No ducks were harmed in the making of this menu. If you have requests, ideas, or concerns, shoot me a message.",
        font_size = 24,
        color = "cadetblue",
        position = {"center", "bottom - 90"},
        text_align = "center",
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
                id = "overlay_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            -- Main overlay container
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {1400, 700},
                type = "container",
                children = main_children
            }
        }
    }
end

-- Function to show the overlay
function show_duck_overlay()
    if current_overlay_widget then
        return -- Already showing
    end
    if DucksUI.import_all_settings then
        pcall(DucksUI.import_all_settings)
    end
    current_overlay_widget = GUI:load_proto(create_duck_overlay_ui())
    set_back_handler(current_overlay_widget, hide_duck_overlay)
    
    GUI:add_modal_widget(current_overlay_widget, GUI.MAIN_CONTROLLER)    
end

function hide_duck_overlay()
    if not current_overlay_widget then
        return
    end

    if DucksUI.save_all_settings then
        pcall(DucksUI.save_all_settings)
    end

    -- Let every mod re-derive whatever it builds from CONFIG. load_config() only runs inside the
    -- import, and the import only happens when the panel opens, so a mod that rebuilds from CONFIG
    -- (Alliances' pools, MeteorStorm's spawning) otherwise kept the settings it read before the
    -- player changed them. Values are not re-read from the file here on purpose: the widgets wrote
    -- them straight into CONFIG, and merging the saved snapshot back would clobber anything a mod
    -- set at runtime.
    for _, name in ipairs(REGISTERED_MODS) do
        local mod = rawget(_G, name)

        if type(mod) == "table" and type(mod.load_config) == "function" then
            pcall(mod.load_config)
        end
    end

    open_panel_hide = nil

    GUI:remove_modal_widget(current_overlay_widget)
    
    GUI:destroy_widget(current_overlay_widget)
    current_overlay_widget = nil
end

Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "foundation/lua/util/json" then
        if DucksUI.import_all_settings then
            pcall(DucksUI.import_all_settings)
        end
    end

    if path == "lua/menu/screen_main_menu" then

        if DucksUI.import_all_settings then
            pcall(DucksUI.import_all_settings)
        end

        Mods.hook:set_object_path("ScreenMainMenu", "rebuild_ui", function (orig, self)            
            orig(self)
            
            local duck_button = {
                id = "ducks_mods_menu",
                style = "title_large",
                type = "button",
                text = "Ducks Mods",
                color = "cadetblue",
                font_size = 64,
                on = {
                    selected = function ()
                        self:show_tooltip("Ducks Mod Menu UI")
                    end,
                    clicked = function ()
                        show_duck_overlay()
                    end,
                },
            }
            
            local custom_duck_widget = GUI:load_proto(duck_button)
            self.widget:get("buttons"):add_child(custom_duck_widget)
        end, MOD_NAME .. ".ScreenMainMenu.rebuild_ui", MOD_NAME)
    end

    -- add a lobby button when the lobby screen is required
    if path == "lua/menu/screen_lobby" then
        Mods.hook:set_object_path("ScreenLobby", "rebuild_ui", function(orig, self, user_name)
            orig(self, user_name)

            local widget = self.widget
            if widget then
                local duck_button = {
                    id = "ducks_mods_menu_lobby",
                    style = "button_standard",
                    type = "button",
                    text = "Ducks Mods",
                    color = "cadetblue",
                    font_size = 36,
                    position = {"left + 20", "bottom - 20"},
                    on = {
                        selected = function()
                            -- Nothing, no tooltips here.
                        end,
                        clicked = function()
                            show_duck_overlay()
                        end,
                    },
                }

                local custom_duck_widget = GUI:load_proto(duck_button)
                local host_btn = widget:get("host_options_button")

                if host_btn then
                    local parent = host_btn:get_parent()
                    if parent then
                        parent:add_child(custom_duck_widget)
                    else
                        widget:add_child(custom_duck_widget)
                    end
                else
                    widget:add_child(custom_duck_widget)
                end
            end
        end, MOD_NAME .. ".ScreenLobby.rebuild_ui", MOD_NAME)
    end


    return result
end, MOD_NAME .. ".require", MOD_NAME)

-- Path of the settings file the shared framework persists mod settings into.
-- moddata.save_mod_settings_to_file writes <mods root>/settings/mod_settings.json, and
-- DucksUI keeps its data under the "DucksUI" key of that file. There is no separate
-- per-mod settings file.
local function settings_file_path()
    local mods_dir = rawget(_G, "DLL_MOD_DIRECTORY_PATH")
    if mods_dir then
        return mods_dir .. "/settings/mod_settings.json"
    end
    return "<mods root>/settings/mod_settings.json"
end


-- Helper function to round floats to hundredths place
local function round_floats(obj)
    if type(obj) == "number" then
        -- Round to thousandths place (0.001)
        return math.floor(obj * 1000 + 0.5) / 1000
    elseif type(obj) == "table" then
        local rounded = {}
        for k, v in pairs(obj) do
            rounded[k] = round_floats(v)
        end
        return rounded
    else
        return obj
    end
end

-- Deep merge saved settings into existing defaults
-- Saved values override defaults, but missing keys keep their default values
-- Merge saved values INTO the live CONFIG table instead of building a new one. The mod UIs capture
-- row tables when they build their widgets (StrongerEnemies' slider closure writes ability.chance
-- on the table get_ability_option handed it), so replacing CONFIG here orphaned those references:
-- the click went into a dead table and neither the game nor the save ever saw it.
local function deep_merge(defaults, saved)
    if type(defaults) ~= "table" or type(saved) ~= "table" then
        return saved
    end

    for k, v in pairs(saved) do
        if type(v) == "table" and type(defaults[k]) == "table" then
            deep_merge(defaults[k], v)
        else
            defaults[k] = v
        end
    end

    return defaults
end

-- Presets are applied by replacing CONFIG, so the stored copy must not share tables with the live
-- one. Every runtime reader (Alliances' pools, StrongerEnemies' ability rows) re-reads CONFIG.
local function deep_copy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}

    for k, v in pairs(value) do
        copy[k] = deep_copy(v)
    end

    return copy
end

-- Snapshot of the live settings in the same shape mod_settings.json stores under "DucksUI".
-- A preset save stores this, and a preset switch stores it as "Last" before overwriting.
local function collect_all_ui_player_settings(verbose)
    local settings = {}

    -- EndlessShop still uses old pattern
    if rawget(_G, "update_endlessshop_config") then
        pcall(rawget(_G, "update_endlessshop_config"))
    end
    
    -- Collect CONFIG from every registered mod that exists
    for _, name in ipairs(REGISTERED_MODS) do
        local mod = rawget(_G, name)
        if mod then
            if mod.CONFIG then
                settings[name] = round_floats(mod.CONFIG)
                if verbose then print("[DucksUI] Collected settings for mod: " .. name) end
            elseif verbose then
                print("[DucksUI] Mod has no CONFIG table (skipping): " .. name)
            end
        elseif verbose then
            print("[DucksUI] Mod not loaded in global namespace (skipping): " .. name)
        end
    end

    -- EndlessShop still uses old pattern
    local endlessshop_config = rawget(_G, "endlessshop_config")
    if endlessshop_config then
        settings.endlessshop_config = endlessshop_config
    end
    
    -- Round ALL settings to thousandths place before encoding
    return round_floats(settings)
end

local function save_all_ui_player_settings()
    local settings = collect_all_ui_player_settings(true)

    -- Persist through the shared framework settings store (mod_settings.json).
    local mod_settings = _G.Mod_settings
    if type(mod_settings) ~= "table" then
        mod_settings = {}
        if _G.moddata and type(_G.moddata.load_mod_settings) == "function" then
            pcall(_G.moddata.load_mod_settings, mod_settings, nil)
        end
        _G.Mod_settings = mod_settings
    end

    mod_settings["DucksUI"] = settings

    local saved_ok = false
    if _G.moddata and type(_G.moddata.save_mod_settings_to_file) == "function" then
        saved_ok = pcall(_G.moddata.save_mod_settings_to_file, mod_settings, nil)
    end

    if saved_ok then
        print("[DucksUI] Settings saved successfully to: " .. settings_file_path())
    else
        print("[DucksUI] Error saving settings (framework settings store unavailable).")
        return nil
    end
    return settings
end

-- Apply a settings table in the shape mod_settings.json stores under "DucksUI".
-- Import merges: the mod UIs capture row tables when they build, so replacing CONFIG there orphans
-- those references. A preset switch replaces CONFIG outright, so keys a preset does not carry fall
-- back to the mod's own defaults instead of leaking from the preset being left.
local function apply_settings_table(settings, replace)
    for _, name in ipairs(REGISTERED_MODS) do
        local saved = settings[name]
        if saved then
            local mod = rawget(_G, name)
            if mod then
                if replace then
                    mod.CONFIG = deep_copy(saved)
                elseif mod.CONFIG and type(mod.CONFIG) == "table" then
                    mod.CONFIG = deep_merge(mod.CONFIG, saved)
                else
                    mod.CONFIG = deep_copy(saved)
                end
                if mod.load_config then pcall(mod.load_config) end
            end
        end
    end

    -- EndlessShop still uses old pattern
    if settings.endlessshop_config then
        rawset(_G, "endlessshop_config", deep_copy(settings.endlessshop_config))
        if rawget(_G, "update_endlessshop_from_config") then
            pcall(rawget(_G, "update_endlessshop_from_config"))
        end
    end
end

local function import_all_ui_player_settings()
    local mod_settings = _G.Mod_settings
    if type(mod_settings) ~= "table" then
        mod_settings = {}
        if _G.moddata and type(_G.moddata.load_mod_settings) == "function" then
            pcall(_G.moddata.load_mod_settings, mod_settings, nil)
        end
        _G.Mod_settings = mod_settings
    end

    -- Shipping defaults, captured before the merge below overwrites them. Only taken once per mod.
    for _, name in ipairs(REGISTERED_MODS) do
        local mod = rawget(_G, name)
        if not mod_defaults[name] and type(mod) == "table" and type(mod.CONFIG) == "table" then
            mod_defaults[name] = deep_copy(mod.CONFIG)
        end
    end

    local endlessshop_config = rawget(_G, "endlessshop_config")
    if not mod_defaults.endlessshop_config and type(endlessshop_config) == "table" then
        mod_defaults.endlessshop_config = deep_copy(endlessshop_config)
    end

    local settings = mod_settings["DucksUI"]
    if type(settings) ~= "table" then
        -- This is normal on first run - no settings saved yet
        print("[DucksUI] No settings found (first run or new install)")
        return
    end

    print("[DucksUI] Loading settings from: " .. settings_file_path())

    apply_settings_table(settings, false)

    print("[DucksUI] Settings loaded successfully")
end

-- =================================================================================================
-- Presets
--
-- Eight named slots plus two fixed entries. "Default" is the per-mod snapshot taken at import time
-- and is never stored; "Last" holds whatever was live when a preset was last loaded, so a switch
-- can be undone. Slots are a fixed-length array, so two presets may share a name and the JSON never
-- has to encode a sparse table.
-- =================================================================================================

local PRESET_SLOT_COUNT = 8
local PRESET_NAME_MAX_CHARS = 24

local preset_slots = {}
local preset_last = nil
local presets_loaded = false
-- Esc is both "stop editing" and this menu's Back button. The field consumes it first, so the back
-- handler has to let that one press through.
local swallow_next_back = false

local function empty_preset_slot()
    return { name = "", settings = {} }
end

local function slot_is_empty(slot)
    return type(slot) ~= "table" or next(slot.settings or {}) == nil
end

local function preset_store()
    local store = _G.Mod_settings

    if type(store) ~= "table" then
        store = {}
        _G.Mod_settings = store

        if _G.moddata and type(_G.moddata.load_mod_settings) == "function" then
            pcall(_G.moddata.load_mod_settings, store, nil)
        end
    end

    return store
end

local function load_presets()
    if presets_loaded then
        return
    end

    local saved = preset_store().DucksUI_presets
    local saved_slots = type(saved) == "table" and type(saved.slots) == "table" and saved.slots or {}

    preset_slots = {}

    for i = 1, PRESET_SLOT_COUNT do
        local slot = saved_slots[i]

        if type(slot) == "table" and type(slot.settings) == "table" then
            preset_slots[i] = { name = tostring(slot.name or ""), settings = slot.settings }
        else
            preset_slots[i] = empty_preset_slot()
        end
    end

    local last = type(saved) == "table" and saved.last
    preset_last = type(last) == "table" and type(last.settings) == "table" and { name = "Last", settings = last.settings } or nil

    presets_loaded = true
end

-- Memory only: save_all_ui_player_settings writes the whole store when the menu closes, and this
-- key rides along with it.
local function store_presets()
    preset_store().DucksUI_presets = { slots = preset_slots, last = preset_last }
end

-- A preset click is an explicit save: write the file now instead of waiting for the menu to close.
local function persist_settings()
    pcall(save_all_ui_player_settings)
end

local function preset_name_from_field(field, slot_index)
    local name = (field:get_text() or ""):trimwhite()

    if name == "" then
        name = "Preset " .. slot_index
    end

    return name
end

local function load_preset_settings(settings, replace)
    if type(settings) ~= "table" then
        return
    end

    -- Whatever is live now becomes "Last" before it is overwritten.
    preset_last = { name = "Last", settings = collect_all_ui_player_settings(false) }
    apply_settings_table(settings, replace)
    store_presets()
    persist_settings()
end

local current_presets_widget = nil

local function hide_presets_overlay()
    if not current_presets_widget then
        return
    end

    GUI:remove_modal_widget(current_presets_widget)
    GUI:destroy_widget(current_presets_widget)
    current_presets_widget = nil
end

local function create_presets_overlay_ui()
    local children = {
        {
            id = "presets_title",
            type = "label",
            text = "Presets",
            font_size = 36,
            color = "cadetblue",
            position = {"center", "top + 24"},
            text_align = "center"
        },
        {
            id = "presets_hint",
            type = "label",
            text = "Click a name to type it. Save stores the current settings, Load applies a preset.",
            font_size = 20,
            color = "cadetblue",
            position = {"center", "top + 74"},
            text_align = "center"
        },
    }

    local row_y = 120
    local row_step = 64

    local function add_fixed_row(id, label_text, on_load)
        table.insert(children, {
            id = id .. "_label",
            type = "label",
            text = label_text,
            font_size = 24,
            color = "white",
            position = {"center + -450", "top + " .. row_y},
            size = {420, 44},
            text_align = "left"
        })
        table.insert(children, {
            id = id .. "_load",
            type = "button",
            text = "Load",
            font_size = 22,
            color = "white",
            position = {"center + 180", "top + " .. row_y},
            size = {160, 44},
            style = "button_standard",
            on = {
                clicked = on_load
            }
        })

        row_y = row_y + row_step
    end

    add_fixed_row("presets_default", "Default Settings", function()
        load_preset_settings(mod_defaults, true)
    end)

    add_fixed_row("presets_last", "Last Used Settings", function()
        if preset_last then
            load_preset_settings(preset_last.settings, true)
        end
    end)

    for i = 1, PRESET_SLOT_COUNT do
        local slot = preset_slots[i]

        table.insert(children, {
            id = "preset_name_" .. i,
            type = "textfield",
            text = slot.name or "",
            translated = false,
            bg_img = "black",
            font_size = 22,
            color = "white",
            position = {"center + -450", "top + " .. row_y},
            size = {420, 44}
        })
        table.insert(children, {
            id = "preset_save_" .. i,
            type = "button",
            text = "Save",
            font_size = 22,
            color = "white",
            position = {"center", "top + " .. row_y},
            size = {160, 44},
            style = "button_standard",
            on = {
                clicked = function(self)
                    local field = self.parent:get("preset_name_" .. i)

                    if not field then
                        return
                    end

                    local name = preset_name_from_field(field, i)
                    field:set_text(name)
                    preset_slots[i] = { name = name, settings = collect_all_ui_player_settings(false) }
                    store_presets()
                    persist_settings()
                    GUI:unselect(field, _G.INPUT_USER_KEYBOARD_MOUSE)
                end
            }
        })

        table.insert(children, {
            id = "preset_load_" .. i,
            type = "button",
            text = "Load",
            font_size = 22,
            color = "white",
            position = {"center + 180", "top + " .. row_y},
            size = {160, 44},
            style = "button_standard",
            on = {
                clicked = function(self)
                    local field = self.parent:get("preset_name_" .. i)

                    if field then
                        GUI:unselect(field, _G.INPUT_USER_KEYBOARD_MOUSE)
                    end

                    if not slot_is_empty(preset_slots[i]) then
                        load_preset_settings(preset_slots[i].settings, true)
                    end
                end
            }
        })
        table.insert(children, {
            id = "preset_delete_" .. i,
            type = "button",
            text = "Delete",
            font_size = 22,
            color = "white",
            position = {"center + 360", "top + " .. row_y},
            size = {160, 44},
            style = "button_standard",
            on = {
                clicked = function(self)
                    local field = self.parent:get("preset_name_" .. i)

                    preset_slots[i] = empty_preset_slot()
                    store_presets()
                    persist_settings()

                    if field then
                        field:set_text("")
                        GUI:unselect(field, _G.INPUT_USER_KEYBOARD_MOUSE)
                    end
                end
            }
        })

        row_y = row_y + row_step
    end

    table.insert(children, {
        id = "presets_back_button",
        type = "button",
        text = "Back",
        font_size = 24,
        color = "white",
        position = {"center", "bottom - 30"},
        size = {200, 50},
        style = "button_standard",
        on = {
            clicked = function()
                hide_presets_overlay()
            end
        }
    })

    return {
        css = "gui/default_css",
        type = "container",
        size = {"100%", "100%"},
        children = {
            {
                alpha = 0.7,
                bg_img = "black",
                id = "presets_overlay_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {1400, 840},
                type = "container",
                children = children
            }
        }
    }
end

function show_presets_overlay()
    if current_presets_widget then
        return
    end

    load_presets()

    current_presets_widget = GUI:load_proto(create_presets_overlay_ui())

    for i = 1, PRESET_SLOT_COUNT do
        local field = current_presets_widget:get("preset_name_" .. i)

        if field then
            field:input_whitelist_add(_G.INPUT_USER_KEYBOARD_MOUSE)
            field:set_max_length_chars(PRESET_NAME_MAX_CHARS)
            field.on.text_canceled = function()
                -- The field already ate the Esc; the page's Back handler must not close it too.
                swallow_next_back = true
                field:set_text(preset_slots[i].name or "")
            end
        end
    end

    -- Not set_back_handler: while a name is being edited, Esc belongs to the field only.
    local function handle_back()
        if swallow_next_back then
            swallow_next_back = false
            return false
        end

        hide_presets_overlay()

        return true
    end

    for _, input_name in ipairs({"back", "cancel"}) do
        current_presets_widget:set_on_pressed(input_name, handle_back)
        GUI:register_on_pressed(current_presets_widget, input_name)
    end

    GUI:add_modal_widget(current_presets_widget, GUI.MAIN_CONTROLLER)
end

-- Export functions on DucksUI namespace
DucksUI.save_all_settings = save_all_ui_player_settings
DucksUI.import_all_settings = import_all_ui_player_settings
DucksUI.get_settings_path = settings_file_path

-- Also keep legacy global exports for backwards compatibility
rawset(_G, "save_all_ui_player_settings", save_all_ui_player_settings)
rawset(_G, "import_all_ui_player_settings", import_all_ui_player_settings)
