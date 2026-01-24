local dependencies = require("necromancer.core.dependencies")

describe("dependencies", function()
  describe("resolve_dependencies", function()
    it("returns plugins in order when no dependencies", function()
      local plugins = {
        { name = "a", repo = "https://github.com/o/a.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" },
        { name = "b", repo = "https://github.com/o/b.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" },
      }
      local result = dependencies.resolve_dependencies(plugins)
      assert.equals(2, #result)
    end)

    it("orders plugins by dependencies", function()
      local plugins = {
        { name = "child", repo = "https://github.com/o/c.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = { "parent" } },
        { name = "parent", repo = "https://github.com/o/p.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" },
      }
      local result = dependencies.resolve_dependencies(plugins)
      assert.equals("parent", result[1].name)
      assert.equals("child", result[2].name)
    end)

    it("handles transitive dependencies", function()
      local plugins = {
        { name = "c", repo = "https://github.com/o/c.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = { "b" } },
        { name = "b", repo = "https://github.com/o/b.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = { "a" } },
        { name = "a", repo = "https://github.com/o/a.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" },
      }
      local result = dependencies.resolve_dependencies(plugins)
      assert.equals("a", result[1].name)
      assert.equals("b", result[2].name)
      assert.equals("c", result[3].name)
    end)

    it("handles multiple dependencies", function()
      local plugins = {
        { name = "app", repo = "https://github.com/o/a.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = { "lib1", "lib2" } },
        { name = "lib1", repo = "https://github.com/o/l1.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" },
        { name = "lib2", repo = "https://github.com/o/l2.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" },
      }
      local result = dependencies.resolve_dependencies(plugins)
      -- app should be last
      assert.equals("app", result[3].name)
      -- lib1 and lib2 should be before app
      local lib1_idx, lib2_idx
      for i, p in ipairs(result) do
        if p.name == "lib1" then lib1_idx = i end
        if p.name == "lib2" then lib2_idx = i end
      end
      assert.is_true(lib1_idx < 3)
      assert.is_true(lib2_idx < 3)
    end)

    it("errors on circular dependency", function()
      local plugins = {
        { name = "a", repo = "https://github.com/o/a.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = { "b" } },
        { name = "b", repo = "https://github.com/o/b.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = { "a" } },
      }
      assert.has_error(function()
        dependencies.resolve_dependencies(plugins)
      end)
    end)

    it("errors on self dependency", function()
      local plugins = {
        { name = "a", repo = "https://github.com/o/a.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = { "a" } },
      }
      assert.has_error(function()
        dependencies.resolve_dependencies(plugins)
      end)
    end)

    it("errors on missing dependency", function()
      local plugins = {
        { name = "a", repo = "https://github.com/o/a.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = { "missing" } },
      }
      assert.has_error(function()
        dependencies.resolve_dependencies(plugins)
      end)
    end)

    it("handles empty dependencies array", function()
      local plugins = {
        { name = "a", repo = "https://github.com/o/a.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = {} },
      }
      local result = dependencies.resolve_dependencies(plugins)
      assert.equals(1, #result)
      assert.equals("a", result[1].name)
    end)

    it("handles diamond dependencies", function()
      -- Diamond: D depends on B and C, both B and C depend on A
      local plugins = {
        { name = "d", repo = "https://github.com/o/d.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = { "b", "c" } },
        { name = "b", repo = "https://github.com/o/b.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = { "a" } },
        { name = "c", repo = "https://github.com/o/c.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = { "a" } },
        { name = "a", repo = "https://github.com/o/a.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" },
      }
      local result = dependencies.resolve_dependencies(plugins)
      -- A must be first
      assert.equals("a", result[1].name)
      -- D must be last
      assert.equals("d", result[4].name)
      -- B and C must be in the middle (order between them doesn't matter)
      local b_idx, c_idx
      for i, p in ipairs(result) do
        if p.name == "b" then b_idx = i end
        if p.name == "c" then c_idx = i end
      end
      assert.is_true(b_idx > 1 and b_idx < 4)
      assert.is_true(c_idx > 1 and c_idx < 4)
    end)

    it("handles empty plugins array", function()
      local result = dependencies.resolve_dependencies({})
      assert.equals(0, #result)
    end)

    it("handles complex dependency chain", function()
      -- telescope-ui-select -> telescope -> plenary
      local plugins = {
        { name = "telescope-ui-select.nvim", repo = "https://github.com/nvim-telescope/telescope-ui-select.nvim.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = { "telescope.nvim" } },
        { name = "telescope.nvim", repo = "https://github.com/nvim-telescope/telescope.nvim.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = { "plenary.nvim" } },
        { name = "plenary.nvim", repo = "https://github.com/nvim-lua/plenary.nvim.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" },
      }
      local result = dependencies.resolve_dependencies(plugins)
      assert.equals("plenary.nvim", result[1].name)
      assert.equals("telescope.nvim", result[2].name)
      assert.equals("telescope-ui-select.nvim", result[3].name)
    end)
  end)

  describe("validate_dependencies", function()
    it("does not error for valid dependencies", function()
      local plugins = {
        { name = "child", repo = "https://github.com/o/c.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = { "parent" } },
        { name = "parent", repo = "https://github.com/o/p.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" },
      }
      assert.has_no.errors(function()
        dependencies.validate_dependencies(plugins)
      end)
    end)

    it("errors for invalid dependencies", function()
      local plugins = {
        { name = "a", repo = "https://github.com/o/a.git", commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", dependencies = { "missing" } },
      }
      assert.has_error(function()
        dependencies.validate_dependencies(plugins)
      end)
    end)
  end)
end)
