-- =================================================================================================
-- Author:  SavageDuck26
-- Version: 1.2
-- Purpose: Spread AIManager._cull_distant over frames. The engine scans every monster (a
--          Unit.world_position + frustum test each) and culls the whole overflow in one frame; that
--          single-frame burst of EntityCullingManager:cull_unit -> pause_all_components is what
--          stutters. This walks a snapshot in fixed slices and drains the cull queue a few units at
--          a time, so neither the scan nor the culling lands in one heavy frame. Also memoizes
--          EntityCullingManager:should_cull per floor.
-- =================================================================================================

local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "1.2"
local MOD_DESCRIPTION = "Frame-spread AIManager._cull_distant + should_cull memo"

local MOD_NAME, log_message = Mods.init_mod()

-- =================================================================================================
-- Engine constants (locals in lua/ai_states/ai_manager.lua; keep in sync -- a mod cannot read them)
-- =================================================================================================
local MAX_MONSTERS = 100   -- live unculled enemy cap
local CULL_DIST = 6        -- frustum distance beyond which an enemy may be culled

PerformanceCulling = PerformanceCulling or {}

PerformanceCulling.CONFIG = PerformanceCulling.CONFIG or {
    enabled = true,
    -- Monsters distance-tested per call. A full floor is then covered over several frames instead of
    -- all at once; lower = smaller per-frame slice, higher = culling reacts sooner.
    scan_slice = 16,
    -- Units culled per call from the pending queue. Each cull pauses every component on the unit.
    cull_slice = 4,
}

-- =================================================================================================
-- Incremental cull state
-- =================================================================================================
-- A pass walks a per-pass snapshot with a cursor. Candidates beyond CULL_DIST are queued and drained
-- a few per call. This state lives across frames, so it is cleared on AIManager.clear() (floor exit).
local scan_units = nil
local scan_cursor = 1
local scan_unculled = 0
local scan_candidates = nil
local cull_queue = nil
local cull_cursor = 1
local last_unculled = MAX_MONSTERS

local function furthest_first(a, b)
    return a.dist > b.dist
end

local function reset_cull_state()
    scan_units = nil
    scan_cursor = 1
    scan_unculled = 0
    scan_candidates = nil
    cull_queue = nil
    cull_cursor = 1
    last_unculled = MAX_MONSTERS
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

    -- Drain the cull queue first: this is where pause_all_components runs, and spreading it keeps it
    -- off a single heavy frame.
    if cull_queue then
        local queue_size = #cull_queue
        local last_cull = math.min(queue_size, cull_cursor + config.cull_slice - 1)

        for i = cull_cursor, last_cull do
            local unit = cull_queue[i]

            if self._monsters[unit] then
                EntityCullingManager:cull_unit(unit)
            end
        end

        cull_cursor = last_cull + 1

        if cull_cursor > queue_size then
            cull_queue = nil
            cull_cursor = 1
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
        scan_candidates = {}

        -- Keep AIManager.update() calling us until the pass (and any queue) is finished.
        self._need_culling = true
    end

    local count = #scan_units
    local last_scan = math.min(count, scan_cursor + config.scan_slice - 1)

    for i = scan_cursor, last_scan do
        local unit = scan_units[i]

        -- Units despawn mid-pass, so self._monsters is the live set.
        if self._monsters[unit] and not EntityCullingManager:is_culled(unit) then
            scan_unculled = scan_unculled + 1

            local pos = Unit.world_position(unit, 0)
            local _, dist = CameraManager:is_position_inside_frustum(pos)

            if dist > CULL_DIST then
                scan_candidates[#scan_candidates + 1] = { dist = dist, unit = unit }
            end
        end
    end

    scan_cursor = last_scan + 1

    if scan_cursor > count then
        local num_to_cull = math.min(#scan_candidates, scan_unculled - MAX_MONSTERS)

        if num_to_cull > 0 then
            table.sort(scan_candidates, furthest_first)

            if not cull_queue then
                cull_queue = {}
                cull_cursor = 1
            end

            for i = 1, num_to_cull do
                cull_queue[#cull_queue + 1] = scan_candidates[i].unit
            end

            scan_unculled = scan_unculled - num_to_cull
        end

        last_unculled = scan_unculled
        self._need_culling = scan_unculled > MAX_MONSTERS or cull_queue ~= nil

        scan_units = nil
        scan_candidates = nil
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
                cached_floor_id = floor_id
                cached_should = orig_should(self, ...)
            end

            return cached_should
        end, MOD_NAME .. ".EntityCullingManager.should_cull", MOD_NAME)
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)

print("[PerformanceCulling] Loaded - " .. MOD_AUTHOR)

