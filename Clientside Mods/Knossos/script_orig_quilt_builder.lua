function _G.get_orig_quilt_builder()
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

		self:connect_seeds()
		self:enclose()
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
					q.exit = true
					tile = self:try_find_tile(x, y, q)

					if tile then
						has_exit = true
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
		end
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
		else
			source_set = self.filler_tile_set
		end

		if self:should_debug_print() then
			-- Nothing
		end

		local matches = {}

		for t, _ in pairs(source_set) do
			if t.supply > 0 and (not q.blackset or not q.blackset[t]) and min_degree <= t.degree and max_degree >= t.degree and (q.w == "*" or q.w == t.w) and (q.h == "*" or q.h == t.h) and material_match(q, t, "u") and material_match(q, t, "r") and material_match(q, t, "d") and material_match(q, t, "l") then
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