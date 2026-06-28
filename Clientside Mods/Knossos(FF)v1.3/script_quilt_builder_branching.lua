-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.3
-- Purpose: Clean Custom Quilt Builder Override - Simple Branching System
-- =================================================================================================

local MOD_NAME = "Knossos"

Knossos = Knossos or {}
Knossos.loaded = true

Knossos.CONFIG = Knossos.CONFIG or {}
Knossos.CONFIG.enabled = (Knossos.CONFIG.enabled == nil) and true or Knossos.CONFIG.enabled
Knossos.CONFIG.mode = Knossos.CONFIG.mode or "Small"

Knossos.BRANCH_DEFAULTS = {
    enabled               = true,   -- Master toggle for all branching
    random_exits          = false,  -- Whether to randomize exit doors on branch encounters (instead of using the tile's default)
    max_total_branches    = 10,     -- Maximum branches across the entire quilt
    branch_chance         = 0.5,    -- Chance (0-1) a main-path encounter room gets queued
    max_branches_per_room = 2,      -- Max branches that can spawn from a single room
    min_hallways          = 1,      -- Min filler tiles before an encounter can be placed
    max_hallways          = 2,      -- Max filler tiles before encounter placement is forced
    max_branch_length     = 12,     -- Safety cap on iterations per single branch attempt
    min_space_score       = 6,      -- Min space score for a door to be considered viable
    allow_recursive       = false,  -- Whether branch-end encounters can themselves branch
    recursive_chance      = 0.0,    -- Chance (0-1) a branch encounter gets queued for further branching
    max_depth             = 1,      -- Max branch depth (1 = main-path only, 2 = one recursive level, etc.)
}

Knossos.MODE_CONFIGS = Knossos.MODE_CONFIGS or {}

Knossos.MODE_CONFIGS.small = {
    random_exits = false,
    max_total_branches = 5,
    branch_chance = 0.4,
    max_branches_per_room = 1,
    min_hallways = 1,
    max_hallways = 1,
    max_branch_length = 4,
    min_space_score = 6,
    allow_recursive = false,
    recursive_chance = 0.0,
    max_depth = 1,
}

Knossos.MODE_CONFIGS.medium = {
    random_exits = false,
    max_total_branches = 8,
    branch_chance = 0.66,
    max_branches_per_room = 1,
    min_hallways = 1,
    max_hallways = 1,
    max_branch_length = 6,
    min_space_score = 5,
    allow_recursive = false,
    recursive_chance = 0.0,
    max_depth = 1,
}

Knossos.MODE_CONFIGS.large = {
    random_exits = false,
    max_total_branches = 14,
    branch_chance = 0.85,
    max_branches_per_room = 3,
    min_hallways = 1,
    max_hallways = 2,
    max_branch_length = 8,
    min_space_score = 4,
    allow_recursive = true,
    recursive_chance = 0.2,
    max_depth = 2,
}

Knossos.MODE_CONFIGS.massive = {
    random_exits = true,
    max_total_branches = 25,
    branch_chance = 1.0,
    max_branches_per_room = 5,
    min_hallways = 1,
    max_hallways = 2,
    max_branch_length = 12,
    min_space_score = 3,
    allow_recursive = true,
    recursive_chance = 0.5,
    max_depth = 3,
}

Knossos.MODE_CONFIGS.labyrinth = {
    random_exits = true,
    max_total_branches = 50,
    branch_chance = 1.0,
    max_branches_per_room = 8,
    min_hallways = 1,
    max_hallways = 2,
    max_branch_length = 12,
    min_space_score = 2,
    allow_recursive = true,
    recursive_chance = 1.0,
    max_depth = 5,
}

Knossos.is_enabled = Knossos.CONFIG.enabled

Knossos.original_quilt_builder = {}

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)
    
    if path == "lua/dungeon/quilt_builder" then        
        result = Knossos.branch_quilt_builder()
    end

    return result
end)


