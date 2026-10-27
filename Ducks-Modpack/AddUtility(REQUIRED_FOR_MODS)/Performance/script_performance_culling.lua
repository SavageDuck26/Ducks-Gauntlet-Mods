
local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "1.3.0"
local MOD_DESCRIPTION = "Frame-spread AIManager._cull_distant + should_cull memo + cheaper scan"

local MOD_NAME, log_message = Mods.init_mod()

-- =================================================================================================
-- Engine constants (locals in lua/ai_states/ai_manager.lua; keep in sync -- a mod cannot read them)
-- =================================================================================================
local MAX_MONSTERS = 100   -- live unculled enemy cap (engine constant)
local CULL_DIST = 6        -- engine's own cull distance; CONFIG.cull_dist overrides the pass

PerformanceCulling = PerformanceCulling or {}

PerformanceCulling.CONFIG = PerformanceCulling.CONFIG or {
    enabled = true,
    -- Monsters distance-tested per call. A full floor is then covered over several frames instead of
    -- all at once; lower = smaller per-frame slice, higher = culling reacts sooner.
    scan_slice = 16,
    -- Units culled per call from the pending queue. Each cull pauses every component on the unit.
    cull_slice = 4,
    -- Distance (metres OUTSIDE the frustum) at which the AI pass queues a monster for culling. The
    -- engine's own uncull check brings a unit back at 5 m, so this value is the dead band: at 6 the
    -- band is 1 m and monsters on the boundary flap cull/uncull; at 9 the band is 4 m. A monster
    -- 6-9 m outside the frustum is invisible either way, so the wider band only removes churn.
    cull_dist = 9,
}

-- Counters for the telemetry mod / a console check: PerformanceCulling.metrics
PerformanceCulling.metrics = PerformanceCulling.metrics or {
    passes = 0,
    scanned = 0,
    queued = 0,
    culls = 0,
    skipped = 0,
}

-- =================================================================================================
-- Incremental cull state
-- =================================================================================================
-- A pass walks a per-pass snapshot with a cursor. Candidates beyond CONFIG.cull_dist are queued and
-- drained a few per call. This state lives across frames, so it is cleared on AIManager.clear().
local scan_units = nil
local scan_cursor = 1
local scan_unculled = 0
local cull_queue = nil
local cull_cursor = 1
-- Candidates are kept in parallel arrays; the old { dist = ..., unit = ... } tables allocated one
-- table per candidate per pass.
local cand_dist = {}
local cand_unit = {}
local cand_count = 0
-- Weak keys: a despawned unit handle must not be pinned by its skip flag for the whole session.
local cull_skip = setmetatable({}, { __mode = "k" })
local scan_skip = setmetatable({}, { __mode = "k" })
-- Units already sitting in the cull queue. The queue drains a few per call, so without this a unit
-- queued in pass N can be queued again in pass N+1 while still unculled; the second cull_unit would
-- fail (its not_culled_units entry is gone by then) and the unit would be skipped for the session.
local queued = setmetatable({}, { __mode = "k" })
-- Conservative until a pass has counted for real: above MAX_MONSTERS means "not yet", which is the
-- safe answer for AIManager._try_spawn_monster while a pass is still in flight.
local last_unculled = MAX_MONSTERS + 1

local function reset_cull_state()
    scan_units = nil
    scan_cursor = 1
    scan_unculled = 0
    cull_queue = nil
    cull_cursor = 1
    cand_count = 0
    cull_skip = setmetatable({}, { __mode = "k" })
    scan_skip = setmetatable({}, { __mode = "k" })
    queued = setmetatable({}, { __mode = "k" })
    last_unculled = MAX_MONSTERS + 1
end

-- =================================================================================================
-- Scan helpers
-- =================================================================================================
-- Hoisted out of the loop. The old code built a closure per unit per call, which allocated on every
-- slice; these are plain functions, so the JIT can inline them and nothing is allocated per unit.
local GONE = "gone"

local unit_alive = nil   -- Unit.alive, resolved on first use

local function is_alive(unit)
    if unit_alive == nil then
        unit_alive = type(Unit) == "table" and Unit.alive or false
    end

    -- A stale handle from the floor being left is exactly what the pcall around this guards against.
    if unit_alive and not unit_alive(unit) then
        return false
    end

    return true
end

