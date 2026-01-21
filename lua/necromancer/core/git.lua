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

return M
