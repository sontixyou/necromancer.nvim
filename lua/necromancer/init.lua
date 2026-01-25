local M = {}

M._VERSION = "2.0.0"

M._config = {
  config_path = nil,
  install_dir = nil,
}

---Setup necromancer plugin manager
---@param opts? table Optional configuration
---  - config_path: string|nil - Custom path to config file
---  - install_dir: string|nil - Custom plugin installation directory
---  - autofetch: boolean|table|nil - Auto-fetch necromancer updates on startup
---    - enabled: boolean (default: true) - Enable/disable autofetch
---    - notify_updates: boolean (default: true) - Show notification when updates are available
---    - quiet: boolean (default: false) - Suppress debug messages
function M.setup(opts)
  opts = opts or {}

  -- Save config options
  M._config.config_path = opts.config_path
  M._config.install_dir = opts.install_dir

  local paths = require("necromancer.utils.paths")
  local lockfile = require("necromancer.core.lockfile")

  -- Find config file
  local config_path = paths.resolve_config_path(opts.config_path)
  if config_path then
    -- Get install directory
    local install_dir = opts.install_dir or paths.get_default_install_dir()

    -- Get lock file and add installed plugins to runtimepath
    local lock_path = paths.get_lock_file_path(config_path)
    local lock = lockfile.read(lock_path)

    for _, plugin in ipairs(lock.plugins) do
      local plugin_path = paths.expand_tilde(plugin.path)
      if vim.fn.isdirectory(plugin_path) == 1 then
        vim.opt.rtp:prepend(plugin_path)
      end
    end
  end

  -- Register :Necromancer command
  local commands = require("necromancer.commands")
  commands.setup()

  -- Start autofetch for necromancer itself
  local autofetch = require("necromancer.core.autofetch")
  autofetch.start(opts.autofetch)
end

return M
