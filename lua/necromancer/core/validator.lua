local M = {}

---Validate Git commit hash (40-character SHA-1)
---@param hash string
---@return boolean
function M.is_valid_commit_hash(hash)
  if type(hash) ~= "string" then
    return false
  end
  return #hash == 40 and hash:match("^[a-fA-F0-9]+$") ~= nil
end

---Validate GitHub repository URL
---@param url string
---@return boolean
function M.is_valid_github_url(url)
  if type(url) ~= "string" then
    return false
  end
  -- Match: https://github.com/owner/repo or https://github.com/owner/repo.git
  -- Owner: alphanumeric, hyphens, underscores
  -- Repo: alphanumeric, hyphens, underscores, dots
  local pattern = "^https://github%.com/[%w_%-]+/[%w%.%-_]+$"
  local pattern_git = "^https://github%.com/[%w_%-]+/[%w%.%-_]+%.git$"
  return url:match(pattern) ~= nil or url:match(pattern_git) ~= nil
end

---Validate plugin name
---@param name string
---@return boolean
function M.is_valid_plugin_name(name)
  if type(name) ~= "string" then
    return false
  end
  if #name < 1 or #name > 100 then
    return false
  end
  -- First char: alphanumeric or underscore (not hyphen)
  -- Rest: alphanumeric, hyphen, underscore, or dot
  return name:match("^[%w_][%w%.%-_]*$") ~= nil
end

---Check for shell metacharacters (injection prevention)
---@param input string
---@return boolean has_metachar
function M.has_shell_metachar(input)
  if type(input) ~= "string" then
    return false
  end
  -- Check for: ; & | ` $ ( ) < > newline
  return input:match("[;&|`$()<>\n]") ~= nil
end

return M
