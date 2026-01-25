local errors = require("necromancer.utils.errors")

local M = {}

---Execute a git command synchronously
---@param args string[] Git command arguments
---@param cwd? string Working directory
---@return string output
local function git_exec(args, cwd)
  local cmd = vim.list_extend({ "git" }, args)

  local result
  if cwd then
    -- Change to directory, run command, change back
    local original_dir = vim.fn.getcwd()
    vim.fn.chdir(cwd)
    result = vim.fn.system(cmd)
    vim.fn.chdir(original_dir)
  else
    result = vim.fn.system(cmd)
  end

  if vim.v.shell_error ~= 0 then
    error(errors.GitError("Git command failed: " .. vim.trim(result)))
  end

  return vim.trim(result)
end

---Clone a git repository
---@param url string Repository URL
---@param target_path string Destination path
function M.clone(url, target_path)
  -- Basic injection prevention (defense in depth)
  local safe_url = url:gsub(";", "")
  local safe_path = target_path:gsub(";", "")

  local ok, err = pcall(function()
    git_exec({ "clone", "--quiet", safe_url, safe_path })
  end)

  if not ok then
    local msg = type(err) == "table" and err.message or tostring(err)
    error(errors.GitError("Failed to clone " .. url .. ": " .. msg))
  end
end

---Checkout a specific commit
---@param repo_path string Path to repository
---@param commit string Commit hash
function M.checkout(repo_path, commit)
  local safe_commit = commit:gsub(";", "")

  local ok, err = pcall(function()
    git_exec({ "checkout", "--quiet", safe_commit }, repo_path)
  end)

  if not ok then
    local msg = type(err) == "table" and err.message or tostring(err)
    error(errors.GitError("Failed to checkout " .. commit .. ": " .. msg))
  end
end

---Fetch updates from remote
---@param repo_path string Path to repository
function M.fetch(repo_path)
  local ok, err = pcall(function()
    git_exec({ "fetch", "--quiet", "--all" }, repo_path)
  end)

  if not ok then
    local msg = type(err) == "table" and err.message or tostring(err)
    error(errors.GitError("Failed to fetch: " .. msg))
  end
end

---Get current commit hash
---@param repo_path string Path to repository
---@return string commit 40-character hash
function M.get_current_commit(repo_path)
  local ok, result = pcall(function()
    return git_exec({ "rev-parse", "HEAD" }, repo_path)
  end)

  if not ok then
    local msg = type(result) == "table" and result.message or tostring(result)
    error(errors.GitError("Failed to get current commit: " .. msg))
  end

  return result
end

---Get default branch name from remote
---@param repo_path string Path to repository
---@return string branch Default branch name
function M.get_default_branch(repo_path)
  -- Try to get from remote
  local ok, result = pcall(function()
    return git_exec({ "remote", "show", "origin" }, repo_path)
  end)

  if ok and result then
    local branch = result:match("HEAD branch: ([^\n]+)")
    if branch and #branch > 0 then
      return vim.trim(branch)
    end
  end

  -- Fallback: check if main or master exists
  local main_ok = pcall(function()
    git_exec({ "rev-parse", "--verify", "main" }, repo_path)
  end)
  if main_ok then
    return "main"
  end

  local master_ok = pcall(function()
    git_exec({ "rev-parse", "--verify", "master" }, repo_path)
  end)
  if master_ok then
    return "master"
  end

  -- Default to main
  return "main"
end

---Get commit hash from before specified number of days ago
---@param repo_path string Path to repository
---@param branch string Branch name (e.g., "origin/main")
---@param days_ago number Number of days ago
---@return string commit 40-character hash
function M.get_commit_before_date(repo_path, branch, days_ago)
  local date_spec = string.format("%d days ago", days_ago)

  -- Try to get commit before the specified date
  local ok, result = pcall(function()
    return git_exec({
      "log",
      branch,
      "--before=" .. date_spec,
      "-1",
      "--format=%H",
    }, repo_path)
  end)

  if ok and result and #result == 40 then
    return result
  end

  -- Fallback: get the oldest commit on the branch
  local oldest_ok, oldest = pcall(function()
    return git_exec({
      "rev-list",
      "--max-parents=0",
      branch,
    }, repo_path)
  end)

  if oldest_ok and oldest then
    -- rev-list may return multiple lines, take the first
    local first_line = oldest:match("^([^\n]+)")
    if first_line and #first_line == 40 then
      return first_line
    end
  end

  -- Last resort: just get HEAD of the branch
  local head_ok, head = pcall(function()
    return git_exec({ "rev-parse", branch }, repo_path)
  end)

  if head_ok and head and #head == 40 then
    return head
  end

  error(errors.GitError("Failed to get commit for branch: " .. branch))
end

---Get remote HEAD commit hash
---@param repo_path string Path to repository
---@return string|nil commit 40-character hash, or nil if no remote
function M.get_remote_head(repo_path)
  -- Try to get remote HEAD (origin/HEAD -> origin/main or origin/master)
  local ok, result = pcall(function()
    -- First try origin/HEAD
    local head = git_exec({ "rev-parse", "origin/HEAD" }, repo_path)
    return head
  end)

  if ok then
    return result
  end

  -- Fallback: try origin/main, then origin/master
  ok, result = pcall(function()
    return git_exec({ "rev-parse", "origin/main" }, repo_path)
  end)

  if ok then
    return result
  end

  ok, result = pcall(function()
    return git_exec({ "rev-parse", "origin/master" }, repo_path)
  end)

  if ok then
    return result
  end

  return nil
end

---Pull updates from remote (fast-forward only)
---@param repo_path string Path to repository
function M.pull(repo_path)
  local ok, err = pcall(function()
    git_exec({ "pull", "--ff-only" }, repo_path)
  end)

  if not ok then
    local msg = type(err) == "table" and err.message or tostring(err)
    error(errors.GitError("Failed to pull: " .. msg))
  end
end

return M
