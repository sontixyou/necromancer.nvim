local config = require("necromancer.core.config")
local git = require("necromancer.core.git")
local installer = require("necromancer.core.installer")
local lockfile = require("necromancer.core.lockfile")
local paths = require("necromancer.utils.paths")
local validator = require("necromancer.core.validator")

local M = {}

---Find a plugin by name in the plugins list
---@param plugins table[] List of plugin definitions
---@param name string Plugin name to find
---@return table|nil plugin Plugin definition or nil if not found
local function find_plugin_by_name(plugins, name)
  for _, p in ipairs(plugins) do
    if p.name == name then
      return p
    end
  end
  return nil
end

---Get status of a single plugin
---@param plugin_def table Plugin definition from config
---@param install_dir string Installation directory
---@param lock table Lock file data (unused for now)
---@return table status {name, state, current_commit, config_commit, remote_commit, error_msg}
function M.get_plugin_status(plugin_def, install_dir, lock)
  local plugin_path = paths.resolve_plugin_path(plugin_def.name, install_dir)
  local result = {
    name = plugin_def.name,
    state = "unknown",
    config_commit = plugin_def.commit,
    current_commit = nil,
    remote_commit = nil,
    error_msg = nil,
  }

  -- Check if directory exists
  if vim.fn.isdirectory(plugin_path) ~= 1 then
    result.state = "not_installed"
    return result
  end

  -- Check if it's a git repo
  if vim.fn.isdirectory(plugin_path .. "/.git") ~= 1 then
    result.state = "corrupted"
    return result
  end

  -- Get current commit
  local ok, current_commit = pcall(git.get_current_commit, plugin_path)
  if not ok then
    result.state = "corrupted"
    result.error_msg = tostring(current_commit)
    return result
  end
  result.current_commit = current_commit

  -- Fetch and get remote HEAD
  local fetch_ok = pcall(git.fetch, plugin_path)
  if fetch_ok then
    result.remote_commit = git.get_remote_head(plugin_path)
  else
    result.error_msg = "fetch_failed"
  end

  -- Determine state
  if current_commit ~= plugin_def.commit then
    result.state = "outdated"
  elseif result.remote_commit and result.remote_commit ~= plugin_def.commit then
    result.state = "update_available"
  else
    result.state = "up_to_date"
  end

  return result
end

---Install all plugins or a specific plugin
---@param args string[] Command arguments (optional plugin name)
function M.cmd_install(args)
  -- Validate args - at most one plugin name allowed
  if #args > 1 then
    vim.notify("Usage: :Necromancer install [plugin_name]", vim.log.levels.ERROR)
    return
  end
  local plugin_name = args[1]

  -- Find config file
  local config_path = paths.resolve_config_path()
  if not config_path then
    vim.notify("Config file not found. Run :Necromancer init to create one.", vim.log.levels.ERROR)
    return
  end

  -- Parse config
  local ok, cfg = pcall(config.parse_config_file, config_path)
  if not ok then
    vim.notify("Failed to parse config: " .. tostring(cfg), vim.log.levels.ERROR)
    return
  end

  -- Get install directory
  local install_dir = paths.get_default_install_dir()

  -- Ensure install directory exists
  vim.fn.mkdir(install_dir, "p")

  -- Get lock file path and read it
  local lock_path = paths.get_lock_file_path(config_path)
  local lock = lockfile.read(lock_path)

  local results
  if plugin_name then
    -- Install specific plugin
    local plugin_def = find_plugin_by_name(cfg.plugins, plugin_name)
    if not plugin_def then
      vim.notify("Plugin not found in config: " .. plugin_name, vim.log.levels.ERROR)
      return
    end

    local result = installer.install_plugin(plugin_def, install_dir)
    results = { result }
  else
    -- Install all plugins
    results = installer.install_all(cfg.plugins, install_dir)
  end

  -- Update lockfile with results
  local success_count = 0
  local failed_count = 0

  for _, result in ipairs(results) do
    if result.success then
      success_count = success_count + 1

      -- Find the plugin definition to get full info
      local plugin_def = find_plugin_by_name(cfg.plugins, result.name)
      if plugin_def and (result.action == "installed" or result.action == "updated") then
        -- Update lockfile entry
        local lock_entry = {
          name = result.name,
          repo = plugin_def.repo,
          commit = plugin_def.commit,
          path = paths.compress_tilde(paths.resolve_plugin_path(result.name, install_dir)),
          installedAt = result.installed_at,
        }

        -- Preserve installedAt for updates if not changed
        if result.action == "updated" then
          local existing = lockfile.find_plugin(lock, result.name)
          if existing and existing.installedAt and not result.installed_at then
            lock_entry.installedAt = existing.installedAt
          end
        end

        lockfile.upsert_plugin(lock, lock_entry)
      end

      vim.notify(result.message, vim.log.levels.INFO)
    else
      failed_count = failed_count + 1
      vim.notify(result.message or ("Failed to install: " .. result.name), vim.log.levels.ERROR)
    end
  end

  -- Write lockfile
  lockfile.write(lock_path, lock)

  -- Summary
  local summary = string.format("Installation complete: %d succeeded, %d failed", success_count, failed_count)
  vim.notify(summary, failed_count > 0 and vim.log.levels.WARN or vim.log.levels.INFO)
