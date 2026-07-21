local MOD_NAME = "KnossosCheckBuilder"

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)
    
    if path == "lua/dungeon/dungeon_graph_builder" then
        Knossos = Knossos or {}
        
        DungeonGraphBuilder.generate_layout_graph = function (self, cluster, layout_node, x, y, override_name)
            cluster.layout_data = layout_node
            cluster.name = override_name or layout_node.name
            cluster.children = {}
            cluster.levels = {}
            cluster.x = x
            cluster.y = y

            if layout_node.quilt then
                local quilt_builder
                if Knossos.CONFIG and Knossos.CONFIG.enabled then
                    Knossos.branch_quilt_builder() -- Redefines QuiltBuilder to branching
                    quilt_builder = QuiltBuilder(layout_node.quilt, self.seed)
                else
                    _G.get_orig_quilt_builder()  -- Redefines QuiltBuilder to original
                    quilt_builder = QuiltBuilder(layout_node.quilt, self.seed)
                end

                quilt_builder:build(cluster, x, y)
            end

            if layout_node.children then
                for i, possibilities in ipairs(layout_node.children) do
                    repeat
                        if #possibilities == 0 then
                            break
                        end

                        local child_node = self.randomizer:array_value(possibilities)
                        local override_name

                        if type(child_node) == "string" then
                            override_name = child_node
                            child_node = self.nodes[child_node]
                        end

                        local offset_x, offset_y
                        local child_size = 35

                        offset_x = child_size
                        offset_y = child_size * (i - 0.5 - #layout_node.children * 0.5)

                        local child_x, child_y = DungeonAux.align_xy(x + offset_x, y + offset_y)
                        local child_cluster = {}

                        self:generate_layout_graph(child_cluster, child_node, child_x, child_y, override_name)

                        cluster.children[#cluster.children + 1] = child_cluster
                    until true
                end
            end

            return cluster
        end
    end

    return result
end)