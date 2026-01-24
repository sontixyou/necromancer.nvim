local M = {}

---Normalize autofetch options
---@param opts any User-provided options (boolean or table)
---@return table Normalized options
function M.normalize_opts(opts)
  local defaults = {
    enabled = true,
    notify_updates = true,
    quiet = false,
  }

  if opts == nil or opts == true then
    return defaults
  end

  if opts == false then
    defaults.enabled = false
    return defaults
  end

  if type(opts) == "table" then
    return {
      enabled = opts.enabled ~= false,
      notify_updates = opts.notify_updates ~= false,
      quiet = opts.quiet == true,
    }
  end

  return defaults
end

---Check if a directory is a git repository
---@param path string Directory path
---@return boolean
local function is_git_repo(path)
  local git_dir = path .. "/.git"
  return vim.fn.isdirectory(git_dir) == 1 or vim.fn.filereadable(git_dir) == 1
end

---Get current HEAD commit hash
---@param path string Repository path
---@return string|nil
local function get_head_commit(path)
  local result = vim.fn.systemlist({ "git", "-C", path, "rev-parse", "HEAD" })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return result[1]
end

---Get remote tracking branch commit hash
---@param path string Repository path
---@return string|nil
local function get_remote_commit(path)
  local result = vim.fn.systemlist({ "git", "-C", path, "rev-parse", "@{upstream}" })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return result[1]
end

---Start autofetch process
---@param opts? table Options from setup()
function M.start(opts)
  local normalized = M.normalize_opts(opts)

  if not normalized.enabled then
    return
  end

  local paths = require("necromancer.utils.paths")
  local necromancer_path = paths.get_necromancer_path()

  if not necromancer_path then
    if not normalized.quiet then
      vim.notify("[necromancer] Could not determine plugin path", vim.log.levels.DEBUG)
    end
    return
  end

  M.autofetch(necromancer_path, normalized)
end

---Execute autofetch asynchronously
---@param path string Path to necromancer.nvim
---@param opts table Normalized options
function M.autofetch(path, opts)
  if not is_git_repo(path) then
    if not opts.quiet then
      vim.notify("[necromancer] Not a git repository: " .. path, vim.log.levels.DEBUG)
    end
    return
  end

  -- Capture current HEAD before fetch
  local head_before = get_head_commit(path)
  if not head_before then
    if not opts.quiet then
      vim.notify("[necromancer] Could not get current HEAD", vim.log.levels.DEBUG)
    end
    return
  end

  -- Run git fetch asynchronously
  local cmd = { "git", "-C", path, "fetch", "--quiet", "--all" }

  vim.fn.jobstart(cmd, {
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        if not opts.quiet then
          vim.notify("[necromancer] git fetch failed", vim.log.levels.DEBUG)
        end
        return
      end

      if opts.notify_updates then
        M._check_updates(path, head_before, opts)
      end
    end,
  })
end

---Check for updates after fetch and notify user
---@param path string Repository path
---@param head_before string HEAD commit before fetch
---@param opts table Normalized options
function M._check_updates(path, head_before, opts)
  local remote_commit = get_remote_commit(path)

  if not remote_commit then
    if not opts.quiet then
      vim.notify("[necromancer] Could not get remote commit", vim.log.levels.DEBUG)
    end
    return
  end

  if remote_commit ~= head_before then
    vim.schedule(function()
      vim.notify(
        "[necromancer] Updates available! Run :Necromancer self-update to update.",
        vim.log.levels.INFO
      )
    end)
  end
end

return M