-- Distance OUTSIDE the frustum, straight from the engine binding. CameraManager's wrapper adds a
-- Profiler.start / get_camera / Profiler.stop round trip around the same call, per unit.
local function measure_direct(unit, camera, inside_frustum)
    return -inside_frustum(camera, Unit.world_position(unit, 0))
end

-- Fallback for the (unexpected) case where the Camera namespace is not callable.
local function measure_wrapped(unit)
    local _, dist = CameraManager:is_position_inside_frustum(Unit.world_position(unit, 0))

    return dist
end

-- true when already culled, GONE when the handle is dead, otherwise the distance.
local function scan_unit(unit, measure, camera, inside_frustum)
    if not is_alive(unit) then
        return GONE
    end

    if EntityCullingManager.culled_units[unit] then
        return true
    end

    return measure(unit, camera, inside_frustum)
end

-- =================================================================================================
-- Incremental AIManager._cull_distant
-- =================================================================================================
-- Replacement for AIManager._cull_distant that does the same job in slices rather than all at once.
local function cull_distant_sliced(self)
    if not EntityCullingManager:should_cull() then
        return
    end

    local config = PerformanceCulling.CONFIG
    local metrics = PerformanceCulling.metrics
    local cull_dist = config.cull_dist or CULL_DIST

    -- Drain the cull queue first: this is where pause_all_components runs, and spreading it keeps it
    -- off a single heavy frame.
    if cull_queue then
        local queue_size = #cull_queue
        local last_cull = math.min(queue_size, cull_cursor + config.cull_slice - 1)

        for i = cull_cursor, last_cull do
            local unit = cull_queue[i]

            if self._monsters[unit] and not cull_skip[unit] then
                -- cull_unit indexes the unit's culled data without checking it
                -- exists, so a unit the manager has no record for takes the
                -- client down inside AIManager.update.  The risen mummy is one.
                -- Skip such a unit for good rather than retrying every pass, and
                -- say so once if the loader offers a log.
                local cull_ok, cull_err = pcall(EntityCullingManager.cull_unit,
                    EntityCullingManager, unit)

                queued[unit] = nil

                if cull_ok then
                    metrics.culls = metrics.culls + 1
                else
                    cull_skip[unit] = true
                    metrics.skipped = metrics.skipped + 1

                    if type(Mods) == "table" and type(Mods.log) == "function" then
                        Mods.log("[PerformanceCulling] skipped uncullable unit: "
                            .. tostring(cull_err))
                    end
                end
            end
        end

        cull_cursor = last_cull + 1

        if cull_cursor > queue_size then
            cull_queue = nil
            cull_cursor = 1
        end
    end

    -- One camera + binding lookup per call (per frame), not per unit: CameraManager:get_camera()
    -- goes through viewport_proxy, and CameraManager:is_position_inside_frustum adds two Profiler
    -- calls on top of Camera.inside_frustum for every unit tested. rawget: strict.lua makes a plain
    -- read of an undeclared global an error, and this is a namespace, not a declared global.
    local camera_ns = rawget(_G, "Camera")
    local inside_frustum = nil

    if type(camera_ns) == "table" and type(camera_ns.inside_frustum) == "function" then
        inside_frustum = camera_ns.inside_frustum
    end

    local camera = nil
    local measure = measure_wrapped

    if inside_frustum then
        camera = CameraManager:get_camera()

        if camera ~= nil then
            measure = measure_direct
        else
            inside_frustum = nil
        end
    end

    if not scan_units then
        local units = {}

        for unit in pairs(self._monsters) do
            units[#units + 1] = unit
        end

        scan_units = units
        scan_cursor = 1
        scan_unculled = 0
        cand_count = 0

        -- Keep AIManager.update() calling us until the pass (and any queue) is finished.
        self._need_culling = true
    end

    local count = #scan_units
    local last_scan = math.min(count, scan_cursor + config.scan_slice - 1)

    for i = scan_cursor, last_scan do
        local unit = scan_units[i]

        -- Units despawn mid-pass, so self._monsters is the live set - but on a
        -- level transition it can still hold handles from the floor being left,
        -- and reading one crashes the client.  Anything that fails here is
        -- dropped for the rest of the pass.  The guarded function is hoisted, so
        -- no closure is allocated per unit (the old form allocated one per unit
        -- per slice).
        if self._monsters[unit] and not scan_skip[unit] and not queued[unit] then
            local scan_ok, culled_or_dist = pcall(scan_unit, unit, measure, camera, inside_frustum)

            if not scan_ok then
                scan_skip[unit] = true
                metrics.skipped = metrics.skipped + 1

                if type(Mods) == "table" and type(Mods.log) == "function" then
                    Mods.log("[PerformanceCulling] dropped stale unit from scan: "
                        .. tostring(culled_or_dist))
                end
            elseif culled_or_dist == GONE then
                -- Unit.alive said no: drop it quietly, the pcall path above is for real errors.
                scan_skip[unit] = true
            elseif culled_or_dist ~= true then
                scan_unculled = scan_unculled + 1

                if culled_or_dist > cull_dist then
                    cand_count = cand_count + 1
                    cand_dist[cand_count] = culled_or_dist
                    cand_unit[cand_count] = unit
                end
            end
        end
    end

    scan_cursor = last_scan + 1

    if scan_cursor > count then
        local num_to_cull = math.min(cand_count, scan_unculled - MAX_MONSTERS)

        if num_to_cull > 0 then
            -- k-largest selection: num_to_cull is normally single digits, so scanning the candidate
            -- list k times beats sorting it and allocates nothing.
            if not cull_queue then
                cull_queue = {}
                cull_cursor = 1
            end

            local added = 0

            for _ = 1, num_to_cull do
                local best, best_dist = nil, nil

                for j = 1, cand_count do
                    local d = cand_dist[j]

                    if d and (best_dist == nil or d > best_dist) then
                        best, best_dist = j, d
                    end
                end

                if best == nil then
                    break
                end

                cull_queue[#cull_queue + 1] = cand_unit[best]
                queued[cand_unit[best]] = true
                cand_dist[best] = nil
                added = added + 1
            end

            scan_unculled = scan_unculled - added
            metrics.queued = metrics.queued + added
        end

        last_unculled = scan_unculled
        self._need_culling = scan_unculled > MAX_MONSTERS or cull_queue ~= nil

        metrics.passes = metrics.passes + 1
        metrics.scanned = metrics.scanned + count

        scan_units = nil
        cand_count = 0
    end

    return last_unculled
end


-- =================================================================================================
-- Hooks
-- =================================================================================================
Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/ai_states/ai_manager" then
        Mods.hook:set_object_path("AIManager", "_cull_distant", function(orig_cull, self, ...)
            if not PerformanceCulling.CONFIG.enabled then
                return orig_cull(self, ...)
            end

            return cull_distant_sliced(self)
        end, MOD_NAME .. ".AIManager._cull_distant", MOD_NAME)

        Mods.hook:set_object_path("AIManager", "clear", function(orig_clear, self, ...)
            reset_cull_state()

            return orig_clear(self, ...)
        end, MOD_NAME .. ".AIManager.clear", MOD_NAME)
    end

    if path == "lua/managers/entity_culling_manager" then
        -- should_cull() reads the current floor's layout, which cannot change while floor_id is the
        -- same, yet it runs every frame (and once more from AIManager._cull_distant). Cache per floor.
        local cached_floor_id = nil
        local cached_should = nil

        Mods.hook:set_object_path("EntityCullingManager", "should_cull", function(orig_should, self, ...)
            if not PerformanceCulling.CONFIG.enabled then
                return orig_should(self, ...)
            end

            local floor_id = self.state_game:get_floor_id()

            if floor_id ~= cached_floor_id then
                -- a new floor: nothing from the last one is still valid
                reset_cull_state()
                cached_floor_id = floor_id
                cached_should = orig_should(self, ...)
            end

            return cached_should
        end, MOD_NAME .. ".EntityCullingManager.should_cull", MOD_NAME)
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)

-- =================================================================================================
-- Diagnostics
-- =================================================================================================
-- Snapshot of the running pass, for the Duckmode diagnostics mod. The pass state is file-local, so it
-- has to be exposed deliberately. Pure table reads, and nothing calls it in normal play.
-- =================================================================================================
PerformanceCulling.debug_state = function()
    return {
        queued = cull_queue and #cull_queue or 0,
        cursor = scan_cursor,
        total = scan_units and #scan_units or 0,
        candidates = cand_count,
        last_unculled = last_unculled,
    }
end
