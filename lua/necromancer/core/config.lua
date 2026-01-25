local errors = require("necromancer.utils.errors")
local validator = require("necromancer.core.validator")
local dependencies = require("necromancer.core.dependencies")

local M = {}

---Parse and validate configuration file
---@param path string Path to config file
---@return table config Parsed configuration
function M.parse_config_file(path)
  -- Read file
  local lines = vim.fn.readfile(path)
  if vim.tbl_isempty(lines) then
    error(errors.ConfigError("Failed to read configuration file at " .. path))
  end

  -- Parse JSON
  local content = table.concat(lines, "\n")
  local ok, config = pcall(vim.json.decode, content)
  if not ok then
    error(errors.ConfigError("Invalid JSON in configuration file: " .. tostring(config)))
  end

  -- Validate
  M.validate_config(config)

  return config
end

---Validate configuration structure and content
---@param config table Configuration to validate
function M.validate_config(config)
  -- Check plugins array exists
  if not config.plugins then
    error(errors.ValidationError('Configuration must contain a "plugins" array'))
  end

  -- Check plugins is non-empty array
  if type(config.plugins) ~= "table" or #config.plugins == 0 then
    error(errors.ValidationError("Plugins array must not be empty"))
  end

  local plugin_names = {}

  -- Validate each plugin
  for i, plugin in ipairs(config.plugins) do
    if not plugin then
      error(errors.ValidationError(string.format("Plugin at index %d is undefined", i)))
    end

    -- Check required fields
    if not plugin.name then
      error(errors.ValidationError(string.format("Plugin at index %d is missing required field: name", i)))
    end
    if not plugin.repo then
      error(errors.ValidationError(string.format("Plugin at index %d is missing required field: repo", i)))
    end
    if not plugin.commit then
      error(errors.ValidationError(string.format("Plugin at index %d is missing required field: commit", i)))
    end

    -- Validate plugin name
    if not validator.is_valid_plugin_name(plugin.name) then
      error(errors.ValidationError(string.format('Invalid plugin name: "%s"', plugin.name)))
    end

    -- Check for duplicates
    if plugin_names[plugin.name] then
      error(errors.ValidationError(string.format('Duplicate plugin name: "%s"', plugin.name)))
    end
    plugin_names[plugin.name] = true

    -- Validate GitHub URL
    if not validator.is_valid_github_url(plugin.repo) then
      error(errors.ValidationError(
        string.format('Invalid GitHub URL for plugin "%s": %s', plugin.name, plugin.repo)
      ))
    end

    -- Validate commit hash
    if not validator.is_valid_commit_hash(plugin.commit) then
      error(errors.ValidationError(
        string.format('Invalid commit hash for plugin "%s": %s', plugin.name, plugin.commit)
      ))
    end

    -- Validate branch if present
    if plugin.branch then
      if type(plugin.branch) ~= "string" then
        error(errors.ValidationError(
          string.format('Branch for plugin "%s" must be a string', plugin.name)
        ))
      end
      if not validator.is_valid_branch_name(plugin.branch) then
        error(errors.ValidationError(
          string.format('Invalid branch name for plugin "%s": %s', plugin.name, plugin.branch)
        ))
      end
    end

    -- Validate dependencies if present
    if plugin.dependencies then
      if type(plugin.dependencies) ~= "table" then
        error(errors.ValidationError(
          string.format('Dependencies for plugin "%s" must be an array', plugin.name)
        ))
      end

      for _, dep in ipairs(plugin.dependencies) do
        if type(dep) ~= "string" then
          error(errors.ValidationError(
            string.format('Dependencies for plugin "%s" must be an array of strings', plugin.name)
          ))
        end
        if not validator.is_valid_plugin_name(dep) then
          error(errors.ValidationError(
            string.format('Invalid dependency name "%s" for plugin "%s"', dep, plugin.name)
          ))
        end
      end
    end
  end

  -- Validate dependency relationships (circular deps, missing deps)
  dependencies.resolve_dependencies(config.plugins)
end

---Update plugin commits in config file
---@param config_path string Path to config file
---@param updates table[] List of {name, commit} pairs
function M.update_plugins_commits(config_path, updates)
  -- Read and parse current config
  local lines = vim.fn.readfile(config_path)
  if vim.tbl_isempty(lines) then
    error(errors.ConfigError("Failed to read configuration file at " .. config_path))
  end

  local content = table.concat(lines, "\n")
  local ok, cfg = pcall(vim.json.decode, content)
  if not ok then
    error(errors.ConfigError("Invalid JSON in configuration file: " .. tostring(cfg)))
  end

  -- Build lookup table for updates
  local update_map = {}
  for _, update in ipairs(updates) do
    update_map[update.name] = update.commit
  end

  -- Apply updates
  for _, plugin in ipairs(cfg.plugins) do
    if update_map[plugin.name] then
      plugin.commit = update_map[plugin.name]
    end
  end

  -- Write back
  local json = vim.json.encode(cfg)
  vim.fn.writefile({ json }, config_path)
end

return M
