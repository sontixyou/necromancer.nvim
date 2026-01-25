local git = require("necromancer.core.git")
local dependencies = require("necromancer.core.dependencies")
local paths = require("necromancer.utils.paths")

local M = {}

---Check if a plugin installation is valid (directory exists, is git repo, correct commit)
---@param installed table InstalledPlugin from lockfile
---@return boolean valid
---@return string|nil error_message
function M.verify_installation(installed)
  -- Expand tilde in path
  local absolute_path = paths.expand_tilde(installed.path)

  -- Check if directory exists
  if vim.fn.isdirectory(absolute_path) ~= 1 then
    return false, "Directory does not exist: " .. absolute_path
  end

  -- Check if it's a valid git repository by trying to get current commit
  local ok, result = pcall(function()
    return git.get_current_commit(absolute_path)
  end)

  if not ok then
    return false, "Not a valid git repository: " .. absolute_path
  end

  -- Validate commit hash format (40 hex characters)
  if #result ~= 40 or not result:match("^[0-9a-fA-F]+$") then
    return false, "Invalid git repository (invalid commit hash format)"
  end

  return true, nil
end

---Re-clone a corrupted or missing plugin
---@param def table PluginDefinition
---@param target_path string Full path to plugin directory
---@return boolean success
---@return string|nil error_message
function M.repair_plugin(def, target_path)
  -- Expand tilde in path
  local absolute_path = paths.expand_tilde(target_path)

  -- Remove corrupted installation if it exists
  if vim.fn.isdirectory(absolute_path) == 1 then
    local delete_result = vim.fn.delete(absolute_path, "rf")
    if delete_result ~= 0 then
      return false, "Failed to remove corrupted plugin directory: " .. absolute_path
    end
  end

  -- Clone fresh copy
  local ok, err = pcall(function()
    git.clone(def.repo, absolute_path)
  end)

  if not ok then
    local msg = type(err) == "table" and err.message or tostring(err)
    return false, "Failed to clone: " .. msg
  end

  -- Checkout the specified commit
  local checkout_ok, checkout_err = pcall(function()
    git.checkout(absolute_path, def.commit)
  end)

  if not checkout_ok then
    local msg = type(checkout_err) == "table" and checkout_err.message or tostring(checkout_err)
    -- Clean up failed installation to prevent partial state
    vim.fn.delete(absolute_path, "rf")
    return false, "Failed to checkout commit: " .. msg
  end

  return true, nil
end

---Install or update a single plugin
---@param def table PluginDefinition {name, repo, commit, dependencies?}
---@param install_dir string Base installation directory
---@return table InstallResult {success, name, action, message?, installed_at?}
function M.install_plugin(def, install_dir)
  local target_path = paths.resolve_plugin_path(def.name, install_dir)
  local result = {
    success = false,
    name = def.name,
    action = "failed",
    message = nil,
    installed_at = nil,
  }

  -- Check if plugin directory already exists
  if vim.fn.isdirectory(target_path) == 1 then
    -- Verify existing installation
    local valid, verify_err = M.verify_installation({
      name = def.name,
      repo = def.repo,
      commit = def.commit,
      path = target_path,
    })

    if not valid then
      -- Corrupted installation, repair it
      local repair_ok, repair_err = M.repair_plugin(def, target_path)
      if not repair_ok then
        result.message = "Failed to repair: " .. (repair_err or "unknown error")
        return result
      end

      result.success = true
      result.action = "installed"
      result.message = string.format(
        "Installed %s at commit %s (repaired corrupted installation)",
        def.name,
        def.commit:sub(1, 8)
      )
      result.installed_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
      return result
    end

    -- Check current commit
    local current_ok, current_commit = pcall(function()
      return git.get_current_commit(target_path)
    end)

    if not current_ok then
      result.message = "Failed to get current commit"
      return result
    end

    -- Already at target commit
    if current_commit == def.commit then
      result.success = true
      result.action = "skipped"
      result.message = string.format(
        "%s already installed at commit %s",
        def.name,
        def.commit:sub(1, 8)
      )
      return result
    end

    -- Update to new commit
    local checkout_ok, checkout_err = pcall(function()
      git.checkout(target_path, def.commit)
    end)

    if not checkout_ok then
      local msg = type(checkout_err) == "table" and checkout_err.message or tostring(checkout_err)
      result.message = "Failed to checkout: " .. msg
      return result
    end

    result.success = true
    result.action = "updated"
    result.message = string.format(
      "Updated %s from %s to %s",
      def.name,
      current_commit:sub(1, 8),
      def.commit:sub(1, 8)
    )
    result.installed_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
    return result
  end

  -- New installation - clone repository
  local clone_ok, clone_err = pcall(function()
    git.clone(def.repo, target_path)
  end)

  if not clone_ok then
    local msg = type(clone_err) == "table" and clone_err.message or tostring(clone_err)
    result.message = "Failed to clone: " .. msg
    return result
  end

  -- Checkout specified commit
  local checkout_ok, checkout_err = pcall(function()
    git.checkout(target_path, def.commit)
  end)

  if not checkout_ok then
    local msg = type(checkout_err) == "table" and checkout_err.message or tostring(checkout_err)
    result.message = "Failed to checkout: " .. msg
    return result
  end

  result.success = true
  result.action = "installed"
  result.message = string.format("Installed %s at commit %s", def.name, def.commit:sub(1, 8))
  result.installed_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
  return result
end

---Install all plugins from config (handles dependency order)
---@param plugins table[] List of PluginDefinitions
---@param install_dir string Base installation directory
---@return table[] List of InstallResults
function M.install_all(plugins, install_dir)
  -- Resolve dependencies to get correct installation order
  local sorted_plugins = dependencies.resolve_dependencies(plugins)

  local results = {}
  for _, plugin in ipairs(sorted_plugins) do
    local result = M.install_plugin(plugin, install_dir)
    table.insert(results, result)
  end

  return results
end

return M