end

---List installed plugins
function M.cmd_list()
  -- Find config file
  local config_path = paths.resolve_config_path()
  if not config_path then
    vim.notify("Config file not found. Run :Necromancer init to create one.", vim.log.levels.WARN)
    return
  end

  -- Get lock file path and read it
  local lock_path = paths.get_lock_file_path(config_path)
  local lock = lockfile.read(lock_path)

  if #lock.plugins == 0 then
    vim.notify("No plugins installed. Run :Necromancer install to install plugins.", vim.log.levels.INFO)
    return
  end

  -- Build list output
  local lines = { "Installed plugins:" }
  for _, plugin in ipairs(lock.plugins) do
    local line = string.format(
      "  %s @ %s",
      plugin.name,
      plugin.commit and plugin.commit:sub(1, 8) or "unknown"
    )
    table.insert(lines, line)
  end

  -- Show in floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "necromancer", { buf = buf })

  -- Calculate window size
  local width = 60
  local height = math.min(#lines + 2, 20)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Necromancer Plugins ",
    title_pos = "center",
  })

  -- Close on q or <Esc>
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true })
end

---Status icons and labels
local STATUS_INFO = {
  up_to_date = { icon = "✓", label = "up-to-date" },
  update_available = { icon = "⬆", label = "update available" },
  outdated = { icon = "!", label = "outdated" },
  not_installed = { icon = "✗", label = "not installed" },
  corrupted = { icon = "⚠", label = "corrupted" },
  fetch_failed = { icon = "?", label = "fetch failed" },
}

