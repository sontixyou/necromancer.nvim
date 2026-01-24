local lockfile = require("necromancer.core.lockfile")

describe("lockfile", function()
  local test_dir

  before_each(function()
    test_dir = vim.fn.tempname()
    vim.fn.mkdir(test_dir, "p")
  end)

  after_each(function()
    vim.fn.delete(test_dir, "rf")
  end)

  describe("create_empty", function()
    it("creates lockfile with version", function()
      local lf = lockfile.create_empty()
      assert.equals("1", lf.version)
      assert.is_table(lf.plugins)
      assert.equals(0, #lf.plugins)
    end)

    it("includes generated timestamp", function()
      local lf = lockfile.create_empty()
      assert.is_not_nil(lf.generated)
      assert.is_true(lf.generated:match("^%d%d%d%d%-%d%d%-%d%dT") ~= nil)
    end)
  end)

  describe("read", function()
    it("returns empty lockfile if file doesn't exist", function()
      local lf = lockfile.read(test_dir .. "/nonexistent.lock")
      assert.equals("1", lf.version)
      assert.equals(0, #lf.plugins)
    end)

    it("reads existing lockfile", function()
      local path = test_dir .. "/test.lock"
      local data = {
        version = "1",
        generated = "2024-01-01T00:00:00Z",
        plugins = {
          { name = "test", commit = "abc123" },
        },
      }
      vim.fn.writefile({ vim.json.encode(data) }, path)

      local lf = lockfile.read(path)
      assert.equals(1, #lf.plugins)
      assert.equals("test", lf.plugins[1].name)
    end)

    it("returns empty on invalid JSON", function()
      local path = test_dir .. "/bad.lock"
      vim.fn.writefile({ "not json" }, path)

      local lf = lockfile.read(path)
      assert.equals("1", lf.version)
      assert.equals(0, #lf.plugins)
    end)
  end)

  describe("write", function()
    it("writes lockfile to disk", function()
      local path = test_dir .. "/test.lock"
      local data = lockfile.create_empty()
      data.plugins = { { name = "test" } }

      lockfile.write(path, data)

      local lf = lockfile.read(path)
      assert.equals(1, #lf.plugins)
      assert.equals("test", lf.plugins[1].name)
    end)

    it("updates generated timestamp on write", function()
      local path = test_dir .. "/test.lock"
      local data = {
        version = "1",
        generated = "old-timestamp",
        plugins = {},
      }

      lockfile.write(path, data)

      local lf = lockfile.read(path)
      assert.is_not.equals("old-timestamp", lf.generated)
    end)
  end)

  describe("find_plugin", function()
    it("finds existing plugin", function()
      local lf = { plugins = { { name = "a" }, { name = "b" }, { name = "c" } } }
      local plugin, index = lockfile.find_plugin(lf, "b")
      assert.equals("b", plugin.name)
      assert.equals(2, index)
    end)

    it("returns nil for missing plugin", function()
      local lf = { plugins = { { name = "a" } } }
      local plugin, index = lockfile.find_plugin(lf, "missing")
      assert.is_nil(plugin)
      assert.is_nil(index)
    end)

    it("returns nil for empty plugins", function()
      local lf = { plugins = {} }
      local plugin, index = lockfile.find_plugin(lf, "test")
      assert.is_nil(plugin)
      assert.is_nil(index)
    end)
  end)

  describe("upsert_plugin", function()
    it("adds new plugin", function()
      local lf = { plugins = {} }
      lockfile.upsert_plugin(lf, { name = "new", commit = "abc" })
      assert.equals(1, #lf.plugins)
      assert.equals("new", lf.plugins[1].name)
    end)

    it("updates existing plugin", function()
      local lf = { plugins = { { name = "a", version = "1" } } }
      lockfile.upsert_plugin(lf, { name = "a", version = "2" })
      assert.equals(1, #lf.plugins)
      assert.equals("2", lf.plugins[1].version)
    end)

    it("preserves other plugins", function()
      local lf = { plugins = { { name = "a" }, { name = "b" } } }
      lockfile.upsert_plugin(lf, { name = "a", updated = true })
      assert.equals(2, #lf.plugins)
      assert.equals("b", lf.plugins[2].name)
    end)
  end)

  describe("remove_plugin", function()
    it("removes existing plugin", function()
      local lf = { plugins = { { name = "a" }, { name = "b" } } }
      local removed = lockfile.remove_plugin(lf, "a")
      assert.is_true(removed)
      assert.equals(1, #lf.plugins)
      assert.equals("b", lf.plugins[1].name)
    end)

    it("returns false for missing plugin", function()
      local lf = { plugins = { { name = "a" } } }
      local removed = lockfile.remove_plugin(lf, "missing")
      assert.is_false(removed)
      assert.equals(1, #lf.plugins)
    end)
  end)
end)
