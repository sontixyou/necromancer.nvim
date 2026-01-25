local config = require("necromancer.core.config")

describe("config", function()
  local test_dir

  before_each(function()
    test_dir = vim.fn.tempname()
    vim.fn.mkdir(test_dir, "p")
  end)

  after_each(function()
    vim.fn.delete(test_dir, "rf")
  end)

  describe("parse_config_file", function()
    it("parses valid config", function()
      local config_path = test_dir .. "/config.json"
      local data = {
        plugins = {
          {
            name = "test-plugin",
            repo = "https://github.com/owner/repo.git",
            commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
          },
        },
      }
      vim.fn.writefile({ vim.json.encode(data) }, config_path)

      local result = config.parse_config_file(config_path)
      assert.equals(1, #result.plugins)
      assert.equals("test-plugin", result.plugins[1].name)
    end)

    it("errors on invalid JSON", function()
      local config_path = test_dir .. "/config.json"
      vim.fn.writefile({ "not valid json" }, config_path)

      assert.has_error(function()
        config.parse_config_file(config_path)
      end)
    end)

    it("parses config with dependencies", function()
      local config_path = test_dir .. "/config.json"
      local data = {
        plugins = {
          { name = "parent", repo = "https://github.com/o/p.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" },
          { name = "child", repo = "https://github.com/o/c.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = { "parent" } },
        },
      }
      vim.fn.writefile({ vim.json.encode(data) }, config_path)

      local result = config.parse_config_file(config_path)
      assert.equals(2, #result.plugins)
    end)
  end)

  describe("validate_config", function()
    it("accepts valid config", function()
      local cfg = {
        plugins = {
          {
            name = "test",
            repo = "https://github.com/owner/repo.git",
            commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
          },
        },
      }
      assert.has_no_error(function()
        config.validate_config(cfg)
      end)
    end)

    it("errors on missing plugins array", function()
      assert.has_error(function()
        config.validate_config({})
      end)
    end)

    it("errors on empty plugins array", function()
      assert.has_error(function()
        config.validate_config({ plugins = {} })
      end)
    end)

    it("errors on missing name", function()
      local cfg = {
        plugins = {
          { repo = "https://github.com/o/r.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" },
        },
      }
      assert.has_error(function()
        config.validate_config(cfg)
      end)
    end)

    it("errors on invalid commit hash", function()
      local cfg = {
        plugins = {
          { name = "test", repo = "https://github.com/o/r.git", commit = "invalid" },
        },
      }
      assert.has_error(function()
        config.validate_config(cfg)
      end)
    end)

    it("errors on duplicate plugin names", function()
      local cfg = {
        plugins = {
          { name = "test", repo = "https://github.com/o/r1.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" },
          { name = "test", repo = "https://github.com/o/r2.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" },
        },
      }
      assert.has_error(function()
        config.validate_config(cfg)
      end)
    end)

    it("errors on circular dependencies", function()
      local cfg = {
        plugins = {
          { name = "a", repo = "https://github.com/o/a.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = { "b" } },
          { name = "b", repo = "https://github.com/o/b.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = { "a" } },
        },
      }
      assert.has_error(function()
        config.validate_config(cfg)
      end)
    end)
  end)

  describe("update_plugins_commits", function()
    local temp_dir
    local config_path

    before_each(function()
      temp_dir = vim.fn.tempname()
      vim.fn.mkdir(temp_dir, "p")
      config_path = temp_dir .. "/.necromancer.json"
    end)

    after_each(function()
      vim.fn.delete(temp_dir, "rf")
    end)

    it("updates single plugin commit", function()
      local initial = {
        plugins = {
          {
            name = "plugin-a",
            repo = "https://github.com/owner/plugin-a",
            commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
          },
        },
      }
      vim.fn.writefile({ vim.json.encode(initial) }, config_path)

      local updates = {
        { name = "plugin-a", commit = "b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3" },
      }
      config.update_plugins_commits(config_path, updates)

      local result = config.parse_config_file(config_path)
      assert.equals("b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3", result.plugins[1].commit)
    end)

    it("updates multiple plugin commits", function()
      local initial = {
        plugins = {
          {
            name = "plugin-a",
            repo = "https://github.com/owner/plugin-a",
            commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
          },
          {
            name = "plugin-b",
            repo = "https://github.com/owner/plugin-b",
            commit = "c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4",
          },
        },
      }
      vim.fn.writefile({ vim.json.encode(initial) }, config_path)

      local updates = {
        { name = "plugin-a", commit = "1111111111111111111111111111111111111111" },
        { name = "plugin-b", commit = "2222222222222222222222222222222222222222" },
      }
      config.update_plugins_commits(config_path, updates)

      local result = config.parse_config_file(config_path)
      assert.equals("1111111111111111111111111111111111111111", result.plugins[1].commit)
      assert.equals("2222222222222222222222222222222222222222", result.plugins[2].commit)
    end)

    it("preserves other plugin fields", function()
      local initial = {
        plugins = {
          {
            name = "dep1",
            repo = "https://github.com/owner/dep1",
            commit = "d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1",
          },
          {
            name = "plugin-a",
            repo = "https://github.com/owner/plugin-a",
            commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
            branch = "main",
            dependencies = { "dep1" },
          },
        },
      }
      vim.fn.writefile({ vim.json.encode(initial) }, config_path)

      local updates = {
        { name = "plugin-a", commit = "b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3" },
      }
      config.update_plugins_commits(config_path, updates)

      local result = config.parse_config_file(config_path)
      -- Find plugin-a in the result (order may change due to JSON encoding)
      local plugin_a
      for _, p in ipairs(result.plugins) do
        if p.name == "plugin-a" then
          plugin_a = p
          break
        end
      end
      assert.is_not_nil(plugin_a)
      assert.equals("main", plugin_a.branch)
      assert.same({ "dep1" }, plugin_a.dependencies)
    end)

    it("skips plugins not in updates", function()
      local initial = {
        plugins = {
          {
            name = "plugin-a",
            repo = "https://github.com/owner/plugin-a",
            commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
          },
          {
            name = "plugin-b",
            repo = "https://github.com/owner/plugin-b",
            commit = "c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4",
          },
        },
      }
      vim.fn.writefile({ vim.json.encode(initial) }, config_path)

      local updates = {
        { name = "plugin-a", commit = "1111111111111111111111111111111111111111" },
      }
      config.update_plugins_commits(config_path, updates)

      local result = config.parse_config_file(config_path)
      assert.equals("1111111111111111111111111111111111111111", result.plugins[1].commit)
      assert.equals("c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4", result.plugins[2].commit)
    end)
  end)
end)
