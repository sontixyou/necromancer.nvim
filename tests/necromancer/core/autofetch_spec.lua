local autofetch = require("necromancer.core.autofetch")

describe("autofetch", function()
  describe("normalize_opts", function()
    it("returns defaults when opts is nil", function()
      local result = autofetch.normalize_opts(nil)
      assert.equals(true, result.enabled)
      assert.equals(true, result.notify_updates)
      assert.equals(false, result.quiet)
    end)

    it("returns defaults when opts is true", function()
      local result = autofetch.normalize_opts(true)
      assert.equals(true, result.enabled)
      assert.equals(true, result.notify_updates)
      assert.equals(false, result.quiet)
    end)

    it("disables when opts is false", function()
      local result = autofetch.normalize_opts(false)
      assert.equals(false, result.enabled)
      assert.equals(true, result.notify_updates)
      assert.equals(false, result.quiet)
    end)

    it("uses table options when provided", function()
      local result = autofetch.normalize_opts({
        enabled = true,
        notify_updates = false,
        quiet = true,
      })
      assert.equals(true, result.enabled)
      assert.equals(false, result.notify_updates)
      assert.equals(true, result.quiet)
    end)

    it("defaults enabled to true when not specified in table", function()
      local result = autofetch.normalize_opts({
        quiet = true,
      })
      assert.equals(true, result.enabled)
    end)

    it("defaults notify_updates to true when not specified in table", function()
      local result = autofetch.normalize_opts({
        enabled = true,
      })
      assert.equals(true, result.notify_updates)
    end)

    it("defaults quiet to false when not specified in table", function()
      local result = autofetch.normalize_opts({
        enabled = true,
      })
      assert.equals(false, result.quiet)
    end)

    it("handles enabled=false in table", function()
      local result = autofetch.normalize_opts({
        enabled = false,
      })
      assert.equals(false, result.enabled)
    end)
  end)

  describe("autofetch", function()
    it("does not error on non-git directory", function()
      local tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")

      -- Should not throw an error
      local ok, err = pcall(function()
        autofetch.autofetch(tmp_dir, { enabled = true, notify_updates = true, quiet = true })
      end)

      vim.fn.delete(tmp_dir, "rf")
      assert.is_true(ok, "Should not error: " .. tostring(err))
    end)

    it("does not error on non-existent directory", function()
      local non_existent = "/non/existent/path/12345"

      -- Should not throw an error
      local ok, err = pcall(function()
        autofetch.autofetch(non_existent, { enabled = true, notify_updates = true, quiet = true })
      end)

      assert.is_true(ok, "Should not error: " .. tostring(err))
    end)
  end)

  describe("start", function()
    it("does not error when disabled", function()
      local ok, err = pcall(function()
        autofetch.start(false)
      end)
      assert.is_true(ok, "Should not error: " .. tostring(err))
    end)

    it("does not error with default options", function()
      -- Note: This may trigger actual fetch if running in a git repo
      -- Using quiet mode to suppress any debug messages
      local ok, err = pcall(function()
        autofetch.start({ quiet = true })
      end)
      assert.is_true(ok, "Should not error: " .. tostring(err))
    end)
  end)
end)