---Show status of all configured plugins
function M.cmd_status()
  -- Find config file
  local config_path = paths.resolve_config_path()
  if not config_path then
    vim.notify("Config file not found. Run :Necromancer init to create one.", vim.log.levels.ERROR)
    return
  end

  -- Parse config
  local ok, cfg = pcall(config.parse_config_file, config_path)
  if not ok then
    vim.notify("Failed to parse config: " .. tostring(cfg), vim.log.levels.ERROR)
    return
  end

  -- Get install directory and lock file
  local install_dir = paths.get_default_install_dir()
  local lock_path = paths.get_lock_file_path(config_path)
  local lock = lockfile.read(lock_path)

  -- Get status for each plugin
  local statuses = {}
  local total = #cfg.plugins
  for i, plugin_def in ipairs(cfg.plugins) do
    vim.notify(string.format("Fetching updates... (%d/%d) %s", i, total, plugin_def.name), vim.log.levels.INFO)
    local status = M.get_plugin_status(plugin_def, install_dir, lock)
    table.insert(statuses, status)
  end

  -- Build output lines
  local timestamp = os.date("%H:%M:%S")
  local lines = { string.format("Plugin Status (fetched at %s):", timestamp), "" }

  -- Track summary counts
  local counts = {}
  for _, status in ipairs(statuses) do
    counts[status.state] = (counts[status.state] or 0) + 1
  end

  -- Find max plugin name length for alignment
  local max_name_len = 0
  for _, status in ipairs(statuses) do
    max_name_len = math.max(max_name_len, #status.name)
  end

  -- Format each plugin line
  for _, status in ipairs(statuses) do
    local info = STATUS_INFO[status.state] or { icon = "?", label = status.state }
    local name_padded = status.name .. string.rep(" ", max_name_len - #status.name)
    local line

    if status.state == "not_installed" then
      line = string.format("  %s %s  %s", info.icon, name_padded, info.label)
    elseif status.state == "corrupted" then
      line = string.format("  %s %s  %s", info.icon, name_padded, info.label)
    elseif status.state == "outdated" then
      local short_current = status.current_commit and status.current_commit:sub(1, 8) or "????????"
      local short_config = status.config_commit:sub(1, 8)
      line = string.format("  %s %s  %-16s @ %s ≠ %s", info.icon, name_padded, info.label, short_current, short_config)
    elseif status.state == "update_available" then
      local short_current = status.current_commit:sub(1, 8)
      local short_remote = status.remote_commit and status.remote_commit:sub(1, 8) or "????????"
      line = string.format("  %s %s  %-16s @ %s → %s", info.icon, name_padded, info.label, short_current, short_remote)
    else
      local short_commit = status.current_commit and status.current_commit:sub(1, 8) or "????????"
      line = string.format("  %s %s  %-16s @ %s", info.icon, name_padded, info.label, short_commit)
    end

    table.insert(lines, line)
  end

  -- Add summary
  table.insert(lines, "")
  local summary_parts = {}
  for _, state in ipairs({ "up_to_date", "update_available", "outdated", "not_installed", "corrupted" }) do
    if counts[state] and counts[state] > 0 then
      local info = STATUS_INFO[state]
      table.insert(summary_parts, string.format("%d %s", counts[state], info.label))
    end
  end
  table.insert(lines, "Summary: " .. table.concat(summary_parts, ", "))

  -- Show in floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "necromancer", { buf = buf })

  -- Calculate window size
  local width = 70
  local height = math.min(#lines + 2, 20)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Necromancer Status ",
    title_pos = "center",
  })

  -- Close on q or <Esc>
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true })
end

---Update necromancer.nvim itself
function M.cmd_self_update()
  local necromancer_path = paths.get_necromancer_path()

  if not necromancer_path then
    vim.notify("Could not determine necromancer.nvim path", vim.log.levels.ERROR)
    return
  end

  -- Check if it's a git repo
  if vim.fn.isdirectory(necromancer_path .. "/.git") ~= 1 then
    vim.notify("necromancer.nvim is not a git repository", vim.log.levels.ERROR)
    return
  end

  vim.notify("Checking for updates...", vim.log.levels.INFO)

  -- Fetch updates
  local ok, err = pcall(git.fetch, necromancer_path)
  if not ok then
    local msg = type(err) == "table" and err.message or tostring(err)
    vim.notify("Failed to fetch updates: " .. msg, vim.log.levels.ERROR)
    return
  end

  -- Compare commits
  local current_ok, current = pcall(git.get_current_commit, necromancer_path)
  if not current_ok then
    vim.notify("Failed to get current commit", vim.log.levels.ERROR)
    return
  end

  local remote = git.get_remote_head(necromancer_path)
  if not remote then
    vim.notify("Could not determine remote HEAD", vim.log.levels.ERROR)
    return
  end

  if current == remote then
    vim.notify("necromancer.nvim is already up-to-date", vim.log.levels.INFO)
    return
  end

  -- Pull updates
  ok, err = pcall(git.pull, necromancer_path)
  if not ok then
    local msg = type(err) == "table" and err.message or tostring(err)
    vim.notify("Failed to update: " .. msg, vim.log.levels.ERROR)
    return
  end

  vim.notify("necromancer.nvim updated! Please restart Neovim to apply changes.", vim.log.levels.INFO)
end

---Generate a new .necromancer.json config file
function M.cmd_init()
  local config_path = ".necromancer.json"

  -- Check if config already exists
  if vim.fn.filereadable(config_path) == 1 then
    vim.notify("Config file already exists: " .. config_path, vim.log.levels.WARN)
    return
  end

  -- Create default config
  local default_config = {
    plugins = {
      {
        name = "plenary.nvim",
        repo = "https://github.com/nvim-lua/plenary.nvim",
        commit = "a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683",
      },
    },
  }

  -- Write config file with pretty formatting using vim.json
  local json = vim.json.encode(default_config)
  vim.fn.writefile({ json }, config_path)
  vim.notify("Created config file: " .. config_path, vim.log.levels.INFO)
