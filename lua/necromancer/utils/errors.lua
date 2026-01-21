local M = {}

function M.NecromancerError(message)
  return { name = "NecromancerError", message = message }
end

function M.ValidationError(message)
  return { name = "ValidationError", message = message }
end

function M.GitError(message)
  return { name = "GitError", message = message }
end

function M.ConfigError(message)
  return { name = "ConfigError", message = message }
end

function M.is_necromancer_error(err)
  return type(err) == "table" and err.name ~= nil and err.message ~= nil
end

return M
