local M = {}

---Expand tilde (~) to home directory
---@param filepath string
---@return string
function M.expand_tilde(filepath)
  return vim.fn.expand(filepath)
end

---Compress home directory to tilde notation
---@param filepath string
---@return string
function M.compress_tilde(filepath)
  local home = vim.fn.expand("~")
  if filepath == home then
    return "~"
  end
  if vim.startswith(filepath, home .. "/") then
    return "~" .. filepath:sub(#home + 1)
  end
  return filepath
end

---Get default plugin installation directory
---@return string
function M.get_default_install_dir()
  if vim.fn.has("win32") == 1 then
    local localappdata = os.getenv("LOCALAPPDATA")
    if not localappdata then
      error("LOCALAPPDATA environment variable not set")
    end
    return localappdata .. "\\nvim\\necromancer\\plugins"
  end
  return vim.fn.expand("~/.local/share/nvim/necromancer/plugins")
end

---Resolve full path for a plugin installation
---@param plugin_name string
---@param custom_install_dir? string
---@return string
function M.resolve_plugin_path(plugin_name, custom_install_dir)
  local install_dir
  if custom_install_dir then
    install_dir = M.expand_tilde(custom_install_dir)
  else
    install_dir = M.get_default_install_dir()
  end
  return install_dir .. "/" .. plugin_name
end

---Get config file path (searches current dir, then global)
---@param custom_path? string
---@return string|nil
function M.resolve_config_path(custom_path)
  if custom_path then
    return custom_path
  end

  -- Try current directory
  if vim.fn.filereadable(".necromancer.json") == 1 then
    return ".necromancer.json"
  end

  -- Try global config
  local global_config = vim.fn.expand("~/.config/necromancer/config.json")
  if vim.fn.filereadable(global_config) == 1 then
    return global_config
  end

  return nil
end

---Get lock file path from config file path
---@param config_path string
---@return string
function M.get_lock_file_path(config_path)
  if vim.endswith(config_path, ".necromancer.json") then
    return config_path:gsub("%.necromancer%.json$", ".necromancer.lock")
  end
  if vim.endswith(config_path, "config.json") then
    return config_path:gsub("config%.json$", "lock.json")
  end
  return config_path .. ".lock"
end

return M
