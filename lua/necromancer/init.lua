local M = {}

M._VERSION = "2.0.0"

---Setup necromancer plugin manager
---@param opts? table Optional configuration
---  - config_path: string|nil - Custom path to config file
---  - install_dir: string|nil - Custom plugin installation directory
function M.setup(opts)
  opts = opts or {}

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
end

return M
