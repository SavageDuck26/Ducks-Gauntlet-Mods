-- =================================================================================================
-- Author:  SavageDuck26
-- Version: 1.0.0
-- Purpose: Make EntityManager:pause_all_components / resume_all_components cheaper.
--
--          The engine walks EVERY active component of the level (57 in state_game.lua) and asks
--          EntityAux.has_component(unit, name) for each, per culled/unculled unit. Only ~12 of those
--          57 are ever on a given unit type, so ~45 probes per pause are pure waste.
--
--          A unit's own component list is already known and cached per unit type
--          (EntityAux.component_list, foundation/lua/entity/entity_aux.lua), and it is in the same
--          component-registration order as active_components, so the mask is ascending and pause
--          ORDER IS UNCHANGED. The inlined has_component guard is kept, so a component that is listed
--          but has no live master/slave context is still skipped exactly as before.
-- =================================================================================================

local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "1.0.0"
local MOD_DESCRIPTION = "Masked EntityManager pause/resume (fewer per-component probes)"

local MOD_NAME, log_message = Mods.init_mod()

PerformancePause = PerformancePause or {}

PerformancePause.CONFIG = PerformancePause.CONFIG or {
    enabled = true,
    -- Compare the mask against EntityAux.has_component for the first N pauses. Exact but not free, so
    -- it only runs while the mask is unproven; any mismatch disables the fast path for the session.
    verify = true,
    verify_samples = 50,
}

PerformancePause.metrics = PerformancePause.metrics or {
    pauses = 0,
    resumes = 0,
    probes_avoided = 0,
    verify_checks = 0,
    verify_failed = 0,
}

local mask_by_type = {}        -- unit_path -> ascending array of component indices
local list_size_by_type = {}   -- unit_path -> #component_list when the mask was built
local verify_left = PerformancePause.CONFIG.verify_samples or 50
local installed = false

