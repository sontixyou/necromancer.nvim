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
end)
