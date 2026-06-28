-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Fixes crashes with poison tower
-- =================================================================================================

local MOD_NAME = "FixPoisonTower"

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)
    
    if path == "lua/ability/animated_physic_queries/projectile_lob_physic_query" then
        local GRAVITY = 20

        Mods.hook:set(MOD_NAME, "ProjectileLobPhysicQuery.initiate_frame", function(orig, self, event, dt, world_pose)

            AnimatedPhysicQuery.initiate_frame(self, event, dt, world_pose)

            local query_info = event.query_info

            if query_info.current_position ~= nil then
                return
            end

            local rotation = Matrix4x4.rotation(world_pose)
            local direction = Quaternion.forward(rotation)
            local origin = self:calculate_origin(event, world_pose)
            local settings = event.settings
            local angle = settings.angle

            if settings.random_angle then
                angle = event.randomizer:rangef(settings.random_angle[1], settings.random_angle[2])
            end

            if angle then
                local x1, x2, x3 = Vector3.to_elements(direction)

                direction = Vector3(self:rotate_around_z(x1, x2, x3, angle))
            end

            local target

            if Unit.alive(event.target_unit) and not settings.random_angle then
                query_info.has_target = true
                target = TargetAlignmentAux.get_target_position(nil, event.target_unit)
            elseif settings.construct_target_position then
                local info = settings.construct_target_position
                local distance = event.randomizer:rangef(info.distance_min, info.distance_max)

                target = origin - Vector3.up() + direction * distance
            else
                if event.target_position_box then
                    target = Vector3Aux.unbox(event.target_position_box) -- Stupid thing, bug, always nil for poison tower.
                else
                    -- Fallback: create a target in front of the origin
                    target = origin + direction * 10
                end
            end

            if settings.marker_unit_path then
                local world = self.world_proxy:get_world()

                event.projectile_lob_marker_unit = World.spawn_unit(world, settings.marker_unit_path, target)
            end

            local speed_multiplier = settings.speed_multiplier or 1

            query_info.start_direction = Vector3Aux.box({}, direction)
            query_info.start_position = Vector3Aux.box({}, origin)
            query_info.current_position = Vector3Aux.box({}, origin)
            query_info.target_posititon = Vector3Aux.box({}, target)

            local to_target = target - origin
            local to_target_direction = Vector3.normalize(to_target)
            local up_direction = Vector3.up()
            local to_target_xy = Vector3(to_target.x, to_target.y, 0)
            local forward = Vector3.normalize(to_target_xy)
            local distance

            if settings.use_flat_distance then
                distance = Vector3.length(to_target_xy)
            else
                distance = Vector3.length(to_target)
            end

            local dot = Vector3.dot(forward, to_target_direction)
            local up_dot = Vector3.dot(up_direction, to_target_direction)
            local vertical_angle = math.deg(math.acos(math.saturate(dot)))

            if up_dot < 0 then
                if vertical_angle < 3 and (settings.vertical_angle or 45) < 3 then
                    vertical_angle = 3
                else
                    vertical_angle = settings.vertical_angle or 45
                end
            else
                vertical_angle = vertical_angle + math.max(settings.vertical_angle or 45, 3)
            end

            local forward_direction = forward
            local firing_angle = math.clamp(vertical_angle, 1, 89)
            local theta = math.rad(firing_angle)
            local cross_product = Vector3.cross(forward_direction, up_direction)
            local q = Quaternion.axis_angle(cross_product, theta)
            local direction_of_velocity = Quaternion.rotate(q, forward_direction)
            local y0 = origin.z - target.z
            local gravity = speed_multiplier * GRAVITY
            local sec_tetha = 1 / math.cos(theta)
            local nominator = math.sqrt(gravity / 2) * distance * math.sqrt(sec_tetha)
            local a = distance * math.sin(theta)
            local b = y0 * math.cos(theta)
            local denominator = a + b > 0 and math.sqrt(a + b) or 1
            local speed = nominator / denominator
            local velocity = direction_of_velocity * speed

            query_info.velocity = Vector3Aux.box({}, velocity)

            local s = math.sin(theta)
            local x = math.max(speed * speed * s * s + 2 * gravity * y0, 0)

            query_info.max_time = settings.max_time and settings.max_time / 30 or speed * s / gravity + math.sqrt(x) / gravity + 1
        end)
    end

    return result
end)