-- =================================================================================================
-- Mask
-- =================================================================================================
local function build_mask(self, unit, unit_path, list)
    local cm = self.component_manager

    if not cm or not cm.active_components or not cm.components then
        return nil
    end

    -- name -> index in component_manager.components
    local active = {}
    local ac = cm.active_components

    for i = 1, #ac do
        local component = cm.components[ac[i]]

        if component then
            active[component.name] = ac[i]
        end
    end

    local mask = {}

    for i = 1, #list do
        local index = active[list[i]]

        if index then
            mask[#mask + 1] = index
        end
    end

    mask_by_type[unit_path] = mask
    list_size_by_type[unit_path] = #list

    return mask
end

local function mask_for(self, unit)
    if type(EntityAux) ~= "table" or type(EntityAux.component_list) ~= "function" then
        return nil
    end

    local unit_path = Unit.get_data(unit, "unit_path")

    if unit_path == nil then
        return nil
    end

    local list = EntityAux.component_list(unit, unit_path)
    local mask = mask_by_type[unit_path]

    -- Rebuild if the unit type's component list changed (a component added/removed for that type).
    if mask and list_size_by_type[unit_path] == #list then
        return mask
    end

    return build_mask(self, unit, unit_path, list)
end

-- Exact parity check: every component the mask claims must really be on the unit, and no component
-- the unit really has may be missing from the mask.
local function mask_is_complete(self, unit, mask)
    local cm = self.component_manager
    local components = cm.components
    local in_mask = {}

    for i = 1, #mask do
        local name = components[mask[i]].name

        if not EntityAux.has_component(unit, name) then
            return false, "mask lists a component the unit does not have: " .. tostring(name)
        end

        in_mask[name] = true
    end

    local ac = cm.active_components

    for i = 1, #ac do
        local name = components[ac[i]].name

        if EntityAux.has_component(unit, name) and not in_mask[name] then
            return false, "unit has a component the mask is missing: " .. tostring(name)
        end
    end

    return true
end

-- =================================================================================================
-- Fast paths
-- =================================================================================================
-- Mirrors foundation/lua/entity/entity_manager.lua:261 exactly, minus the 57-probe scan.
local function pause_all_fast(self, unit)
    local mask = mask_for(self, unit)

    if not mask or #mask == 0 then
        return false
    end

    self.pending[unit] = nil

    local slave = EntityAux.cache_slave_context[unit]
    local master = EntityAux.cache_master_context[unit]
    local components = self.component_manager.components
    local paused_all = self.paused_contexts
    local contexts = self.component_name_to_contexts

    for i = 1, #mask do
        local index = mask[i]
        local name = components[index].name
        local paused = paused_all[name]

        -- has_component inlined: the unit holds a live context for this component
        if paused and paused[unit] == nil
            and ((slave and slave[name] ~= nil) or (master and master[name] ~= nil)) then
            local component_context = contexts[name]
            local master_context = master and master[name]
            local slave_context = slave and slave[name]

            components[index]:pause(unit, master_context, slave_context)

            paused[unit] = {
                master_context = master_context,
                slave_context = slave_context,
            }
            component_context.master[unit] = nil
            component_context.slave[unit] = nil
            component_context.prediction[unit] = nil
        end
    end

    return true
end

-- Mirrors entity_manager.lua:295. The engine indexes paused_contexts[unit] unconditionally; this
-- version skips units that are not paused rather than erroring on them.
local function resume_all_fast(self, unit)
    local mask = mask_for(self, unit)

    if not mask or #mask == 0 then
        return false
    end

    local components = self.component_manager.components
    local paused_all = self.paused_contexts
    local contexts = self.component_name_to_contexts

    for i = 1, #mask do
        local index = mask[i]
        local name = components[index].name
        local paused = paused_all[name]
        local entry = paused and paused[unit]

        if entry then
            local component_context = contexts[name]
            local master_context = entry.master_context
            local slave_context = entry.slave_context

            paused[unit] = nil
            component_context.master[unit] = master_context
            component_context.slave[unit] = slave_context

            if master_context then
                master_context.num_commands = 0
            else
                component_context.prediction[unit] = slave_context
            end

            if slave_context then
                slave_context.num_commands = 0
            end

            components[index]:resume(unit, master_context, slave_context)
        end
    end

    return true
end

-- =================================================================================================
-- Hooks
-- =================================================================================================
-- EntityCullingManager:cull_unit calls self.entity_manager:pause_all_components(unit), which resolves
-- through the class metatable, so replacing the class method is enough (same mechanism the existing
-- AIManager/EntityCullingManager hooks rely on).
local function install()
    if installed or type(rawget(_G, "EntityManager")) ~= "table" then
        return installed
    end

    installed = true

    Mods.hook:set_object_path("EntityManager", "pause_all_components", function(orig, self, unit)
        if not PerformancePause.CONFIG.enabled or not self.component_manager then
            return orig(self, unit)
        end

        local mask = mask_for(self, unit)

        if not mask then
            return orig(self, unit)
        end

        if PerformancePause.CONFIG.verify and verify_left > 0 then
            verify_left = verify_left - 1
            PerformancePause.metrics.verify_checks = PerformancePause.metrics.verify_checks + 1

            local ok, why = mask_is_complete(self, unit, mask)

            if not ok then
                PerformancePause.metrics.verify_failed = PerformancePause.metrics.verify_failed + 1
                PerformancePause.CONFIG.enabled = false

                if log_message then
                    log_message("WARN", "mask mismatch, fast pause disabled: " .. tostring(why))
                end

                return orig(self, unit)
            end
        end

        if pause_all_fast(self, unit) then
            local active = self.component_manager.active_components

            PerformancePause.metrics.pauses = PerformancePause.metrics.pauses + 1
            PerformancePause.metrics.probes_avoided = PerformancePause.metrics.probes_avoided
                + math.max(0, (active and #active or 0) - #mask)

            return
        end

        return orig(self, unit)
    end, MOD_NAME .. ".EntityManager.pause_all_components", MOD_NAME)

    Mods.hook:set_object_path("EntityManager", "resume_all_components", function(orig, self, unit)
        if not PerformancePause.CONFIG.enabled or not self.component_manager then
            return orig(self, unit)
        end

        if resume_all_fast(self, unit) then
            PerformancePause.metrics.resumes = PerformancePause.metrics.resumes + 1

            return
        end

        return orig(self, unit)
    end, MOD_NAME .. ".EntityManager.resume_all_components", MOD_NAME)

    if log_message then
        log_message("INFO", "fast pause/resume installed")
    end

    return true
end

install()

Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    -- EntityManager may not exist yet when this file loads; retry once its module has been required.
    -- Duplicate installs are prevented by the `installed` flag and by the framework's own duplicate
    -- hook protection.
    if not installed and path == "foundation/lua/entity/entity_manager" then
        install()
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)

print("[PerformancePause] Loaded - " .. MOD_AUTHOR)


