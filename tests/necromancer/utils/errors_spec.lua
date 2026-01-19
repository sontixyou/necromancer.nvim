--- Unit tests for necromancer.utils.errors module
--- Tests all error constructors and the format_error function

describe('necromancer.utils.errors', function()
  local errors

  before_each(function()
    errors = require('necromancer.utils.errors')
  end)

  describe('ValidationError', function()
    it('creates an error table with correct structure', function()
      local err = errors.ValidationError('Invalid plugin definition')

      assert.are.equal('ValidationError', err.name)
      assert.are.equal('Invalid plugin definition', err.message)
      assert.is_true(err.is_necromancer_error)
    end)

    it('preserves the exact message passed', function()
      local message = 'Commit hash must be 40 characters'
      local err = errors.ValidationError(message)

      assert.are.equal(message, err.message)
    end)

    it('creates unique error instances', function()
      local err1 = errors.ValidationError('Error 1')
      local err2 = errors.ValidationError('Error 2')

      assert.are_not.equal(err1, err2)
      assert.are_not.equal(err1.message, err2.message)
    end)
  end)

  describe('GitError', function()
    it('creates an error table with correct structure', function()
      local err = errors.GitError('Failed to clone repository')

      assert.are.equal('GitError', err.name)
      assert.are.equal('Failed to clone repository', err.message)
      assert.is_true(err.is_necromancer_error)
    end)

    it('handles git command error messages', function()
      local message = 'git clone failed: repository not found'
      local err = errors.GitError(message)

      assert.are.equal(message, err.message)
      assert.are.equal('GitError', err.name)
    end)
  end)

  describe('InstallationError', function()
    it('creates an error table with correct structure', function()
      local err = errors.InstallationError('Plugin installation failed')

      assert.are.equal('InstallationError', err.name)
      assert.are.equal('Plugin installation failed', err.message)
      assert.is_true(err.is_necromancer_error)
    end)

    it('preserves detailed installation failure messages', function()
      local message = 'Failed to install plenary.nvim: disk full'
      local err = errors.InstallationError(message)

      assert.are.equal(message, err.message)
    end)
  end)

  describe('ConfigError', function()
    it('creates an error table with correct structure', function()
      local err = errors.ConfigError('Missing required field: url')

      assert.are.equal('ConfigError', err.name)
      assert.are.equal('Missing required field: url', err.message)
      assert.is_true(err.is_necromancer_error)
    end)

    it('handles configuration parsing errors', function()
      local message = 'Invalid JSON in necromancer.json'
      local err = errors.ConfigError(message)

      assert.are.equal(message, err.message)
      assert.are.equal('ConfigError', err.name)
    end)
  end)

  describe('format_error', function()
    it('formats necromancer errors with name and message', function()
      local err = errors.ValidationError('Test validation error')
      local formatted = errors.format_error(err)

      assert.are.equal('[ValidationError] Test validation error', formatted)
    end)

    it('formats GitError correctly', function()
      local err = errors.GitError('Clone failed')
      local formatted = errors.format_error(err)

      assert.are.equal('[GitError] Clone failed', formatted)
    end)

    it('formats InstallationError correctly', function()
      local err = errors.InstallationError('Install failed')
      local formatted = errors.format_error(err)

      assert.are.equal('[InstallationError] Install failed', formatted)
    end)

    it('formats ConfigError correctly', function()
      local err = errors.ConfigError('Invalid config')
      local formatted = errors.format_error(err)

      assert.are.equal('[ConfigError] Invalid config', formatted)
    end)

    it('handles non-necromancer error tables with message field', function()
      local err = { message = 'Generic error' }
      local formatted = errors.format_error(err)

      assert.are.equal('Generic error', formatted)
    end)

    it('handles non-table errors by converting to string', function()
      local formatted = errors.format_error('Plain string error')

      assert.are.equal('Plain string error', formatted)
    end)

    it('handles nil errors gracefully', function()
      local formatted = errors.format_error(nil)

      assert.are.equal('nil', formatted)
    end)

    it('handles number errors by converting to string', function()
      local formatted = errors.format_error(42)

      assert.are.equal('42', formatted)
    end)

    it('handles error tables without message field', function()
      local err = { some_field = 'value' }
      local formatted = errors.format_error(err)

      -- Should convert table to string representation
      assert.is_not_nil(formatted)
      assert.is_string(formatted)
    end)

    it('preserves error message content exactly', function()
      local message = 'Error with special chars: []{}<>!@#$%^&*()'
      local err = errors.ValidationError(message)
      local formatted = errors.format_error(err)

      assert.is_true(string.find(formatted, message, 1, true) ~= nil)
    end)

    it('formats multiline error messages', function()
      local message = 'Line 1\nLine 2\nLine 3'
      local err = errors.ConfigError(message)
      local formatted = errors.format_error(err)

      assert.are.equal('[ConfigError] Line 1\nLine 2\nLine 3', formatted)
    end)
  end)

  describe('error table structure consistency', function()
    it('all error types have the same structure', function()
      local validation_err = errors.ValidationError('msg')
      local git_err = errors.GitError('msg')
      local install_err = errors.InstallationError('msg')
      local config_err = errors.ConfigError('msg')

      -- Check that all have the same keys
      local function get_keys(tbl)
        local keys = {}
        for k, _ in pairs(tbl) do
          table.insert(keys, k)
        end
        table.sort(keys)
        return keys
      end

      local validation_keys = get_keys(validation_err)
      local git_keys = get_keys(git_err)
      local install_keys = get_keys(install_err)
      local config_keys = get_keys(config_err)

      assert.are.same(validation_keys, git_keys)
      assert.are.same(git_keys, install_keys)
      assert.are.same(install_keys, config_keys)
    end)

    it('all error types have is_necromancer_error set to true', function()
      assert.is_true(errors.ValidationError('msg').is_necromancer_error)
      assert.is_true(errors.GitError('msg').is_necromancer_error)
      assert.is_true(errors.InstallationError('msg').is_necromancer_error)
      assert.is_true(errors.ConfigError('msg').is_necromancer_error)
    end)

    it('all error types have unique names', function()
      local names = {
        errors.ValidationError('msg').name,
        errors.GitError('msg').name,
        errors.InstallationError('msg').name,
        errors.ConfigError('msg').name,
      }

      -- Check uniqueness
      local seen = {}
      for _, name in ipairs(names) do
        assert.is_nil(seen[name], 'Duplicate error name: ' .. name)
        seen[name] = true
      end

      -- Check we have exactly 4 unique names
      local count = 0
      for _ in pairs(seen) do
        count = count + 1
      end
      assert.are.equal(4, count)
    end)
  end)
end)
