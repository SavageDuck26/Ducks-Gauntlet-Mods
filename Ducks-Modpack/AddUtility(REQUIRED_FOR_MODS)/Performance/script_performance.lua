
local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "3.0.0"
local MOD_DESCRIPTION = "Faster decal + gib cleanup + cheaper renderer settings per floor"

local MOD_NAME = Mods.init_mod()

Performance = Performance or {}

Performance.CONFIG = Performance.CONFIG or {
    enabled = true,
    -- Live decal cap. SurfaceEffectManager evicts the oldest decals above this (fade, then destroy);
    -- lower means fewer decal projections are drawn. Reset on floor enter, so it is re-applied there.
    max_decals = 64,
    -- Seconds a gib rests before it starts sinking away (engine default: 2).
    gib_wait = 0.5,
    -- Seconds a gib spends sinking before it is destroyed (engine default: 3).
    gib_decay = 1.0,
    -- Renderer settings, re-applied on every floor enter (the engine resets several of them when it
    -- builds a level's render setup, so a one-shot change at boot does not stick). Every name here is
    -- one the game's own options screen writes, and it is applied through
    -- Application.set_renderer_setting, which applies live and does NOT save to the player's user
    -- settings -- so the options menu is left feeling untouched.
    -- Shadow casting is the single biggest win on a floor with ~1000 monsters.
    render = {
        local_lights_cast_shadows = false,
        ssao_enabled = false,
        bloom_enabled = false,
        fxaa_enabled = true,
        dof_enabled = false,
    },
}

local function clamp_to(value, fallback, maximum)
    value = value or fallback

    if value > maximum then
        value = maximum
    end

    return value
end

-- =================================================================================================
-- Renderer settings
-- =================================================================================================
-- rawget is used on purpose: strict.lua turns a plain global read of an undeclared name into an
-- error, and these tables may not exist yet on an early floor enter.
local RENDER_SETTING_NAMES = {
    "local_lights_cast_shadows",
    "ssao_enabled",
    "bloom_enabled",
    "fxaa_enabled",
    "dof_enabled",
}

local function apply_render_settings()
    local render = Performance.CONFIG.render

    if type(render) ~= "table" then
        return 0
    end

    local app = rawget(_G, "Application")

    if type(app) ~= "table" or type(app.set_renderer_setting) ~= "function" then
        return 0
    end

    local applied = 0

    for i = 1, #RENDER_SETTING_NAMES do
        local name = RENDER_SETTING_NAMES[i]
        local value = render[name]

        if value ~= nil then
            app.set_renderer_setting(name, value and "true" or "false")
            applied = applied + 1
        end
    end

    return applied
end

-- =================================================================================================
-- Decals
-- =================================================================================================
-- SurfaceEffectManager resets its budget during setup, so this must be re-applied on every floor enter.
Mods.hook:set_object_path("StateGame", "on_enter", function(orig, self, params)
    orig(self, params)

    local config = Performance.CONFIG

    if not config.enabled then
        return
    end

    local surface_effects = rawget(_G, "SurfaceEffectManager")

    if surface_effects then
        surface_effects:set_max_decal_units(config.max_decals)
    end

    apply_render_settings()
end, MOD_NAME .. ".StateGame.on_enter", MOD_NAME)

-- =================================================================================================
-- Gibs
-- =================================================================================================
-- A gib is thrown, must come to rest, then waits before it sinks. add_gib_unit seeds the sink time;
-- the post-rest wait is set inside GibManager.update from Despawner's shared default, so it is
-- clamped here after the fact rather than mutating that constant (other units read it too).
Mods.hook:set_object_path("GibManager", "add_gib_unit", function(orig, self, unit, start_decay_time, decay_duration, ...)
    if Performance.CONFIG.enabled then
        local config = Performance.CONFIG

        start_decay_time = clamp_to(start_decay_time, config.gib_wait, config.gib_wait)
        decay_duration = clamp_to(decay_duration, config.gib_decay, config.gib_decay)
    end

    return orig(self, unit, start_decay_time, decay_duration, ...)
end, MOD_NAME .. ".GibManager.add_gib_unit", MOD_NAME)

Mods.hook:set_object_path("GibManager", "update", function(orig, self, dt)
    orig(self, dt)

    if not Performance.CONFIG.enabled then
        return
    end

    -- Only "waiting" gibs are touched; while a gib is still awake its sink timer is set but the
    -- waiting branch is not evaluated, so clamping it early is harmless and it is re-set on rest.
    local deadline = _G.GAME_TIME + Performance.CONFIG.gib_wait

    for _, data in pairs(self.gib_units) do
        if data.state == "waiting" and data.start_decay_time > deadline then
            data.start_decay_time = deadline
        end
    end
end, MOD_NAME .. ".GibManager.update", MOD_NAME)

print("[Performance] Loaded - " .. MOD_AUTHOR)