end

---Update plugins to commits from specified days ago on their branch
---@param args string[] Command arguments (optional plugin name)
function M.cmd_update(args)
  -- Validate args - at most one plugin name allowed
  if #args > 1 then
    vim.notify("Usage: :Necromancer update [plugin_name]", vim.log.levels.ERROR)
    return
  end
  local plugin_name = args[1]

  -- Find config file
  local config_path = paths.resolve_config_path()
  if not config_path then
    vim.notify("Config file not found. Run :Necromancer init to create one.", vim.log.levels.ERROR)
    return
  end

  -- Parse config
  local ok, cfg = pcall(config.parse_config_file, config_path)
  if not ok then
    vim.notify("Failed to parse config: " .. tostring(cfg), vim.log.levels.ERROR)
    return
  end

  -- Get install directory
  local install_dir = paths.get_default_install_dir()

  -- Determine which plugins to update
  local plugins_to_update = {}
  if plugin_name then
    local plugin_def = find_plugin_by_name(cfg.plugins, plugin_name)
    if not plugin_def then
      vim.notify("Plugin not found in config: " .. plugin_name, vim.log.levels.ERROR)
      return
    end
    table.insert(plugins_to_update, plugin_def)
  else
    plugins_to_update = cfg.plugins
  end

  -- Track results
  local updates = {}
  local updated_count = 0
  local skipped_count = 0
  local failed_count = 0
  local days_ago = 7

  -- Process each plugin
  for _, plugin in ipairs(plugins_to_update) do
    local plugin_path = paths.resolve_plugin_path(plugin.name, install_dir)

    -- Check if plugin is installed
    if vim.fn.isdirectory(plugin_path) ~= 1 then
      vim.notify(string.format("Plugin not installed: %s (run :Necromancer install first)", plugin.name), vim.log.levels.WARN)
      failed_count = failed_count + 1
      goto continue
    end

    vim.notify(string.format("Fetching %s...", plugin.name), vim.log.levels.INFO)

    -- Fetch latest from remote
    local fetch_ok, fetch_err = pcall(function()
      git.fetch(plugin_path)
    end)
    if not fetch_ok then
      vim.notify(string.format("Failed to fetch %s: %s", plugin.name, tostring(fetch_err)), vim.log.levels.ERROR)
      failed_count = failed_count + 1
      goto continue
    end

    -- Determine branch
    local branch = plugin.branch
    if not branch then
      local branch_ok, detected_branch = pcall(function()
        return git.get_default_branch(plugin_path)
      end)
      if branch_ok and validator.is_valid_branch_name(detected_branch) then
        branch = detected_branch
      else
        branch = "main"
      end
    end

    -- Get commit from days_ago
    local remote_branch = "origin/" .. branch
    local commit_ok, new_commit = pcall(function()
      return git.get_commit_before_date(plugin_path, remote_branch, days_ago)
    end)
    if not commit_ok then
      vim.notify(string.format("Failed to get commit for %s: %s", plugin.name, tostring(new_commit)), vim.log.levels.ERROR)
      failed_count = failed_count + 1
      goto continue
    end

    -- Check if already at this commit
    if new_commit == plugin.commit then
      vim.notify(string.format("%s is already up to date", plugin.name), vim.log.levels.INFO)
      skipped_count = skipped_count + 1
      goto continue
    end

    -- Validate commit hash using the standard validator
    if not validator.is_valid_commit_hash(new_commit) then
      vim.notify(string.format("Invalid commit hash for %s: %s", plugin.name, new_commit), vim.log.levels.ERROR)
      failed_count = failed_count + 1
      goto continue
    end

    -- Checkout new commit
    local checkout_ok, checkout_err = pcall(function()
      git.checkout(plugin_path, new_commit)
    end)
    if not checkout_ok then
      vim.notify(string.format("Failed to checkout %s: %s", plugin.name, tostring(checkout_err)), vim.log.levels.ERROR)
      failed_count = failed_count + 1
      goto continue
    end

    -- Record successful update
    table.insert(updates, { name = plugin.name, commit = new_commit })
    updated_count = updated_count + 1
    vim.notify(string.format(
      "Updated %s: %s -> %s (branch: %s, %d days ago)",
      plugin.name,
      plugin.commit:sub(1, 8),
      new_commit:sub(1, 8),
      branch,
      days_ago
    ), vim.log.levels.INFO)

    ::continue::
  end

  -- Update config file with successful updates
  if #updates > 0 then
    local update_ok, update_err = pcall(function()
      config.update_plugins_commits(config_path, updates)
    end)
    if not update_ok then
      vim.notify("Failed to update config file: " .. tostring(update_err), vim.log.levels.ERROR)
      -- Skip lockfile update to maintain consistency
    else
      -- Update lockfile only if config update succeeded
      local lock_path = paths.get_lock_file_path(config_path)
      local lock = lockfile.read(lock_path)
      for _, update in ipairs(updates) do
        local plugin_def = find_plugin_by_name(cfg.plugins, update.name)
        if plugin_def then
          local lock_entry = {
            name = update.name,
            repo = plugin_def.repo,
            commit = update.commit,
            path = paths.compress_tilde(paths.resolve_plugin_path(update.name, install_dir)),
            installedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
          }
          lockfile.upsert_plugin(lock, lock_entry)
        end
      end
      lockfile.write(lock_path, lock)
    end
  end

  -- Summary
  local summary = string.format("Update complete: %d updated, %d skipped, %d failed", updated_count, skipped_count, failed_count)
  vim.notify(summary, failed_count > 0 and vim.log.levels.WARN or vim.log.levels.INFO)
