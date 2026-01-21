local errors = require("necromancer.utils.errors")

local M = {}

---Resolve plugin dependencies using topological sort (Kahn's algorithm)
---@param plugins table[] Array of plugin definitions with name, repo, commit, dependencies?
---@return table[] Sorted plugins in installation order
function M.resolve_dependencies(plugins)
  -- Create plugin map for quick lookup
  local plugin_map = {}
  for _, plugin in ipairs(plugins) do
    plugin_map[plugin.name] = plugin
  end

  -- Validate all dependencies exist
  for _, plugin in ipairs(plugins) do
    if plugin.dependencies then
      for _, dep_name in ipairs(plugin.dependencies) do
        if not plugin_map[dep_name] then
          error(errors.ValidationError(
            string.format('Plugin "%s" depends on "%s", but "%s" is not defined in the configuration',
              plugin.name, dep_name, dep_name)
          ))
        end
      end
    end
  end

  -- Initialize in-degree count and adjacency list
  local in_degree = {}
  local adjacency = {}

  for _, plugin in ipairs(plugins) do
    in_degree[plugin.name] = 0
    adjacency[plugin.name] = {}
  end

  -- Build dependency graph
  for _, plugin in ipairs(plugins) do
    if plugin.dependencies then
      for _, dep_name in ipairs(plugin.dependencies) do
        -- dep_name should be installed before plugin.name
        table.insert(adjacency[dep_name], plugin.name)
        in_degree[plugin.name] = in_degree[plugin.name] + 1
      end
    end
  end

  -- Queue for processing (plugins with no dependencies)
  local queue = {}
  local result = {}

  -- Find all plugins with no incoming edges
  for name, degree in pairs(in_degree) do
    if degree == 0 then
      table.insert(queue, name)
    end
  end

  -- Process queue
  while #queue > 0 do
    local current = table.remove(queue, 1)
    table.insert(result, plugin_map[current])

    -- Remove this node and update in-degrees
    for _, neighbor in ipairs(adjacency[current]) do
      in_degree[neighbor] = in_degree[neighbor] - 1
      if in_degree[neighbor] == 0 then
        table.insert(queue, neighbor)
      end
    end
  end

  -- Check for circular dependencies
  if #result ~= #plugins then
    local remaining = {}
    for _, plugin in ipairs(plugins) do
      local found = false
      for _, resolved in ipairs(result) do
        if resolved.name == plugin.name then
          found = true
          break
        end
      end
      if not found then
        table.insert(remaining, plugin.name)
      end
    end
    error(errors.ValidationError(
      "Circular dependency detected involving plugins: " .. table.concat(remaining, ", ")
    ))
  end

  return result
end

---Validate plugin dependencies without sorting
---@param plugins table[] Array of plugin definitions
---@return nil Throws ValidationError if dependencies are invalid
function M.validate_dependencies(plugins)
  -- This will throw if there are issues
  M.resolve_dependencies(plugins)
end

return M
