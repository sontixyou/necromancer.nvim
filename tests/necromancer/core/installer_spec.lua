local installer = require("necromancer.core.installer")
local git = require("necromancer.core.git")

describe("installer", function()
  local test_dir
  local test_repo
  local commit1
  local commit2

  before_each(function()
    -- Create temp directory
    test_dir = vim.fn.tempname()
    vim.fn.mkdir(test_dir, "p")

    -- Create a test git repo with two commits
    test_repo = test_dir .. "/test-repo"
    vim.fn.mkdir(test_repo, "p")

    vim.fn.system({ "git", "-C", test_repo, "init" })
    vim.fn.system({ "git", "-C", test_repo, "config", "user.email", "test@test.com" })
    vim.fn.system({ "git", "-C", test_repo, "config", "user.name", "Test" })

    -- Create first commit
    vim.fn.writefile({ "content 1" }, test_repo .. "/file.txt")
    vim.fn.system({ "git", "-C", test_repo, "add", "." })
    vim.fn.system({ "git", "-C", test_repo, "commit", "-m", "first commit" })
    commit1 = vim.trim(vim.fn.system({ "git", "-C", test_repo, "rev-parse", "HEAD" }))

    -- Create second commit
    vim.fn.writefile({ "content 2" }, test_repo .. "/file.txt")
    vim.fn.system({ "git", "-C", test_repo, "add", "." })
    vim.fn.system({ "git", "-C", test_repo, "commit", "-m", "second commit" })
    commit2 = vim.trim(vim.fn.system({ "git", "-C", test_repo, "rev-parse", "HEAD" }))
  end)

  after_each(function()
    -- Cleanup
    vim.fn.delete(test_dir, "rf")
  end)

  describe("verify_installation", function()
    it("returns true for valid installation", function()
      -- Clone the repo to a target path
      local target_path = test_dir .. "/installed-plugin"
      git.clone(test_repo, target_path)
      git.checkout(target_path, commit1)

      local installed = {
        name = "test-plugin",
        repo = test_repo,
        commit = commit1,
        path = target_path,
        installedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      }

      local valid, err = installer.verify_installation(installed)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("returns false when directory does not exist", function()
      local installed = {
        name = "test-plugin",
        repo = test_repo,
        commit = commit1,
        path = test_dir .. "/nonexistent",
        installedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      }

      local valid, err = installer.verify_installation(installed)
      assert.is_false(valid)
      assert.is_not_nil(err)
    end)

    it("returns false when directory is not a git repo", function()
      local non_git_dir = test_dir .. "/not-git"
      vim.fn.mkdir(non_git_dir, "p")
      vim.fn.writefile({ "some content" }, non_git_dir .. "/file.txt")

      local installed = {
        name = "test-plugin",
        repo = test_repo,
        commit = commit1,
        path = non_git_dir,
        installedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      }

      local valid, err = installer.verify_installation(installed)
      assert.is_false(valid)
      assert.is_not_nil(err)
    end)
  end)

  describe("repair_plugin", function()
    it("restores a missing plugin directory", function()
      local target_path = test_dir .. "/plugin-to-repair"

      local def = {
        name = "test-plugin",
        repo = test_repo,
        commit = commit1,
      }

      local success, err = installer.repair_plugin(def, target_path)
      assert.is_true(success)
      assert.is_nil(err)

      -- Verify the repo is properly installed
      assert.equals(1, vim.fn.isdirectory(target_path))
      local current = git.get_current_commit(target_path)
      assert.equals(commit1, current)
    end)

    it("removes corrupted directory and re-clones", function()
      -- Create a corrupted installation (directory but not git repo)
      local target_path = test_dir .. "/corrupted-plugin"
      vim.fn.mkdir(target_path, "p")
      vim.fn.writefile({ "corrupt" }, target_path .. "/file.txt")

      local def = {
        name = "test-plugin",
        repo = test_repo,
        commit = commit1,
      }

      local success, err = installer.repair_plugin(def, target_path)
      assert.is_true(success)
      assert.is_nil(err)

      -- Verify the repo is properly installed now
      assert.equals(1, vim.fn.isdirectory(target_path .. "/.git"))
      local current = git.get_current_commit(target_path)
      assert.equals(commit1, current)
    end)
  end)

  describe("install_plugin", function()
    it("clones a new plugin", function()
      local install_dir = test_dir .. "/plugins"
      vim.fn.mkdir(install_dir, "p")

      local def = {
        name = "test-plugin",
        repo = test_repo,
        commit = commit1,
      }

      local result = installer.install_plugin(def, install_dir)

      assert.is_true(result.success)
      assert.equals("test-plugin", result.name)
      assert.equals("installed", result.action)
      assert.is_not_nil(result.installed_at)

      -- Verify plugin was installed
      local plugin_path = install_dir .. "/test-plugin"
      assert.equals(1, vim.fn.isdirectory(plugin_path))
      local current = git.get_current_commit(plugin_path)
      assert.equals(commit1, current)
    end)

    it("updates existing plugin to new commit", function()
      local install_dir = test_dir .. "/plugins"
      local plugin_path = install_dir .. "/test-plugin"
      vim.fn.mkdir(install_dir, "p")

      -- First, install at commit1
      git.clone(test_repo, plugin_path)
      git.checkout(plugin_path, commit1)

      -- Now try to install at commit2
      local def = {
        name = "test-plugin",
        repo = test_repo,
        commit = commit2,
      }

      local result = installer.install_plugin(def, install_dir)

      assert.is_true(result.success)
      assert.equals("test-plugin", result.name)
      assert.equals("updated", result.action)

      -- Verify commit was updated
      local current = git.get_current_commit(plugin_path)
      assert.equals(commit2, current)
    end)

    it("skips plugin already at correct commit", function()
      local install_dir = test_dir .. "/plugins"
      local plugin_path = install_dir .. "/test-plugin"
      vim.fn.mkdir(install_dir, "p")

      -- Install at commit1
      git.clone(test_repo, plugin_path)
      git.checkout(plugin_path, commit1)

      -- Try to install same commit again
      local def = {
        name = "test-plugin",
        repo = test_repo,
        commit = commit1,
      }

      local result = installer.install_plugin(def, install_dir)

      assert.is_true(result.success)
      assert.equals("test-plugin", result.name)
      assert.equals("skipped", result.action)
    end)

    it("repairs corrupted installation", function()
      local install_dir = test_dir .. "/plugins"
      local plugin_path = install_dir .. "/test-plugin"
      vim.fn.mkdir(plugin_path, "p")

      -- Create corrupted installation (directory without .git)
      vim.fn.writefile({ "corrupt" }, plugin_path .. "/file.txt")

      local def = {
        name = "test-plugin",
        repo = test_repo,
        commit = commit1,
      }

      local result = installer.install_plugin(def, install_dir)

      assert.is_true(result.success)
      assert.equals("test-plugin", result.name)
      assert.equals("installed", result.action)
      assert.is_not_nil(result.message)
      assert.is_true(result.message:find("repaired") ~= nil)

      -- Verify plugin is properly installed now
      local current = git.get_current_commit(plugin_path)
      assert.equals(commit1, current)
    end)
  end)

  describe("install_all", function()
    it("installs multiple plugins", function()
      local install_dir = test_dir .. "/plugins"
      vim.fn.mkdir(install_dir, "p")

      -- Create a second test repo
      local test_repo2 = test_dir .. "/test-repo2"
      vim.fn.mkdir(test_repo2, "p")
      vim.fn.system({ "git", "-C", test_repo2, "init" })
      vim.fn.system({ "git", "-C", test_repo2, "config", "user.email", "test@test.com" })
      vim.fn.system({ "git", "-C", test_repo2, "config", "user.name", "Test" })
      vim.fn.writefile({ "repo2 content" }, test_repo2 .. "/file.txt")
      vim.fn.system({ "git", "-C", test_repo2, "add", "." })
      vim.fn.system({ "git", "-C", test_repo2, "commit", "-m", "initial" })
      local repo2_commit = vim.trim(vim.fn.system({ "git", "-C", test_repo2, "rev-parse", "HEAD" }))

      local plugins = {
        { name = "plugin-a", repo = test_repo, commit = commit1 },
        { name = "plugin-b", repo = test_repo2, commit = repo2_commit },
      }

      local results = installer.install_all(plugins, install_dir)

      assert.equals(2, #results)
      assert.is_true(results[1].success)
      assert.is_true(results[2].success)

      -- Verify both plugins installed
      assert.equals(1, vim.fn.isdirectory(install_dir .. "/plugin-a"))
      assert.equals(1, vim.fn.isdirectory(install_dir .. "/plugin-b"))
    end)

    it("respects dependency order", function()
      local install_dir = test_dir .. "/plugins"
      vim.fn.mkdir(install_dir, "p")

      -- Create repos for dependency chain: plenary <- telescope <- telescope-ui
      local plenary_repo = test_dir .. "/plenary"
      vim.fn.mkdir(plenary_repo, "p")
      vim.fn.system({ "git", "-C", plenary_repo, "init" })
      vim.fn.system({ "git", "-C", plenary_repo, "config", "user.email", "test@test.com" })
      vim.fn.system({ "git", "-C", plenary_repo, "config", "user.name", "Test" })
      vim.fn.writefile({ "plenary" }, plenary_repo .. "/file.txt")
      vim.fn.system({ "git", "-C", plenary_repo, "add", "." })
      vim.fn.system({ "git", "-C", plenary_repo, "commit", "-m", "initial" })
      local plenary_commit = vim.trim(vim.fn.system({ "git", "-C", plenary_repo, "rev-parse", "HEAD" }))

      local telescope_repo = test_dir .. "/telescope"
      vim.fn.mkdir(telescope_repo, "p")
      vim.fn.system({ "git", "-C", telescope_repo, "init" })
      vim.fn.system({ "git", "-C", telescope_repo, "config", "user.email", "test@test.com" })
      vim.fn.system({ "git", "-C", telescope_repo, "config", "user.name", "Test" })
      vim.fn.writefile({ "telescope" }, telescope_repo .. "/file.txt")
      vim.fn.system({ "git", "-C", telescope_repo, "add", "." })
      vim.fn.system({ "git", "-C", telescope_repo, "commit", "-m", "initial" })
      local telescope_commit = vim.trim(vim.fn.system({ "git", "-C", telescope_repo, "rev-parse", "HEAD" }))

      local ui_repo = test_dir .. "/telescope-ui"
      vim.fn.mkdir(ui_repo, "p")
      vim.fn.system({ "git", "-C", ui_repo, "init" })
      vim.fn.system({ "git", "-C", ui_repo, "config", "user.email", "test@test.com" })
      vim.fn.system({ "git", "-C", ui_repo, "config", "user.name", "Test" })
      vim.fn.writefile({ "ui" }, ui_repo .. "/file.txt")
      vim.fn.system({ "git", "-C", ui_repo, "add", "." })
      vim.fn.system({ "git", "-C", ui_repo, "commit", "-m", "initial" })
      local ui_commit = vim.trim(vim.fn.system({ "git", "-C", ui_repo, "rev-parse", "HEAD" }))

      -- Define plugins with dependencies in reverse order
      local plugins = {
        { name = "telescope-ui", repo = ui_repo, commit = ui_commit, dependencies = { "telescope" } },
        { name = "telescope", repo = telescope_repo, commit = telescope_commit, dependencies = { "plenary" } },
        { name = "plenary", repo = plenary_repo, commit = plenary_commit },
      }

      local results = installer.install_all(plugins, install_dir)

      -- All should succeed
      assert.equals(3, #results)
      for _, result in ipairs(results) do
        assert.is_true(result.success, "Failed: " .. result.name .. " " .. (result.message or ""))
      end

      -- Verify installation order: plenary first, telescope second, ui third
      assert.equals("plenary", results[1].name)
      assert.equals("telescope", results[2].name)
      assert.equals("telescope-ui", results[3].name)
    end)
  end)
end)