end

---Get list of available subcommands
---@return string[]
local function get_subcommands()
  return { "install", "list", "status", "init", "update", "self-update" }
end

---Get completions for :Necromancer command
---@param arg_lead string Current argument being typed
---@param cmd_line string Full command line
---@param cursor_pos number Cursor position
---@return string[]
local function complete(arg_lead, cmd_line, cursor_pos)
  local parts = vim.split(cmd_line:sub(1, cursor_pos), "%s+")
  local num_args = #parts

  -- First argument: subcommand
  if num_args == 2 then
    local subcommands = get_subcommands()
    return vim.tbl_filter(function(cmd)
      return vim.startswith(cmd, arg_lead)
    end, subcommands)
  end

  -- Second argument for install or update: plugin names
  if num_args == 3 and (parts[2] == "install" or parts[2] == "update") then
    local config_path = paths.resolve_config_path()
    if not config_path then
      return {}
    end

    local ok, cfg = pcall(config.parse_config_file, config_path)
    if not ok then
      return {}
    end

    local plugin_names = {}
    for _, p in ipairs(cfg.plugins) do
      if vim.startswith(p.name, arg_lead) then
        table.insert(plugin_names, p.name)
      end
    end
    return plugin_names
  end

  return {}
end

---Dispatch subcommand
---@param opts table Command options from nvim_create_user_command
local function dispatch(opts)
  local args = opts.fargs
  local subcommand = args[1]

  if not subcommand then
    vim.notify("Usage: :Necromancer <install|list|status|init|update|self-update> [args]", vim.log.levels.ERROR)
    return
  end

  -- Remove subcommand from args
  local subargs = {}
  for i = 2, #args do
    table.insert(subargs, args[i])
  end

  if subcommand == "install" then
    M.cmd_install(subargs)
  elseif subcommand == "list" then
    M.cmd_list()
  elseif subcommand == "status" then
    M.cmd_status()
  elseif subcommand == "self-update" then
    M.cmd_self_update()
  elseif subcommand == "init" then
    M.cmd_init()
  elseif subcommand == "update" then
    M.cmd_update(subargs)
  else
    vim.notify("Unknown subcommand: " .. subcommand, vim.log.levels.ERROR)
    vim.notify("Available commands: install, list, status, init, update, self-update", vim.log.levels.INFO)
  end
end

---Register :Necromancer command with subcommand completion
function M.setup()
  vim.api.nvim_create_user_command("Necromancer", dispatch, {
    nargs = "+",
    complete = complete,
    desc = "Necromancer plugin manager",
  })
end

return M
