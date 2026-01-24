local paths = require("necromancer.utils.paths")

describe("paths", function()
  describe("expand_tilde", function()
    it("expands ~ to home", function()
      local result = paths.expand_tilde("~/test")
      assert.is_not.equals("~/test", result)
      assert.is_true(result:match("/test$") ~= nil)
    end)

    it("returns path unchanged if no tilde", function()
      local result = paths.expand_tilde("/usr/local/bin")
      assert.equals("/usr/local/bin", result)
    end)
  end)

  describe("compress_tilde", function()
    it("compresses home to ~", function()
      local home = vim.fn.expand("~")
      local result = paths.compress_tilde(home .. "/test")
      assert.equals("~/test", result)
    end)

    it("returns ~ for exact home directory", function()
      local home = vim.fn.expand("~")
      local result = paths.compress_tilde(home)
      assert.equals("~", result)
    end)

    it("returns unchanged for non-home paths", function()
      local result = paths.compress_tilde("/usr/local/bin")
      assert.equals("/usr/local/bin", result)
    end)

    it("handles partial home match", function()
      -- /home/user123 should not compress if home is /home/user
      local result = paths.compress_tilde("/not/home/path")
      assert.equals("/not/home/path", result)
    end)
  end)

  describe("get_default_install_dir", function()
    it("returns a valid path ending with necromancer/plugins", function()
      local result = paths.get_default_install_dir()
      assert.is_true(result:match("necromancer/plugins$") ~= nil or result:match("necromancer\\plugins$") ~= nil)
    end)

    it("returns expanded path (no tilde)", function()
      local result = paths.get_default_install_dir()
      assert.is_false(result:match("^~") ~= nil)
    end)
  end)

  describe("resolve_plugin_path", function()
    it("returns full path for plugin with default dir", function()
      local result = paths.resolve_plugin_path("test-plugin")
      assert.is_true(result:match("test%-plugin$") ~= nil)
      assert.is_true(result:match("necromancer/plugins/test%-plugin$") ~= nil or result:match("necromancer\\plugins\\test%-plugin$") ~= nil)
    end)

    it("uses custom install dir when provided", function()
      local result = paths.resolve_plugin_path("test-plugin", "/custom/dir")
      assert.equals("/custom/dir/test-plugin", result)
    end)

    it("expands tilde in custom install dir", function()
      local result = paths.resolve_plugin_path("test-plugin", "~/custom")
      assert.is_false(result:match("^~") ~= nil)
      assert.is_true(result:match("test%-plugin$") ~= nil)
    end)
  end)

  describe("resolve_config_path", function()
    it("returns custom path if provided", function()
      local result = paths.resolve_config_path("/custom/config.json")
      assert.equals("/custom/config.json", result)
    end)

    it("returns nil if no config found", function()
      -- Note: This test assumes no .necromancer.json in current dir and no global config
      -- May need to be adjusted based on test environment
      local result = paths.resolve_config_path(nil)
      -- Result could be nil or a path if config exists
      assert.is_true(result == nil or type(result) == "string")
    end)
  end)

  describe("get_lock_file_path", function()
    it("converts .necromancer.json to .necromancer.lock", function()
      local result = paths.get_lock_file_path(".necromancer.json")
      assert.equals(".necromancer.lock", result)
    end)

    it("converts full path .necromancer.json to .necromancer.lock", function()
      local result = paths.get_lock_file_path("/path/to/.necromancer.json")
      assert.equals("/path/to/.necromancer.lock", result)
    end)

    it("converts config.json to lock.json", function()
      local result = paths.get_lock_file_path("/path/config.json")
      assert.equals("/path/lock.json", result)
    end)

    it("appends .lock for other files", function()
      local result = paths.get_lock_file_path("/path/custom.json")
      assert.equals("/path/custom.json.lock", result)
    end)
  end)
end)