-- Global function to return the custom quilt builder
function Knossos.branch_quilt_builder()
    local function quilt_error(fmt, ...)
        fmt = fmt or "Unknown quilt fail"

        error(sprintf("Quilt: " .. fmt, ...))
    end

    local function quilt_ensure(what, fmt, ...)
        if not what then
            quilt_error(fmt, ...)
        end
    end

    local assert = assert

    if _G.IS_DEV then
        function assert(what, fmt, ...)
            if not what then
                fmt = fmt or "quilt assert"

                error(sprintf("Quilt assert: " .. fmt, ...))
            end
        end
    end

    local TILE_SIZE = 8
    local MAX_COORD_METERS = 496
    local MAX_COORD_C = math.floor(MAX_COORD_METERS / 2)
    local GRID_WIDTH = 100000

    local function xy_to_id(x, y)
        return y * GRID_WIDTH + x
    end

    local function id_to_xy(id)
        local x = (id - GRID_WIDTH / 2) % GRID_WIDTH - GRID_WIDTH / 2
        local y = math.floor((id - x) / GRID_WIDTH)

        return x, y
    end

    local INV_DIR = table.make_bimap({
        3,
        4,
        l = "r",
        u = "d",
    })

    local function dir_iter()
        return coroutine.wrap(function ()
            coroutine.yield("u", 0, 1)
            coroutine.yield("r", 1, 0)
            coroutine.yield("d", 0, -1)
            coroutine.yield("l", -1, 0)
        end)
    end

    local function dir_offset(dir)
        if dir == "u" then
            return 0, 1
        end

        if dir == "r" then
            return 1, 0
        end

        if dir == "d" then
            return 0, -1
        end

        if dir == "l" then
            return -1, 0
        end

        quilt_ensure(false)
    end

    local function dir_to_cardinal(dir)
        if dir == "u" then
            return "north"
        end

        if dir == "r" then
            return "east"
        end

        if dir == "d" then
            return "south"
        end

        if dir == "l" then
            return "west"
        end

        quilt_ensure(false)
    end

    local function block_border_iter(x, y, tile)
        local w = tile.qw or tile.w
        local w, h = w, tile.qh or tile.h

        return coroutine.wrap(function ()
            local index = 0

            for i = 1, w do
                index = index + 1

                coroutine.yield("u", x + i - 1, y + h - 1, tile.u[i], tile.u_type[i], i, index)
            end

            for i = 1, h do
                index = index + 1

                coroutine.yield("r", x + w - 1, y + h - i, tile.r[i], tile.r_type[i], i, index)
            end

            for i = 1, w do
                index = index + 1

                coroutine.yield("d", x + w - i, y, tile.d[i], tile.d_type[i], i, index)
            end

            for i = 1, h do
                index = index + 1

                coroutine.yield("l", x, y + i - 1, tile.l[i], tile.l_type[i], i, index)
            end
        end)
    end

    local function cell_neighbor_iter(cell)
        return coroutine.wrap(function ()
            for dir, dx, dy in dir_iter() do
                coroutine.yield(dir, dx, dy, cell[dir])
            end
        end)
    end

    local function doorway_sorter(a, b)
        if a == b then
            return false
        elseif a.qx ~= b.qx then
            return a.qx < b.qx
        elseif a.qy ~= b.qy then
            return a.qy < b.qy
        elseif a.dir ~= b.dir then
            return a.dir < b.dir
        end
    end

    local function tile_sorter(a, b)
        if a == b then
            return false
        else
            return a.path < b.path
        end
    end

    local function set_to_sorted_list(s, sorter)
        local list = set.set_to_list(s)

        table.sort(list, sorter)

        return list
    end

    local function is_walkable(s)
        quilt_ensure(type(s) == "string" and #s == 1)

        return s == "e" or s == "i" or s == "o" or s == "g"
    end

    local function is_entrance(s)
        quilt_ensure(type(s) == "string" and #s == 1)

        return s == "e" or s == "i"
    end

    local function is_exit(s)
        quilt_ensure(type(s) == "string" and #s == 1)

        return s == "e" or s == "o"
    end

    local function unify_materials(s)
        return s:gsub("[eio]", "g")
    end

    QuiltBuilder = class("QuiltBuilder")

    QuiltBuilder.parse_tiles = function (self, tiles, target_set, tag)
        if not tiles then
            return
        end

        tiles = table.clone(tiles)

        local path_prefix = tiles.path

        tiles.path = nil

        local tile_defaults = tiles.defaults or {}

        tiles.defaults = nil

        for group_name, variants in pairs(tiles) do
            variants = table.clone(variants)

            local pattern_weight = variants.weight or 1

            variants.weight = nil

            local defaults = variants.defaults or tile_defaults or {}

            variants.defaults = nil

            for name, meta in pairs(variants) do
                local type_name, u, r, d, l, variant_name = name:match("^%w+_quilt_(%w+)__([^_]+)_([^_]+)_([^_]+)_([^_]+)__(.*)$")
                local w = #u
                local h = #r
                local short_name = type_name .. " - " .. variant_name

                meta = table.clone(meta)

                for k, v in pairs(defaults) do
                    if meta[k] == nil then
                        meta[k] = v
                    end
                end

                local tile = {
                    w = w,
                    h = h,
                    u = string.explode(unify_materials(u)),
                    r = string.explode(unify_materials(r)),
                    d = string.explode(unify_materials(d)),
                    l = string.explode(unify_materials(l)),
                    u_type = string.explode(u),
                    r_type = string.explode(r),
                    d_type = string.explode(d),
                    l_type = string.explode(l),
                    name = name,
                    short_name = short_name,
                    path = path_prefix .. name,
                    weight = pattern_weight * (meta.weight or 1),
                    supply = meta.supply or math.huge,
                    tag = tag,
                }

                tile.degree = 0

                for dir in dir_iter() do
                    local border = tile[dir]

                    for _, b in ipairs(border) do
                        if is_walkable(b) then
                            tile.degree = tile.degree + 1
                        end
                    end
                end

                for old_tile, _ in pairs(target_set) do
                    -- Nothing
                end

                target_set[tile] = true
            end
        end
    end

    QuiltBuilder.init = function (self, layout_node, seed)
        self._use_original = false
        
        self.layout_node = layout_node
        self.randomizer = Randomizer(seed)
        self.special_blocks = {}
        self.open_set = {}
        self.doorway_set = {}
        self.filler_tile_set = {}
        self.encounter_tile_set = {}
        self.entrance_tile_set = {}
        self.exit_tile_set = {}
        self.saferoom_tile_set = {}

        self:parse_tiles(layout_node.fillers, self.filler_tile_set, "filler")
        self:parse_tiles(layout_node.encounters, self.encounter_tile_set, "encounter")
        self:parse_tiles(layout_node.entrances, self.entrance_tile_set, "entrance")
        self:parse_tiles(layout_node.exits, self.exit_tile_set, "exit")
        self:parse_tiles(layout_node.saferooms, self.encounter_tile_set, "saferoom")

        -- Merge branch defaults with mode-specific settings and any layout_node overrides
        self.branch_config = {}
        
        -- Get mode-specific settings based on Knossos.CONFIG.mode
        local mode = Knossos.CONFIG.mode or "Small"
        local mode_key = string.lower(mode)
        local mode_settings = Knossos.MODE_CONFIGS[mode_key]
        
        -- print("[Knossos] Building quilt with mode: " .. mode .. " (key: " .. mode_key .. ")")
        
        -- Use mode settings as primary source, fallback to BRANCH_DEFAULTS only if mode not found
        if mode_settings then
            for k, v in pairs(mode_settings) do
                self.branch_config[k] = v
            end
            for k, v in pairs(Knossos.BRANCH_DEFAULTS) do
                if self.branch_config[k] == nil then
                    self.branch_config[k] = v
                end
            end
        else
            for k, v in pairs(Knossos.BRANCH_DEFAULTS) do
                self.branch_config[k] = v
            end
        end
        
        -- Allow layout_node.branch_config to override (highest priority)
        if layout_node.branch_config then
            for k, v in pairs(layout_node.branch_config) do
                self.branch_config[k] = v
            end
        end
        self.total_branches_spawned = 0
        self.needs_random_exit = false  -- Set true when random_exits is enabled and main path ends
        self.branch_endpoints = {}      -- Track {block, depth} for random exit placement
    end

    local function center_quilt(quilt)
        local min_qx, min_qy = math.huge, math.huge
        local max_qx, max_qy = -math.huge, -math.huge
        local min_x, min_y = math.huge, math.huge
        local max_x, max_y = -math.huge, -math.huge

        for _, block in ipairs(quilt.blocks) do
            min_qx = math.min(min_qx, block.qx)
            min_qy = math.min(min_qy, block.qy)
            max_qx = math.max(max_qx, block.qx + block.qw)
            max_qy = math.max(max_qy, block.qy + block.qh)
            min_x = math.min(min_x, block.x)
            min_y = math.min(min_y, block.y)
            max_x = math.max(max_x, block.x + block.w)
            max_y = math.max(max_y, block.y + block.h)
        end

        local qw = max_qx - min_qx
        local qh = max_qy - min_qy
        local delta_qx = math.floor(-min_qx - 0.5 * (max_qx - min_qx))
        local delta_qy = math.floor(-min_qy - 0.5 * (max_qy - min_qy))
        local delta_x = delta_qx * TILE_SIZE
        local delta_y = delta_qy * TILE_SIZE

        for _, block in ipairs(quilt.blocks) do
            block.qx = block.qx + delta_qx
            block.qy = block.qy + delta_qy
            block.x = block.x + delta_x
            block.y = block.y + delta_y

            local x, y = block.x, block.y
            local w, h = block.w, block.h

            if x <= -MAX_COORD_C or MAX_COORD_C <= x + w or y <= -MAX_COORD_C or MAX_COORD_C <= y + h then
                quilt_error("Quilt too big (outside of MAX_COORD_METERS=%d). Width: %d, height: %d", MAX_COORD_METERS, qw * TILE_SIZE * 2, qh * TILE_SIZE * 2)
            end
        end
    end

    QuiltBuilder.build = function (self, cluster, cluster_x, cluster_y)
        self.cluster = cluster
        self.cluster_x = cluster_x
        self.cluster_y = cluster_y

        local quilt = {
            blocks = {},
        }

        if _G.IS_DEV then
            quilt.builder = self
        end

        cluster.quilt = quilt
        self.quilt = quilt
        self.grid = {}
        self.blocks = quilt.blocks


        self:build_quilt(cluster, cluster_x, cluster_y)
        center_quilt(quilt)

        return quilt
    end

    QuiltBuilder.build_quilt = function (self, cluster, cluster_x, cluster_y)
        local entrance_tile_list = set_to_sorted_list(self.entrance_tile_set, tile_sorter)
        local entrance_tile = self.randomizer:array_weighted_value(entrance_tile_list)
        local entrance_block = self:spawn_block(0, 0, entrance_tile)

        entrance_block.distance = 0
        self.entrance_block = entrance_block
        self.branch_queue = {}  -- Queue of {block, depth, branches_spawned}

        self:connect_seeds()

        -- Process all dead-end branches AFTER the main path is complete
        -- This ensures the main path has priority on tile supply and grid space
        self:process_branch_queue()

        -- Place random exit if enabled and needed
        if self.branch_config.random_exits and self.needs_random_exit then
            self:place_random_exit()
        end

        self:enclose()
    end

    -- Process the branch queue, supporting multiple branches per room and recursive branching.
    -- Entries are added by connect_seeds (main-path rooms) and optionally by this function
    -- itself when allow_recursive is true and a branch-end encounter room passes the chance roll.
    QuiltBuilder.process_branch_queue = function (self)
        local config = self.branch_config
        if not config.enabled then
            return
        end

        local queue_index = 1
        while queue_index <= #self.branch_queue do
            if self.total_branches_spawned >= config.max_total_branches then
                break
            end

            local entry = self.branch_queue[queue_index]
            local block = entry.block
            local depth = entry.depth

            if depth <= config.max_depth then
                for attempt = entry.branches_spawned + 1, config.max_branches_per_room do
                    if self.total_branches_spawned >= config.max_total_branches then
                        break
                    end

                    local result_block = self:spawn_dead_end_branch(block)
                    if result_block then
                        self.total_branches_spawned = self.total_branches_spawned + 1
                        entry.branches_spawned = attempt

                        -- Track endpoint for potential random exit placement
                        table.insert(self.branch_endpoints, {
                            block = result_block,
                            depth = depth,
                        })

                        -- Queue the new encounter for recursive branching if allowed
                        if config.allow_recursive and depth < config.max_depth then
                            if self.randomizer:random() < config.recursive_chance then
                                table.insert(self.branch_queue, {
                                    block = result_block,
                                    depth = depth + 1,
                                    branches_spawned = 0,
                                })
                            end
                        end
                    else
                        break  -- No more viable doors on this block
                    end
                end
            end

            queue_index = queue_index + 1
        end

        self.branch_queue = nil  -- Clean up
    end

    -- Find where an endpoint block connects to the rest of the quilt
    -- Returns {spawn_x, spawn_y, entrance_dir} or nil
    QuiltBuilder.find_endpoint_connection_info = function (self, endpoint_block)
        for dir, bx, by, material in block_border_iter(endpoint_block.qx, endpoint_block.qy, endpoint_block) do
            if is_walkable(material) then
                local dx, dy = dir_offset(dir)
                local adj_x, adj_y = bx + dx, by + dy
                local adj_id = xy_to_id(adj_x, adj_y)
                local adj_cell = self.grid[adj_id]
                if adj_cell and adj_cell.block and adj_cell.block ~= endpoint_block then
                    -- (bx, by) is the cell of endpoint that connects to filler
                    -- After removing endpoint, (bx, by) will be empty
                    -- entrance_dir is the direction FROM the connection point TO the filler
                    return {
                        spawn_x = bx,
                        spawn_y = by,
                        entrance_dir = dir,
                    }
                end
            end
        end
        return nil
    end

    -- Try to replace an encounter block with an exit tile
    -- Returns true on success, false on failure
    QuiltBuilder.try_replace_with_exit = function (self, endpoint_block)
        local conn_info = self:find_endpoint_connection_info(endpoint_block)
        if not conn_info then
            return false
        end

        local qx, qy = endpoint_block.qx, endpoint_block.qy

        -- Remove the current encounter block
        self:remove_block(endpoint_block)

        -- Try to find and spawn an exit tile at the connection point
        local exit_q = {
            exit = true,
            lowest_degree = true,
            w = "*",
            h = "*",
        }
        local exit_tile = self:try_find_tile(conn_info.spawn_x, conn_info.spawn_y, exit_q)

        if not exit_tile then
            -- No exit tile found, attempt to restore encounter
            -- This is a simplified fallback - just try to place any encounter
            local restore_q = {
                room = true,
                lowest_degree = true,
                w = "*",
                h = "*",
            }
            local restore_tile = self:try_find_tile(conn_info.spawn_x, conn_info.spawn_y, restore_q)
            if restore_tile then
                local restore_block = self:try_spawning_block_here(conn_info.spawn_x, conn_info.spawn_y, restore_tile)
                if restore_block then
                    restore_block.is_dead_end = true
                    self:seal_block_exits(restore_block, conn_info.entrance_dir)
                end
            end
            return false
        end

        local exit_block = self:try_spawning_block_here(conn_info.spawn_x, conn_info.spawn_y, exit_tile)

        if not exit_block then
            -- Failed to spawn exit, try to restore encounter
            local restore_q = {
                room = true,
                lowest_degree = true,
                w = "*",
                h = "*",
            }
            local restore_tile = self:try_find_tile(conn_info.spawn_x, conn_info.spawn_y, restore_q)
            if restore_tile then
                local restore_block = self:try_spawning_block_here(conn_info.spawn_x, conn_info.spawn_y, restore_tile)
                if restore_block then
                    restore_block.is_dead_end = true
                    self:seal_block_exits(restore_block, conn_info.entrance_dir)
                end
            end
            return false
        end

        -- Remove the endpoint from tracking since it's now an exit
        for i = #self.branch_endpoints, 1, -1 do
            if self.branch_endpoints[i].block == endpoint_block then
                table.remove(self.branch_endpoints, i)
                break
            end
        end

        return true
    end

    -- Place the exit at a random branch endpoint (preferring deeper branches)
    QuiltBuilder.place_random_exit = function (self)
        if #self.branch_endpoints == 0 then
            -- No branches created - this shouldn't happen if random_exits is working
            -- The main path end was placed as an encounter, but no branches were created
            -- Fall back: find the main path end encounter and try to replace it
            return
        end

        -- Group endpoints by depth
        local endpoints_by_depth = {}
        for _, ep in ipairs(self.branch_endpoints) do
            endpoints_by_depth[ep.depth] = endpoints_by_depth[ep.depth] or {}
            table.insert(endpoints_by_depth[ep.depth], ep)
        end

        -- Get sorted list of depths (deepest first, as recursive branches have higher depth)
        local depths = {}
        for d, _ in pairs(endpoints_by_depth) do
            table.insert(depths, d)
        end
        table.sort(depths, function(a, b) return a > b end)  -- Sort descending (deepest first)

        -- Try depths from deepest to shallowest
        for _, d in ipairs(depths) do
            local candidates = endpoints_by_depth[d]

            -- Shuffle candidates at this depth for randomness
            for j = #candidates, 2, -1 do
                local k = self.randomizer:random(1, j)
                candidates[j], candidates[k] = candidates[k], candidates[j]
            end

            -- Try each candidate
            for _, ep in ipairs(candidates) do
                if self:try_replace_with_exit(ep.block) then
                    return  -- Success!
                end
            end
        end

        -- Could not place exit on any branch endpoint
        -- This is a fallback situation - the quilt will not have an exit
    end

    QuiltBuilder.prune_open_cells = function (self)
        for doorway, _ in pairs(self.doorway_set) do
            for cell_id, _ in pairs(doorway.open_cells) do
                if not self.open_set[cell_id] then
                    doorway.open_cells[cell_id] = nil
                end
            end
        end
    end

    QuiltBuilder.dist_to_doorway = function (self, doorways, cell_id, ignore_block)
        local cx, cy = id_to_xy(cell_id)
        local smallest_dist_sq = math.huge

        for _, doorway in ipairs(doorways) do
            if doorway.block ~= ignore_block then
                local dx = doorway.qx - cx
                local dy = doorway.qy - cy
                local dist_sq = dx * dx + dy * dy

                smallest_dist_sq = math.min(dist_sq, smallest_dist_sq)
            end
        end

        return math.sqrt(smallest_dist_sq)
    end

    QuiltBuilder.extract_next_doorway = function (self)
        local randomizer = self.randomizer
        local doorways = {}

        for doorway, _ in pairs(self.doorway_set) do
            if not table.empty(doorway.open_cells) then
                doorways[#doorways + 1] = doorway
            end
        end

        if #doorways == 0 then
            return nil
        end

        table.sort(doorways, doorway_sorter)

        local closest_distance = math.huge
        local cell_id_to_doorway = {}
        local PICK_CLOSEST_TO_START = false

        if PICK_CLOSEST_TO_START then
            for _, doorway in ipairs(doorways) do
                for cell_id, distance in pairs(doorway.open_cells) do
                    if distance < closest_distance then
                        closest_distance = distance
                        cell_id_to_doorway = {
                            [cell_id] = doorway,
                        }
                    elseif distance == closest_distance then
                        cell_id_to_doorway[cell_id] = doorway
                    end
                end
            end
        else
            for _, doorway in ipairs(doorways) do
                for cell_id, source_dist in pairs(doorway.open_cells) do
                    local target_dist = self:dist_to_doorway(doorways, cell_id, doorway.block)
                    local distance = target_dist + source_dist
                    local SPREAD = 2

                    distance = distance + randomizer:rangef(-SPREAD, SPREAD)

                    if distance < closest_distance then
                        closest_distance = distance
                        cell_id_to_doorway = {}
                    end

                    if distance == closest_distance then
                        cell_id_to_doorway[cell_id] = doorway
                    end
                end
            end
        end

        local list = {}

        for cell_id, doorway in pairs(cell_id_to_doorway) do
            local source_dist = doorway.open_cells[cell_id]

            list[#list + 1] = {
                cell_id,
                doorway,
                source_dist,
            }
        end

        table.sort(list, function (a, b)
            return a[1] < b[1]
        end)

        return unpack(randomizer:array_value(list))
    end

    QuiltBuilder.should_debug_print = function (self)
        return false
    end

    QuiltBuilder.connect_seeds = function (self)
        local randomizer = self.randomizer
        local layout_node = self.layout_node
        local min_spacing = layout_node.min_spacing + 1
        local max_spacing = layout_node.max_spacing + 1
        local num_target_rooms = randomizer(layout_node.min_rooms, layout_node.max_rooms)
        local num_spawned_rooms = 0
        local has_exit = false

        while not has_exit do
            if self:should_debug_print() then
                -- Nothing
            end

            self:prune_open_cells()

            local cell_id, doorway, source_dist = self:extract_next_doorway()

            if not cell_id then
                quilt_ensure(false, "Failed to connect start room with every other special room")

                return false
            end

            local x, y = id_to_xy(cell_id)
            local chance_of_room = 0

            if max_spacing < source_dist then
                quilt_error("Failed to find a fitting room in time")
            end

            if max_spacing <= source_dist then
                chance_of_room = 1
            elseif min_spacing <= source_dist then
                chance_of_room = 1 / (max_spacing - source_dist)
            else
                chance_of_room = 0
            end

            local q = {
                dont_repeat_neighbors = true,
                h = "*",
                prevent_spreading = true,
                w = "*",
            }
            local tile

            if chance_of_room > randomizer:random() then
                if num_spawned_rooms < num_target_rooms then
                    q.room = true
                    tile = self:try_find_tile(x, y, q)

                    if tile and (not self:should_debug_print() or true) then
                        num_spawned_rooms = num_spawned_rooms + 1
                    end
                else
                    -- Check if we should randomize exit placement
                    if self.branch_config.random_exits then
                        -- Place an encounter (dead-end) instead of exit at main path end
                        q.room = true
                        tile = self:try_find_tile(x, y, q)
                        if tile then
                            self.needs_random_exit = true
                            has_exit = true  -- Mark as done so loop ends
                        end
                    else
                        q.exit = true
                        tile = self:try_find_tile(x, y, q)

                        if tile then
                            has_exit = true
                        end
                    end
                end
            end

            if not tile then
                q.room = false
                q.exit = false
                tile = self:try_find_tile(x, y, q)
            end

            quilt_ensure(tile, "Failed to find a quilt tile for <%d,%d>", x, y)

            local block = self:try_spawning_block_here(x, y, tile)

            -- If random_exits is on and this is the main path end encounter, seal it as a dead-end
            -- and queue it for branching so Knossos handles exit placement through branches
            if self.needs_random_exit and q.room and block then
                block.is_dead_end = true
                -- Find the entrance direction (where we came from)
                local entrance_dir = nil
                for dir, bx, by, material in block_border_iter(block.qx, block.qy, block) do
                    if is_walkable(material) then
                        local dx, dy = dir_offset(dir)
                        local adj_id = xy_to_id(bx + dx, by + dy)
                        local adj_cell = self.grid[adj_id]
                        if adj_cell and adj_cell.block and adj_cell.block ~= block then
                            entrance_dir = dir
                            break
                        end
                    end
                end
                if entrance_dir then
                    self:seal_block_exits(block, entrance_dir)
                end
                -- Queue for branching so exit can be placed on a branch from here
                table.insert(self.branch_queue, {
                    block = block,
                    depth = 1,
                    branches_spawned = 0,
                })
            -- Queue encounter rooms on the main path for potential dead-end branches
            elseif q.room and block and not block.is_dead_end then
                if self.randomizer:random() < self.branch_config.branch_chance then
                    table.insert(self.branch_queue, {
                        block = block,
                        depth = 1,
                        branches_spawned = 0,
                    })
                end
            end
        end
    end

    -- Helper: Check if a tile border is entirely walls (no walkable cells)
    local function is_border_all_walls(tile, dir)
        for _, mat in ipairs(tile[dir]) do
            if is_walkable(mat) then
                return false
            end
        end
        return true
    end

    -- Helper: Check if a tile border has any walkable cells
    local function border_has_walkable(tile, dir)
        for _, mat in ipairs(tile[dir]) do
            if is_walkable(mat) then
                return true
            end
        end
        return false
    end

    -- Find entrance tiles that can work as dead-ends (only one side has walkable cells)
    -- required_open_dir: the direction that MUST have a walkable opening (to connect to filler)
    QuiltBuilder.find_dead_end_entrance_tiles = function (self, required_open_dir)
        local matches = {}
        
        for tile, _ in pairs(self.entrance_tile_set) do
            if tile.supply > 0 then
                -- Count how many sides have walkable cells
                local walkable_sides = 0
                local walkable_dir = nil
                
                for dir in dir_iter() do
                    if border_has_walkable(tile, dir) then
                        walkable_sides = walkable_sides + 1
                        walkable_dir = dir
                    end
                end
                
                -- Perfect dead-end: exactly 1 side with walkable cells
                -- AND that side must match required_open_dir (or no requirement)
                if walkable_sides == 1 then
                    if not required_open_dir or walkable_dir == required_open_dir then
                        matches[#matches + 1] = tile
                    end
                end
            end
        end
        
        table.sort(matches, tile_sorter)
        return matches
    end

    -- Helper function to count free cells in a direction (used to prefer directions with more space)
    QuiltBuilder.count_free_space_in_direction = function (self, start_x, start_y, dir, max_depth)
        max_depth = max_depth or 5
        local dx, dy = dir_offset(dir)
        local free_count = 0
        
        for depth = 1, max_depth do
            local check_x = start_x + dx * depth
            local check_y = start_y + dy * depth
            
            -- Check a 3x3 area around the target point
            for ox = -1, 1 do
                for oy = -1, 1 do
                    local cell_id = xy_to_id(check_x + ox, check_y + oy)
                    if not self.grid[cell_id] then
                        free_count = free_count + 1
                    end
                end
            end
        end
        
        return free_count
    end
    
    -- Helper function to check if a room (entrance or encounter) can fit at a position
    QuiltBuilder.can_any_room_fit = function (self, x, y, entrance_dir)
        -- Check entrance tiles
        local entrance_tiles = self:find_dead_end_entrance_tiles(entrance_dir)
        for _, tile in ipairs(entrance_tiles) do
            local pos = self:position_tile(x, y, tile)
            if pos and self:can_fit_tile_here(pos.x, pos.y, tile) then
                return true
            end
        end
        
        -- Check encounter tiles (excluding saferooms for branch dead-ends)
        local encounter_q = {
            room = true,
            w = "*",
            h = "*",
            exclude_tags = {"saferoom"},
        }
        local encounter_tiles = self:find_tiles(encounter_q)
        for _, tile in ipairs(encounter_tiles) do
            local pos = self:position_tile(x, y, tile)
            if pos and self:can_fit_tile_here(pos.x, pos.y, tile) then
                return true
            end
        end
        
        return false
    end
    
    -- Check if a 2x2 area is completely free at the given position
    QuiltBuilder.is_2x2_free = function (self, x, y)
        for ox = 0, 1 do
            for oy = 0, 1 do
                local cell_id = xy_to_id(x + ox, y + oy)
                if self.grid[cell_id] then
                    return false
                end
            end
        end
        return true
    end
    
    -- Calculate space score for a direction from a door position
    -- Returns nil if not enough space (no 2x2 area), otherwise returns a score (higher = more space)
    QuiltBuilder.calculate_branch_space = function (self, door_bx, door_by, dir)
        local dx, dy = dir_offset(dir)
        local start_x = door_bx + dx
        local start_y = door_by + dy
        
        -- First check: immediate adjacent cell must be free
        local start_id = xy_to_id(start_x, start_y)
        if self.grid[start_id] then
            return nil
        end
        
        -- Check for at least one 2x2 free area within reach (depth 1-3)
        local found_2x2 = false
        local CHECK_DEPTH = 4
        
        for depth = 1, CHECK_DEPTH do
            local check_x = start_x + dx * (depth - 1)
            local check_y = start_y + dy * (depth - 1)
            
            -- Check 2x2 areas around this position (offset to find any valid 2x2)
            for ox = -1, 0 do
                for oy = -1, 0 do
                    if self:is_2x2_free(check_x + ox, check_y + oy) then
                        found_2x2 = true
                        break
                    end
                end
                if found_2x2 then break end
            end
            if found_2x2 then break end
        end
        
        if not found_2x2 then
            -- print("    Direction", dir, "- no 2x2 free area found")
            return nil
        end
        
        -- Calculate total free space score (more free cells = higher score)
        local free_count = 0
        local CHECK_WIDTH = 2
        
        for depth = 1, CHECK_DEPTH do
            local check_x = start_x + dx * depth
            local check_y = start_y + dy * depth
            
            -- Check cells perpendicular to direction as well
            for offset = -CHECK_WIDTH, CHECK_WIDTH do
                local ox, oy = 0, 0
                if dir == "u" or dir == "d" then
                    ox = offset
                else
                    oy = offset
                end
                
                local cell_id = xy_to_id(check_x + ox, check_y + oy)
                if not self.grid[cell_id] then
                    free_count = free_count + 1
                end
            end
        end
        
        -- print("    Direction", dir, "- space score:", free_count)
        return free_count
    end
    
    -- Find the best door to use for branching
    -- Returns the door with the most space, or nil if no door has enough space
    QuiltBuilder.find_best_branch_door = function (self, possible_doors)
        local best_door = nil
        local best_score = 0
        local MIN_SCORE = self.branch_config.min_space_score
        
        -- print("Evaluating doors for branch space...")
        
        for _, door in ipairs(possible_doors) do
            local score = self:calculate_branch_space(door.bx, door.by, door.dir)
            if score and score >= MIN_SCORE and score > best_score then
                best_door = door
                best_score = score
            end
        end
        
        if best_door then
            -- print("Best door:", best_door.dir, "with score:", best_score)
        else
            -- print("No door has enough space for a branch")
        end
        
        return best_door
    end
    
    -- Remove a block from the quilt (for culling failed branches)
    QuiltBuilder.remove_block = function (self, block)
        -- print("Removing block:", block.name)
        
        -- Restore tile supply
        block.tile.supply = block.tile.supply + 1
        
        -- Remove from blocks list
        for i = #self.blocks, 1, -1 do
            if self.blocks[i] == block then
                table.remove(self.blocks, i)
                break
            end
        end
        
        -- Clear grid cells occupied by this block
        local w, h = block.tile.w, block.tile.h
        for oy = 0, h - 1 do
            for ox = 0, w - 1 do
                local cell_id = xy_to_id(block.qx + ox, block.qy + oy)
                self.grid[cell_id] = nil
            end
        end
        
        -- Remove from special_blocks if present
        self.special_blocks[block] = nil
        
        -- Clean up doorway references
        if block.doorways then
            for _, doorway in ipairs(block.doorways) do
                self.doorway_set[doorway] = nil
            end
        end
        
        -- print("Block removed successfully")
    end

    QuiltBuilder.spawn_dead_end_branch = function (self, first_encounter_block)
        -- print("Spawn dead-end branch started for block:", first_encounter_block.name)
        
        -- First, collect all possible doors we could open
        -- A door can be opened if it's currently closed ("x") but the material_type indicates
        -- it could be walkable (e, i, o - any door type, not just exits)
        local possible_doors = {}
        local all_closed_doors = {}  -- For debugging
        
        for dir, bx, by, material, material_type, dir_index, index in block_border_iter(first_encounter_block.qx, first_encounter_block.qy, first_encounter_block) do
            -- Check if this is a closed door that could be opened
            -- material == "x" means currently closed, is_walkable(material_type) means it's a valid door
            if material == "x" and is_walkable(material_type) then
                local dx, dy = dir_offset(dir)
                local adj_id = xy_to_id(bx + dx, by + dy)
                local adj_free = not self.grid[adj_id]
                
                table.insert(all_closed_doors, {dir = dir, free = adj_free, material_type = material_type})
                
                if adj_free then
                    table.insert(possible_doors, {
                        dir = dir,
                        bx = bx,
                        by = by,
                        dir_index = dir_index,
                        original_material = first_encounter_block.tile[dir][dir_index]
                    })
                end
            end
        end
        
        -- Debug: show what doors exist and which are blocked
        -- print("All closed doors on block:")
        for _, door in ipairs(all_closed_doors) do
            -- print("  Dir:", door.dir, "Adjacent free:", door.free)
        end
        
        if #possible_doors == 0 then
            -- print("No available doors to open (all adjacent cells occupied)")
            return
        end
        
        -- print("Found", #possible_doors, "possible doors. Finding best direction...")
        
        -- Find the best door (most space available)
        local chosen_door = self:find_best_branch_door(possible_doors)
        
        if not chosen_door then
            -- print("No doors have enough space for a branch - aborting")
            return
        end
        
        local chosen_dir = chosen_door.dir
        local chosen_bx = chosen_door.bx
        local chosen_by = chosen_door.by
        local chosen_dir_index = chosen_door.dir_index
        local original_material = chosen_door.original_material
        
        -- Force this door open
        first_encounter_block[chosen_dir][chosen_dir_index] = original_material
        
        -- Remove the "closed" marker and add "open" marker
        local cardinal_dir = dir_to_cardinal(chosen_dir)
        local closed_marker = sprintf("%s%d_closed", cardinal_dir, chosen_dir_index)
        local open_marker = sprintf("%s%d_open", cardinal_dir, chosen_dir_index)
        
        -- Remove closed marker if it exists
        for i = #first_encounter_block.object_sets, 1, -1 do
            if first_encounter_block.object_sets[i] == closed_marker then
                table.remove(first_encounter_block.object_sets, i)
                -- print("  Removed closed marker:", closed_marker)
            end
        end
        
        -- Add open marker
        table.insert(first_encounter_block.object_sets, open_marker)
        -- print("  Added open marker:", open_marker)
        
        -- Update the grid cell
        local cell_id = xy_to_id(chosen_bx, chosen_by)
        local cell = self.grid[cell_id]
        if cell and cell[chosen_dir] then
            cell[chosen_dir].material = original_material
            -- If doorway exists, update open_cells
            if cell[chosen_dir].doorway then
                local dx, dy = dir_offset(chosen_dir)
                local open_id = xy_to_id(chosen_bx + dx, chosen_by + dy)
                cell[chosen_dir].doorway.open_cells[open_id] = 1  -- add as open
            end
        end
        
        -- print("Forced open door in direction:", chosen_dir, "at", chosen_bx, chosen_by)

        -- Keep track of filler blocks spawned (so we can potentially remove them if branch fails)
        local filler_blocks = {}
        local current_block = first_encounter_block
        local current_dir = chosen_dir
        local branch_cfg = self.branch_config
        local MAX_BRANCH_LENGTH = branch_cfg.max_branch_length
        local MIN_HALLWAYS = branch_cfg.min_hallways
        local MAX_HALLWAYS = branch_cfg.max_hallways
        
        for branch_iteration = 1, MAX_BRANCH_LENGTH do
            -- print("Branch iteration:", branch_iteration)
            
            -- Find the next position to spawn at
            local next_dirs = {}
            for dir2, bx, by, material, material_type in block_border_iter(current_block.qx, current_block.qy, current_block) do
                -- Only consider directions that aren't going backwards
                local is_backwards = (branch_iteration == 1 and dir2 == INV_DIR[current_dir]) or
                                     (branch_iteration > 1 and dir2 == INV_DIR[current_dir])
                if not is_backwards and is_walkable(material) then
                    local dx2, dy2 = dir_offset(dir2)
                    local adj_x = bx + dx2
                    local adj_y = by + dy2
                    local adj_id = xy_to_id(adj_x, adj_y)
                    if not self.grid[adj_id] then
                        -- Calculate free space score for this direction
                        local free_space = self:count_free_space_in_direction(adj_x, adj_y, dir2, 5)
                        table.insert(next_dirs, {x = adj_x, y = adj_y, dir = dir2, bx = bx, by = by, free_space = free_space})
                    end
                end
            end
            
            if #next_dirs == 0 then
                -- print("No free directions available at iteration", branch_iteration)
                break
            end
            
            -- Shuffle directions for variety
            for i = #next_dirs, 2, -1 do
                local j = self.randomizer:random(1, i)
                next_dirs[i], next_dirs[j] = next_dirs[j], next_dirs[i]
            end
            
            local num_hallways = #filler_blocks
            
            -- HALLWAY REQUIREMENT: Must have at least MIN_HALLWAYS before placing encounter
            -- After MAX_HALLWAYS, we must try to place encounter (no more hallways allowed)
            local can_place_encounter = num_hallways >= MIN_HALLWAYS
            local must_place_encounter = num_hallways >= MAX_HALLWAYS
            
            -- print("Hallways placed:", num_hallways, "Can place encounter:", can_place_encounter, "Must place encounter:", must_place_encounter)
            
            -- Try to place an encounter room if we've met the minimum hallway requirement
            if can_place_encounter then
                -- print("Trying to place encounter room in", #next_dirs, "directions...")
                
                for _, dir_info in ipairs(next_dirs) do
                    local test_entrance_dir = INV_DIR[dir_info.dir]
                    
                    -- Try to place encounter room at this position
                    local dead_end_q = {
                        room = true,
                        lowest_degree = true,
                        w = "*",
                        h = "*",
                        exclude_tags = {
                            "saferoom" -- Culls crypt room that doesn't close doors.
                        },
                        exclude_names = {
                            "caves_quilt_mediumroom__xox_xex_xix_xex__04_civilization", -- Causes softlock Northward
                            "caves_quilt_mediumroom__xox_xex_xix_xex__04_spider", -- Causes softlock Northward
                        },
                    }
                    local dead_end_tile = self:try_find_tile(dir_info.x, dir_info.y, dead_end_q)
                    if dead_end_tile then
                        -- print("Found encounter tile for direction", dir_info.dir, ":", dead_end_tile.name)
                        local spawned_block = self:try_spawning_block_here(dir_info.x, dir_info.y, dead_end_tile)
                        if spawned_block then
                            spawned_block.is_dead_end = true
                            self:seal_block_exits(spawned_block, test_entrance_dir)
                            return spawned_block  -- Success: return the encounter block
                        end
                    end
                end
                
                -- If we MUST place an encounter but couldn't, branch fails
                if must_place_encounter then
                    -- print("Reached max hallways but couldn't place encounter room - branch cannot continue")
                    break
                end
            end
            
            -- Need to extend with filler (either haven't met minimum hallways, or no room fits yet)
            -- print("Extending branch with hallway... (hallway", num_hallways + 1, "of max", MAX_HALLWAYS, ")")
            
            -- Pick direction with most free space for extending
            table.sort(next_dirs, function(a, b) return a.free_space > b.free_space end)
            local next_pos = next_dirs[1]
            local entrance_dir = INV_DIR[next_pos.dir]
            -- print("Extending in direction:", next_pos.dir, "free_space:", next_pos.free_space)
            
            local filler_q = {
                room = false,
                exit = false,
                w = "*",
                h = "*",
                max_degree = 4,  -- Allow higher degree fillers for more options
            }
            local filler_tile = self:try_find_tile(next_pos.x, next_pos.y, filler_q)
            if not filler_tile then
                -- print("No filler tile available - branch cannot continue")
                break
            end
            
            local filler_block = self:try_spawning_block_here(next_pos.x, next_pos.y, filler_tile)
            if not filler_block then
                -- print("Failed to spawn filler block - branch cannot continue")
                break
            end
            
            -- print("Placed hallway:", filler_tile.name)
            table.insert(filler_blocks, filler_block)
            current_block = filler_block
            current_dir = next_pos.dir
        end
        
        -- If we get here, we couldn't place an encounter room
        -- CULL THE ENTIRE BRANCH - remove all filler blocks and close the door
        -- print("Branch failed to place encounter room - culling entire branch")
        
        -- Remove all filler blocks in reverse order
        for i = #filler_blocks, 1, -1 do
            self:remove_block(filler_blocks[i])
        end
        
        -- Close the door we forced open on the first encounter block
        -- print("Closing the door we forced open")
        
        first_encounter_block[chosen_dir][chosen_dir_index] = "x"
        
        -- Update grid
        local cell_id = xy_to_id(chosen_bx, chosen_by)
        local cell = self.grid[cell_id]
        if cell and cell[chosen_dir] then
            cell[chosen_dir].material = "x"
            -- Remove from doorway tracking
            if cell[chosen_dir].doorway and cell[chosen_dir].doorway.open_cells then
                local dx, dy = dir_offset(chosen_dir)
                local open_id = xy_to_id(chosen_bx + dx, chosen_by + dy)
                cell[chosen_dir].doorway.open_cells[open_id] = nil
            end
        end
        
        -- Remove open marker and add closed marker
        local cardinal_dir2 = dir_to_cardinal(chosen_dir)
        local open_marker2 = sprintf("%s%d_open", cardinal_dir2, chosen_dir_index)
        local closed_marker2 = sprintf("%s%d_closed", cardinal_dir2, chosen_dir_index)
        
        for i = #first_encounter_block.object_sets, 1, -1 do
            if first_encounter_block.object_sets[i] == open_marker2 then
                table.remove(first_encounter_block.object_sets, i)
                -- print("  Removed open marker:", open_marker2)
            end
        end
        table.insert(first_encounter_block.object_sets, closed_marker2)
        return nil  -- Branch failed, all filler culled
    end

    -- Helper function to seal all exits except the connected entrance
    QuiltBuilder.seal_block_exits = function (self, block, entrance_dir)
        -- print("Sealing extra exits on block...")
        for dir, bx, by, material, material_type, dir_index in block_border_iter(block.qx, block.qy, block) do
            -- Check if this cell has a neighbor (is connected to something)
            local dx, dy = dir_offset(dir)
            local neighbor_id = xy_to_id(bx + dx, by + dy)
            local has_neighbor = self.grid[neighbor_id] ~= nil
            
            -- For entrance direction: only keep open if connected to a neighbor
            -- For other directions: always seal
            local should_seal = false
            if dir == entrance_dir then
                -- On entrance side, only seal if NOT connected to a neighbor
                if not has_neighbor and is_walkable(material) then
                    should_seal = true
                end
            else
                -- On non-entrance sides, seal everything
                should_seal = true
            end
            
            if should_seal then
                -- Check if this is a potential door position (material_type is walkable)
                -- This includes both currently-open doors AND already-closed doors that have doorway visuals
                local is_potential_door = is_walkable(material_type)
                local is_currently_open = is_walkable(material)
                
                if is_currently_open then
                    -- Close this opening by marking it as wall
                    block[dir][dir_index] = "x"
                    
                    -- Update the grid cell to reflect it's now a wall
                    local cell_id = xy_to_id(bx, by)
                    local cell = self.grid[cell_id]
                    if cell and cell[dir] then
                        cell[dir].material = "x"
                    end
                    
                    -- Remove from any doorway tracking
                    if cell and cell[dir] and cell[dir].doorway then
                        local dx2, dy2 = dir_offset(dir)
                        local open_id = xy_to_id(bx + dx2, by + dy2)
                        if cell[dir].doorway.open_cells then
                            cell[dir].doorway.open_cells[open_id] = nil
                        end
                    end
                end
                
                -- Add closed object set marker for ANY potential door position (not just currently open ones)
                -- This ensures doorway visuals are removed even for already-closed doors
                if is_potential_door then
                    local cardinal = dir_to_cardinal(dir)
                    local closed_marker = sprintf("%s%d_closed", cardinal, dir_index)
                    local open_marker = sprintf("%s%d_open", cardinal, dir_index)
                    
                    -- Remove any existing open marker first
                    if block.object_sets then
                        for i = #block.object_sets, 1, -1 do
                            if block.object_sets[i] == open_marker then
                                table.remove(block.object_sets, i)
                            end
                        end
                        
                        -- Add closed marker if not already present
                        local has_closed_marker = false
                        for _, marker in ipairs(block.object_sets) do
                            if marker == closed_marker then
                                has_closed_marker = true
                                break
                            end
                        end
                        if not has_closed_marker then
                            table.insert(block.object_sets, closed_marker)
                        end
                    end
                    
                    local seal_reason = dir == entrance_dir and "(entrance side, no neighbor)" or (is_currently_open and "(was open)" or "(was already closed)")
                    -- print("  Sealed", dir, "side at border index", dir_index, seal_reason)
                end
            end
        end
        -- print("Block sealed successfully")
    end

    QuiltBuilder.enclose = function (self)
        local THICKNESS = 4
        local grid = self.grid

        for it = 1, THICKNESS do
            local open = {}

            for grid_id, cell in pairs(grid) do
                local x, y = id_to_xy(grid_id)

                for dir, dx, dy, material in cell_neighbor_iter(cell) do
                    if material ~= "w" then
                        local neigh_id = xy_to_id(x + dx, y + dy)

                        if not grid[neigh_id] then
                            open[#open + 1] = neigh_id
                        end
                    end
                end
            end

            table.sort(open)

            for _, grid_id in ipairs(open) do
                if grid[grid_id] == nil then
                    local x, y = id_to_xy(grid_id)
                    local q = {
                        lowest_degree = true,
                        max_degree = 0,
                        prefer_lava = true,
                    }

                    for dir, dx, dy in dir_iter() do
                        local neighbor = grid[xy_to_id(x + dx, y + dy)]

                        if neighbor then
                            local mat = neighbor[INV_DIR[dir]].material

                            if is_walkable(mat) then
                                q.max_degree = q.max_degree + 1
                            end
                        end
                    end

                    local tile = self:try_find_tile(x, y, q)

                    if tile then
                        local yield_time = 0.1

                        self:spawn_block(x, y, tile, yield_time)
                    end
                end
            end
        end
    end

    QuiltBuilder.can_fit_tile_here = function (self, x, y, tile)
        local w, h = tile.w, tile.h

        for oy = 0, h - 1 do
            for ox = 0, w - 1 do
                if self.grid[xy_to_id(x + ox, y + oy)] then
                    return false
                end
            end
        end

        for dir, bx, by, material in block_border_iter(x, y, tile) do
            local dx, dy = dir_offset(dir)
            local nx, ny = bx + dx, by + dy
            local neighbor = self.grid[xy_to_id(nx, ny)]

            if neighbor and neighbor[INV_DIR[dir]].material ~= material then
                return false
            end
        end

        return true
    end

    QuiltBuilder.position_tile = function (self, x, y, tile)
        local suggestions = {}

        for dx = 0, tile.w - 1 do
            for dy = 0, tile.h - 1 do
                if self:can_fit_tile_here(x - dx, y - dy, tile) then
                    suggestions[#suggestions + 1] = Vector2(x - dx, y - dy)
                end
            end
        end

        if #suggestions == 0 then
            return nil
        else
            return self.randomizer:array_value(suggestions)
        end
    end

    QuiltBuilder.try_spawning_block_here = function (self, x, y, tile)
        local pos = self:position_tile(x, y, tile)

        if pos then
            return self:spawn_block(pos.x, pos.y, tile)
        end
    end

    QuiltBuilder.connect_doorways = function (self, a, b)
        if not a or not b then
            return false
        end

        if a == b then
            return false
        end

        if a.neighbor_doorways[b] and b.neighbor_doorways[a] then
            return false
        end

        a.neighbor_doorways[b] = true
        b.neighbor_doorways[a] = true

        return true
    end

    QuiltBuilder.connect_edges = function (self, a, b)
        a.doorway = a.doorway or b.doorway
        b.doorway = b.doorway or a.doorway

        return self:connect_doorways(a.doorway, b.doorway)
    end

    QuiltBuilder.reanalyze_graph = function (self)
        repeat
            local did_update = false

            for block, _ in pairs(self.special_blocks) do
                for _, doorway_a in ipairs(block.doorways) do
                    for doorway_b, _ in pairs(doorway_a.neighbor_doorways) do
                        local block_b = doorway_b.block

                        if not block.neighbor_specials[block_b] then
                            did_update = true
                            block.neighbor_specials[block_b] = true
                            block_b.neighbor_specials[block] = true
                        end

                        for third_party, _ in pairs(block_b.reachable_specials) do
                            did_update = did_update or not block.reachable_specials[third_party]
                            block.reachable_specials[third_party] = true
                        end

                        for third_party, _ in pairs(block.reachable_specials) do
                            did_update = did_update or not block_b.reachable_specials[third_party]
                            block_b.reachable_specials[third_party] = true
                        end
                    end
                end
            end
        until not did_update
    end

    QuiltBuilder.spawn_block = function (self, x, y, tile)
        if self:should_debug_print() then
            -- Nothing
        end

        local MAX_BLOCKS = 1000

        quilt_ensure(MAX_BLOCKS > #self.blocks, "Too many blocks in quilt")

        tile.supply = tile.supply - 1

        local w, h = tile.w, tile.h
        local block = {
            tile = tile,
            path = tile.path,
            qx = x,
            qy = y,
            qw = tile.w,
            qh = tile.h,
            x = self.cluster_x + x * TILE_SIZE,
            y = self.cluster_x + y * TILE_SIZE,
            w = tile.w * TILE_SIZE,
            h = tile.h * TILE_SIZE,
            walkable_edges = {},
            name = sprintf("%s__%d_%d", tile.name, x, y),
            neighbor_blocks = {},
            distance = math.huge,
            in_direction = tile.in_direction,
            u = table.shallow_clone(tile.u),
            r = table.shallow_clone(tile.r),
            d = table.shallow_clone(tile.d),
            l = table.shallow_clone(tile.l),
            u_type = table.shallow_clone(tile.u_type),
            r_type = table.shallow_clone(tile.r_type),
            d_type = table.shallow_clone(tile.d_type),
            l_type = table.shallow_clone(tile.l_type),
            object_sets = {},
        }
        local original_inputs, original_outputs = {}, {}
        local available_inputs, available_outputs = {}, {}
        local finalized_inputs, finalized_outputs = {}, {}

        for dir, bx, by, material, material_type, dir_index, index in block_border_iter(x, y, tile) do
            local dx, dy = dir_offset(dir)
            local neigh_id = xy_to_id(bx + dx, by + dy)
            local neighbor_cell = self.grid[neigh_id]

            if is_entrance(material_type) then
                original_inputs[index] = true
                available_inputs[index] = true
            end

            if is_exit(material_type) then
                original_outputs[index] = true
                available_outputs[index] = true
            end

            if neighbor_cell then
                if is_entrance(material_type) then
                    finalized_inputs[index] = true
                    available_outputs[index] = nil
                elseif is_exit(material_type) then
                    finalized_outputs[index] = true
                    available_inputs[index] = nil
                end
            end
        end

        if next(finalized_inputs) == nil and next(available_inputs) then
            local available_inputs_list = set_to_sorted_list(available_inputs)
            local input_index = self.randomizer:array_value(available_inputs_list)

            finalized_inputs[input_index] = true
            available_outputs[input_index] = nil
        end

        if next(finalized_outputs) == nil and next(available_outputs) then
            local available_outputs_list = set_to_sorted_list(available_outputs)
            local output_index = self.randomizer:array_value(available_outputs_list)

            finalized_outputs[output_index] = true
            available_inputs[output_index] = nil
        end

        for dir, bx, by, material, material_type, dir_index, index in block_border_iter(x, y, block) do
            if finalized_inputs[index] and table.map_size(original_inputs) > 1 then
                table.insert(block.object_sets, sprintf("%s%d_open", dir_to_cardinal(dir), dir_index))
            elseif finalized_outputs[index] and table.map_size(original_outputs) > 1 then
                table.insert(block.object_sets, sprintf("%s%d_open", dir_to_cardinal(dir), dir_index))
            elseif is_entrance(material_type) and table.map_size(original_inputs) > 1 or is_exit(material_type) and table.map_size(original_outputs) > 1 then
                block[dir][dir_index] = "x"

                table.insert(block.object_sets, sprintf("%s%d_closed", dir_to_cardinal(dir), dir_index))
            end
        end

        if table.map_size(original_inputs) == 2 and table.shallow_equals(original_inputs, original_outputs) then
            block.object_sets = {}
        end

        if self.filler_tile_set[tile] == nil then
            self.special_blocks[block] = true
            block.is_special = true
            block.doorways = {}
            block.neighbor_specials = set.list_to_set({
                block,
            })
            block.reachable_specials = set.list_to_set({
                block,
            })
            block.distance = 0
        end

        for oy = 0, h - 1 do
            for ox = 0, w - 1 do
                local cell = {
                    tile = tile,
                    block = block,
                }
                local cell_id = xy_to_id(x + ox, y + oy)

                self.grid[cell_id] = cell
                self.open_set[cell_id] = nil
            end
        end

        local connectivity_changed = false
        local open_neighbors = {}
        local doorways = {}

        for dir, bx, by, material, material_type in block_border_iter(x, y, block) do
            local dx, dy = dir_offset(dir)
            local neigh_id = xy_to_id(bx + dx, by + dy)
            local neighbor_cell = self.grid[neigh_id]

            if neighbor_cell then
                local neighbor_material = neighbor_cell[INV_DIR[dir]].material

                quilt_ensure(material == neighbor_material, "Tile %q does not fit at <%d %d>", tile.name, x, y)
            end

            local border_cell_id = xy_to_id(bx, by)
            local cell = self.grid[border_cell_id]
            local edge = {
                material = material,
                dir = dir,
            }

            cell[dir] = edge

            if is_walkable(material) then
                table.insert(block.walkable_edges, edge)

                local doorway

                if block.is_special then
                    doorway = {
                        qx = bx + dx,
                        qy = by + dy,
                        dir = dir,
                        block = block,
                        neighbor_doorways = {},
                        open_cells = {},
                    }
                    self.doorway_set[doorway] = true

                    table.insert(block.doorways, doorway)

                    doorways[doorway] = true
                    cell[dir].doorway = doorway
                end

                if neighbor_cell then
                    local neigh_edge = neighbor_cell[INV_DIR[dir]]

                    connectivity_changed = self:connect_edges(edge, neigh_edge) or connectivity_changed

                    local neighbor_block = neighbor_cell.block

                    block.neighbor_blocks[neighbor_block] = true
                    neighbor_block.neighbor_blocks[block] = true
                    block.distance = math.min(block.distance, neighbor_block.distance + 1)

                    if neigh_edge.doorway then
                        neigh_edge.doorway.open_cells[border_cell_id] = nil
                        doorways[neigh_edge.doorway] = true
                    end
                else
                    self.open_set[neigh_id] = true
                    open_neighbors[neigh_id] = true

                    if doorway then
                        doorway.open_cells[neigh_id] = 1
                    end
                end
            end
        end

        if block.tile.degree > 0 then
            quilt_ensure(block.distance < 20, "Too far from doorway")
        end

        if not tile.is_disconnected then
            for i = 1, #block.walkable_edges do
                local edge_i = block.walkable_edges[i]

                for j = i + 1, #block.walkable_edges do
                    local edge_j = block.walkable_edges[j]

                    connectivity_changed = self:connect_edges(edge_i, edge_j) or connectivity_changed
                end
            end

            if not block.is_special then
                for doorway, _ in pairs(doorways) do
                    for cell_id, _ in pairs(open_neighbors) do
                        doorway.open_cells[cell_id] = math.min(block.distance + 1, doorway.open_cells[cell_id] or math.huge)
                    end
                end
            end
        end

        table.insert(self.blocks, block)

        if connectivity_changed then
            self:reanalyze_graph()
        end

        return block
    end

    function material_match(q, tile, dir)
        if q[dir] == "*" then
            return true
        end

        for ix, mat in ipairs(tile[dir]) do
            if q[dir] == mat then
                if q[dir] == "g" then
                    local door_type = tile[dir .. "_type"][ix]

                    if door_type == "i" or door_type == "e" then
                        tile.in_direction = dir

                        return true
                    else
                        return false
                    end
                else
                    return true
                end
            end
        end

        return false
    end

    QuiltBuilder.find_tiles = function (self, q)
        local min_degree = q.min_degree or 0
        local max_degree = q.max_degree or math.huge
        local source_set

        if q.room then
            source_set = self.encounter_tile_set
        elseif q.exit then
            source_set = self.exit_tile_set
        elseif q.entrance then
            source_set = self.entrance_tile_set
        else
            source_set = self.filler_tile_set
        end

        if self:should_debug_print() then
            -- Nothing
        end

        local matches = {}

        for t, _ in pairs(source_set) do
            -- Check if tile's tag is excluded
            local tag_excluded = false
            if q.exclude_tags and t.tag then
                for _, excluded_tag in ipairs(q.exclude_tags) do
                    if t.tag == excluded_tag then
                        tag_excluded = true
                        break
                    end
                end
            end
            
            -- Check if tile's name is excluded
            local name_excluded = false
            if q.exclude_names and t.name then
                for _, excluded_name in ipairs(q.exclude_names) do
                    if t.name == excluded_name then
                        name_excluded = true
                        break
                    end
                end
            end
            
            if not tag_excluded and not name_excluded and t.supply > 0 and (not q.blackset or not q.blackset[t]) and min_degree <= t.degree and max_degree >= t.degree and (q.w == "*" or q.w == t.w) and (q.h == "*" or q.h == t.h) and material_match(q, t, "u") and material_match(q, t, "r") and material_match(q, t, "d") and material_match(q, t, "l") then
                matches[#matches + 1] = t
            end
        end

        table.sort(matches, tile_sorter)

        return matches
    end

    QuiltBuilder.try_find_tile = function (self, x, y, q)
        if not q.processed then
            q.w = q.w or 1
            q.h = q.h or 1
            q.u = q.u or "*"
            q.r = q.r or "*"
            q.d = q.d or "*"
            q.l = q.l or "*"

            local grid = self.grid

            for dir, dx, dy in dir_iter() do
                local id = xy_to_id(x + dx, y + dy)
                local neighbor = grid[id]

                if neighbor then
                    local material = neighbor[INV_DIR[dir]].material

                    quilt_ensure(type(material) == "string")

                    q[dir] = material

                    if q.dont_repeat_neighbors then
                        q.blackset = q.blackset or {}
                        q.blackset[neighbor.tile] = true
                    end

                    if q.prevent_spreading then
                        if neighbor.tile.degree >= 4 then
                            q.max_degree = math.min(q.max_degree or 2, 2)
                        elseif neighbor.tile.degree >= 3 then
                            q.max_degree = math.min(q.max_degree or 3, 3)
                        end
                    end
                end
            end

            q.processed = true
        end

        local matches = self:find_tiles(q)

        if self:should_debug_print() then
            local matched_names = {}

            for i, tile in ipairs(matches) do
                matched_names[i] = tile.name
            end

            table.sort(matched_names)
        end

        matches = array.filter(matches, function (tile)
            return self:position_tile(x, y, tile) ~= nil
        end)

        if #matches == 0 then
            return nil
        elseif #matches == 1 then
            return matches[1]
        end

        if q.lowest_degree then
            local _, lowest_deg = array.pick_smallest(matches, function (t)
                return t.degree
            end)

            matches = array.filter(matches, function (t)
                return t.degree == lowest_deg
            end)
        end

        if #matches == 0 then
            return nil
        else
            return self.randomizer:array_weighted_value(matches)
        end
    end

    QuiltBuilder.find_tile = function (self, x, y, q)
        local tile = self:try_find_tile(x, y, q)

        if tile then
            return tile
        end

        q = table.shallow_clone(q)

        if q.blackset then
            q.blackset = nil
            tile = self:try_find_tile(x, y, q)

            if tile then
                return tile
            end
        end

        if q.max_degree then
            local w = q.w or 1
            local h = q.h or 1

            while q.max_degree < 2 * (w + h) do
                q.max_degree = q.max_degree + 1
                tile = self:try_find_tile(x, y, q)

                if tile then
                    return tile
                end
            end
        end

        if q.min_degree then
            while q.min_degree > 0 do
                q.min_degree = q.min_degree - 1
                tile = self:try_find_tile(x, y, q)

                if tile then
                    return tile
                end
            end
        end

        quilt_error(sprintf("Failed to find tile matching query"))

        return nil
    end

    function dim_color(c)
        local _, r, g, b = Quaternion.to_elements(c)

        return Color(196, r, g, b)
    end

    local function get_side_points(offset, block, side)
        local side_ix = 0

        for dir, bx, by, material in block_border_iter(0, 0, block) do
            if is_walkable(material) then
                side_ix = side_ix + 1

                if side_ix == side then
                    local points = {}
                    local pos = offset + Vector3(block.x, 0, block.y) + TILE_SIZE * Vector3(bx, 0, by)
                    local STEP = 1
                    local START = 2 * STEP
                    local END = TILE_SIZE - START

                    if dir == "u" then
                        for dx = START, END, STEP do
                            points[#points + 1] = pos + Vector3(dx, 0, TILE_SIZE)
                        end
                    end

                    if dir == "r" then
                        for dy = END, START, -STEP do
                            points[#points + 1] = pos + Vector3(TILE_SIZE, 0, dy)
                        end
                    end

                    if dir == "d" then
                        for dx = END, START, -STEP do
                            points[#points + 1] = pos + Vector3(dx, 0, 0)
                        end
                    end

                    if dir == "l" then
                        for dy = START, END, STEP do
                            points[#points + 1] = pos + Vector3(0, 0, dy)
                        end
                    end

                    return points
                end
            end
        end
    end

end