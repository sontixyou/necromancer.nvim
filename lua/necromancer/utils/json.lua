local M = {}

---Pretty print JSON with indentation (2 spaces)
---Works with Neovim 0.9+ (doesn't rely on vim.json.encode options)
---@param value any Value to encode
---@param indent_size? number Indent size (default: 2)
---@return string json Pretty-printed JSON string
function M.encode_pretty(value, indent_size)
  indent_size = indent_size or 2

  local function encode(val, level)
    local indent = string.rep(" ", level * indent_size)
    local next_indent = string.rep(" ", (level + 1) * indent_size)
    local t = type(val)

    if val == vim.NIL then
      return "null"
    elseif t == "nil" then
      return "null"
    elseif t == "boolean" then
      return val and "true" or "false"
    elseif t == "number" then
      if val ~= val then -- NaN
        return "null"
      elseif val == math.huge then
        return "null"
      elseif val == -math.huge then
        return "null"
      else
        return tostring(val)
      end
    elseif t == "string" then
      -- Escape special characters
      local escaped = val:gsub('[\\"]', {
        ["\\"] = "\\\\",
        ['"'] = '\\"',
      })
      -- Escape control characters (0x00-0x1f)
      escaped = escaped:gsub("%c", function(c)
        local byte = string.byte(c)
        if byte == 8 then -- backspace
          return "\\b"
        elseif byte == 9 then -- tab
          return "\\t"
        elseif byte == 10 then -- newline
          return "\\n"
        elseif byte == 12 then -- form feed
          return "\\f"
        elseif byte == 13 then -- carriage return
          return "\\r"
        else
          return string.format("\\u%04x", byte)
        end
      end)
      return '"' .. escaped .. '"'
    elseif t == "table" then
      -- Check if array (sequential integer keys starting from 1)
      local is_array = true
      local max_index = 0
      for k, _ in pairs(val) do
        if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
          is_array = false
          break
        end
        if k > max_index then
          max_index = k
        end
      end
      -- Verify no gaps
      if is_array and max_index > 0 then
        for i = 1, max_index do
          if val[i] == nil then
            is_array = false
            break
          end
        end
      end
      -- Empty table is array
      if next(val) == nil then
        is_array = true
      end

      if is_array then
        if max_index == 0 then
          return "[]"
        end
        local parts = {}
        for i = 1, max_index do
          table.insert(parts, next_indent .. encode(val[i], level + 1))
        end
        return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
      else
        -- Object
        local keys = {}
        for k, _ in pairs(val) do
          if type(k) == "string" then
            table.insert(keys, k)
          end
        end
        if #keys == 0 then
          return "{}"
        end
        -- Sort keys for consistent output
        table.sort(keys)
        local parts = {}
        for _, k in ipairs(keys) do
          local v = val[k]
          table.insert(parts, next_indent .. encode(k, level + 1) .. ": " .. encode(v, level + 1))
        end
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
      end
    else
      error("Cannot encode type: " .. t)
    end
  end

  return encode(value, 0)
end

return M
