-- =================================================================================================
-- Author:  SavageDuck26
-- Version: 2.0
-- Purpose: Shortens how long surface debris keeps drawing. Caps the decal budget and cuts gib
--          (flesh chunk) lifetime so both stop consuming render time sooner.
-- =================================================================================================

local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "2.0"
local MOD_DESCRIPTION = "Faster decal + gib cleanup"

local MOD_NAME = Mods.init_mod()

Performance = Performance or {}

Performance.CONFIG = Performance.CONFIG or {
    enabled = true,
    -- Live decal cap. SurfaceEffectManager evicts the oldest decals above this (fade, then destroy);
    -- lower means fewer decal projections are drawn. Reset on floor enter, so it is re-applied there.
    max_decals = 128,
    -- Seconds a gib rests before it starts sinking away (engine default: 2).
    gib_wait = 0.5,
    -- Seconds a gib spends sinking before it is destroyed (engine default: 3).
    gib_decay = 1.0,
}

local function clamp_to(value, fallback, maximum)
    value = value or fallback

    if value > maximum then
        value = maximum
    end

    return value
end

-- =================================================================================================
-- Decals
-- =================================================================================================
-- SurfaceEffectManager resets its budget during setup, so this must be re-applied on every floor enter.
Mods.hook:set_object_path("StateGame", "on_enter", function(orig, self, params)
    orig(self, params)

    if not Performance.CONFIG.enabled then
        return
    end

    local surface_effects = rawget(_G, "SurfaceEffectManager")

    if surface_effects then
        surface_effects:set_max_decal_units(Performance.CONFIG.max_decals)
    end
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
