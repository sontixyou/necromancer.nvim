local M = {}

M.LOCK_FILE_VERSION = "1"

---Create an empty lock file
---@return table
function M.create_empty()
  return {
    version = M.LOCK_FILE_VERSION,
    generated = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    plugins = {},
  }
end

---Read lock file (or create empty if doesn't exist)
---@param path string
---@return table
function M.read(path)
  if vim.fn.filereadable(path) ~= 1 then
    return M.create_empty()
  end

  local lines = vim.fn.readfile(path)
  if vim.tbl_isempty(lines) then
    return M.create_empty()
  end

  local content = table.concat(lines, "\n")
  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    return M.create_empty()
  end

  return data
end

---Write lock file
---@param path string
---@param data table
function M.write(path, data)
  data.generated = os.date("!%Y-%m-%dT%H:%M:%SZ")
  local json = vim.json.encode(data)
  vim.fn.writefile({ json }, path)
end

---Find plugin in lock file
---@param lockfile table
---@param name string
---@return table|nil plugin
---@return number|nil index
function M.find_plugin(lockfile, name)
  for i, plugin in ipairs(lockfile.plugins) do
    if plugin.name == name then
      return plugin, i
    end
  end
  return nil, nil
end

---Update or add plugin to lock file
---@param lockfile table
---@param plugin table
function M.upsert_plugin(lockfile, plugin)
  local _, index = M.find_plugin(lockfile, plugin.name)
  if index then
    lockfile.plugins[index] = plugin
  else
    table.insert(lockfile.plugins, plugin)
  end
end

---Remove plugin from lock file
---@param lockfile table
---@param name string
---@return boolean removed
function M.remove_plugin(lockfile, name)
  local _, index = M.find_plugin(lockfile, name)
  if index then
    table.remove(lockfile.plugins, index)
    return true
  end
  return false
end

return M
