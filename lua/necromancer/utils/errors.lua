--- Error handling utilities for necromancer.nvim
--- Provides custom error types for better error classification and formatting
--- @module necromancer.utils.errors

local M = {}

--- Creates a validation error
--- Used when plugin definitions, configurations, or inputs fail validation
--- @param message string The error message describing what validation failed
--- @return table Error table with name, message, and is_necromancer_error fields
function M.ValidationError(message)
  return {
    name = 'ValidationError',
    message = message,
    is_necromancer_error = true,
  }
end

--- Creates a git operation error
--- Used when git commands (clone, fetch, checkout) fail
--- @param message string The error message describing the git operation failure
--- @return table Error table with name, message, and is_necromancer_error fields
function M.GitError(message)
  return {
    name = 'GitError',
    message = message,
    is_necromancer_error = true,
  }
end

--- Creates an installation error
--- Used when plugin installation or setup operations fail
--- @param message string The error message describing the installation failure
--- @return table Error table with name, message, and is_necromancer_error fields
function M.InstallationError(message)
  return {
    name = 'InstallationError',
    message = message,
    is_necromancer_error = true,
  }
end

--- Creates a configuration error
--- Used when configuration files are malformed or missing required fields
--- @param message string The error message describing the configuration problem
--- @return table Error table with name, message, and is_necromancer_error fields
function M.ConfigError(message)
  return {
    name = 'ConfigError',
    message = message,
    is_necromancer_error = true,
  }
end

--- Formats an error table into a user-friendly error message
--- Takes a necromancer error table and produces a formatted string suitable for display
--- @param err table Error table with name and message fields
--- @return string Formatted error message in the format "[ErrorName] message"
function M.format_error(err)
  if type(err) ~= 'table' then
    return tostring(err)
  end

  if err.is_necromancer_error then
    return string.format('[%s] %s', err.name, err.message)
  end

  -- Fallback for non-necromancer errors
  if err.message then
    return tostring(err.message)
  end

  return tostring(err)
end

return M
