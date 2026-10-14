
local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Spawn a cape only once when two players are on the same hero."


local MOD_NAME, log_message = Mods.init_mod()

-- DOES NOT WORK YET. Crashes on level load when same cape.

local function cape_already_attached(self, unit, cape)
    for other_unit, context in pairs(self.entity_manager:get_slave_entities(self.name)) do
        local slots = other_unit ~= unit and context.state.slots

        if slots and slots.cape and slots.cape.item_id == cape then
            return true
        end
    end

    return false
end

Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/components/equipment_component" and EquipmentComponent then
        Mods.hook:set_object_path("EquipmentComponent", "update_slots_slave", function(orig2, self, unit, state)
            if state.cape and state.slots and cape_already_attached(self, unit, state.cape) then
                -- Hide the cape from this pass only, so the replicated loadout keeps its true value.
                local cape = state.cape

                state.cape = nil

                local result2 = orig2(self, unit, state)

                state.cape = cape

                return result2
            end

            return orig2(self, unit, state)
        end, MOD_NAME .. ".EquipmentComponent.update_slots_slave", MOD_NAME)
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)
