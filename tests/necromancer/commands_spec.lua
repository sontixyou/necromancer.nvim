local commands = require("necromancer.commands")
local paths = require("necromancer.utils.paths")
local lockfile = require("necromancer.core.lockfile")

describe("commands", function()
  local test_dir
  local original_cwd

  before_each(function()
    -- Save current directory
    original_cwd = vim.fn.getcwd()

    -- Create temp directory for tests
    test_dir = vim.fn.tempname()
    vim.fn.mkdir(test_dir, "p")
    vim.fn.chdir(test_dir)
  end)

  after_each(function()
    -- Restore original directory
    vim.fn.chdir(original_cwd)
    -- Cleanup
    vim.fn.delete(test_dir, "rf")
    -- Clean up command if registered
    pcall(vim.api.nvim_del_user_command, "Necromancer")
  end)

  describe("setup", function()
    it("registers :Necromancer command", function()
      commands.setup()

      -- Check that command exists
      local cmds = vim.api.nvim_get_commands({})
      assert.is_not_nil(cmds.Necromancer)
    end)
  end)

  describe("cmd_init", function()
    it("creates a new config file", function()
      commands.cmd_init()

      -- Check file was created
      assert.equals(1, vim.fn.filereadable(".necromancer.json"))

      -- Verify content is valid JSON
      local content = table.concat(vim.fn.readfile(".necromancer.json"), "\n")
      local ok, config = pcall(vim.json.decode, content)
      assert.is_true(ok)
      assert.is_not_nil(config.plugins)
      assert.equals(1, #config.plugins)
      assert.equals("plenary.nvim", config.plugins[1].name)
    end)

    it("does not overwrite existing config", function()
      -- Create existing config
      vim.fn.writefile({ '{"plugins":[]}' }, ".necromancer.json")

      commands.cmd_init()

      -- Verify original content preserved
      local content = table.concat(vim.fn.readfile(".necromancer.json"), "\n")
      local ok, config = pcall(vim.json.decode, content)
      assert.is_true(ok)
      assert.equals(0, #config.plugins)
    end)
  end)

  describe("cmd_list", function()
    it("shows message when no plugins installed", function()
      -- Create empty config
      vim.fn.writefile({ '{"plugins":[]}' }, ".necromancer.json")

      -- Create empty lock file
      local lock_path = ".necromancer.lock"
      lockfile.write(lock_path, lockfile.create_empty())

      -- This would show a notification - we just ensure it doesn't error
      commands.cmd_list()
    end)

    it("opens floating window with plugins when installed", function()
      -- Create config
      vim.fn.writefile({ '{"plugins":[]}' }, ".necromancer.json")

      -- Create lock file with a plugin
      local lock_path = ".necromancer.lock"
      local lock = lockfile.create_empty()
      lockfile.upsert_plugin(lock, {
        name = "test-plugin",
        repo = "https://github.com/test/test-plugin",
        commit = "1234567890abcdef1234567890abcdef12345678",
        path = "~/.local/share/nvim/necromancer/plugins/test-plugin",
        installedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      })
      lockfile.write(lock_path, lock)

      -- Run list command - it opens a floating window
      commands.cmd_list()

      -- Find the floating window
      local wins = vim.api.nvim_list_wins()
      local found_float = false
      for _, win in ipairs(wins) do
        local win_config = vim.api.nvim_win_get_config(win)
        if win_config.relative ~= "" then
          found_float = true
          -- Close the window
          vim.api.nvim_win_close(win, true)
          break
        end
      end

      assert.is_true(found_float, "Should open a floating window")
    end)
  end)

  describe("get_plugin_status", function()
    local git = require("necromancer.core.git")

    it("returns 'not_installed' when plugin directory does not exist", function()
      local plugin_def = {
        name = "test-plugin",
        repo = "https://github.com/test/test-plugin",
        commit = "1234567890abcdef1234567890abcdef12345678",
      }
      local install_dir = test_dir .. "/plugins"
      local lock = { plugins = {} }

      local status = commands.get_plugin_status(plugin_def, install_dir, lock)

      assert.equals("test-plugin", status.name)
      assert.equals("not_installed", status.state)
    end)

    it("returns 'corrupted' when directory exists but is not a git repo", function()
      local plugin_def = {
        name = "test-plugin",
        repo = "https://github.com/test/test-plugin",
        commit = "1234567890abcdef1234567890abcdef12345678",
      }
      local install_dir = test_dir .. "/plugins"
      local lock = { plugins = {} }

      -- Create directory without .git
      vim.fn.mkdir(install_dir .. "/test-plugin", "p")

      local status = commands.get_plugin_status(plugin_def, install_dir, lock)

      assert.equals("test-plugin", status.name)
      assert.equals("corrupted", status.state)
    end)

    it("returns 'outdated' when current commit differs from config", function()
      local plugin_def = {
        name = "test-plugin",
        repo = test_dir .. "/origin-repo",
        commit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      }
      local install_dir = test_dir .. "/plugins"
      local lock = { plugins = {} }

      -- Create origin repo
      local origin_repo = test_dir .. "/origin-repo"
      vim.fn.mkdir(origin_repo, "p")
      vim.fn.system({ "git", "-C", origin_repo, "init" })
      vim.fn.system({ "git", "-C", origin_repo, "config", "user.email", "test@test.com" })
      vim.fn.system({ "git", "-C", origin_repo, "config", "user.name", "Test" })
      vim.fn.writefile({ "test" }, origin_repo .. "/file.txt")
      vim.fn.system({ "git", "-C", origin_repo, "add", "." })
      vim.fn.system({ "git", "-C", origin_repo, "commit", "-m", "initial" })

      -- Clone to install dir
      vim.fn.mkdir(install_dir, "p")
      git.clone(origin_repo, install_dir .. "/test-plugin")

      local status = commands.get_plugin_status(plugin_def, install_dir, lock)

      assert.equals("test-plugin", status.name)
      assert.equals("outdated", status.state)
    end)

    it("returns 'up_to_date' when current commit matches config", function()
      local origin_repo = test_dir .. "/origin-repo"
      vim.fn.mkdir(origin_repo, "p")
      vim.fn.system({ "git", "-C", origin_repo, "init" })
      vim.fn.system({ "git", "-C", origin_repo, "config", "user.email", "test@test.com" })
      vim.fn.system({ "git", "-C", origin_repo, "config", "user.name", "Test" })
      vim.fn.writefile({ "test" }, origin_repo .. "/file.txt")
      vim.fn.system({ "git", "-C", origin_repo, "add", "." })
      vim.fn.system({ "git", "-C", origin_repo, "commit", "-m", "initial" })

      local commit = git.get_current_commit(origin_repo)

      local plugin_def = {
        name = "test-plugin",
        repo = origin_repo,
        commit = commit,
      }
      local install_dir = test_dir .. "/plugins"
      local lock = { plugins = {} }

      -- Clone to install dir
      vim.fn.mkdir(install_dir, "p")
      git.clone(origin_repo, install_dir .. "/test-plugin")

      local status = commands.get_plugin_status(plugin_def, install_dir, lock)

      assert.equals("test-plugin", status.name)
      assert.equals("up_to_date", status.state)
      assert.equals(commit, status.current_commit)
    end)
  end)

  describe("cmd_status", function()
    it("shows error when config file not found", function()
      -- No config file exists
      -- This should show an error but not crash
      commands.cmd_status()
      assert.is_true(true)
    end)

    it("opens floating window with status", function()
      -- Create config with a plugin
      local cfg = {
        plugins = {
          {
            name = "plenary.nvim",
            repo = "https://github.com/nvim-lua/plenary.nvim",
            commit = "a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683",
          },
        },
      }
      vim.fn.writefile({ vim.json.encode(cfg) }, ".necromancer.json")

      -- Run status command
      commands.cmd_status()

      -- Find the floating window
      local wins = vim.api.nvim_list_wins()
      local found_float = false
      for _, win in ipairs(wins) do
        local win_config = vim.api.nvim_win_get_config(win)
        if win_config.relative ~= "" then
          found_float = true
          vim.api.nvim_win_close(win, true)
          break
        end
      end

      assert.is_true(found_float, "Should open a floating window")
    end)
  end)

  describe("cmd_install", function()
    it("shows error when config file not found", function()
      -- No config file exists
      -- This should show an error but not crash
      commands.cmd_install({})
      assert.is_true(true)
    end)

    it("shows error for non-existent plugin name", function()
      -- Create valid config with a known plugin
      local config = {
        plugins = {
          {
            name = "plenary.nvim",
            repo = "https://github.com/nvim-lua/plenary.nvim",
            commit = "a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683",
          },
        },
      }
      vim.fn.writefile({ vim.json.encode(config) }, ".necromancer.json")

      -- Try to install non-existent plugin - should not crash
      commands.cmd_install({ "nonexistent-plugin" })

      -- No crash means success for this test
      assert.is_true(true)
    end)

    it("parses valid config without error", function()
      -- Create valid config
      local cfg = {
        plugins = {
          {
            name = "plenary.nvim",
            repo = "https://github.com/nvim-lua/plenary.nvim",
            commit = "a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683",
          },
        },
      }
      vim.fn.writefile({ vim.json.encode(cfg) }, ".necromancer.json")

      -- Parse should succeed
      local config = require("necromancer.core.config")
      local parsed = config.parse_config_file(".necromancer.json")
      assert.equals(1, #parsed.plugins)
      assert.equals("plenary.nvim", parsed.plugins[1].name)
    end)
  end)

  describe("cmd_update", function()
    it("shows error when config file not found", function()
      -- Change to a directory without config
      local temp_dir = vim.fn.tempname()
      vim.fn.mkdir(temp_dir, "p")
      local original_cwd = vim.fn.getcwd()
      vim.fn.chdir(temp_dir)

      local notifications = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
      end

      commands.cmd_update({})

      vim.notify = original_notify
      vim.fn.chdir(original_cwd)
      vim.fn.delete(temp_dir, "rf")

      assert.is_true(#notifications > 0)
      assert.is_true(notifications[1].msg:match("Config file not found") ~= nil)
    end)

    it("shows error for non-existent plugin name", function()
      -- Create temp dir with config
      local temp_dir = vim.fn.tempname()
      vim.fn.mkdir(temp_dir, "p")
      local config_path = temp_dir .. "/.necromancer.json"
      local config_content = vim.json.encode({
        plugins = {
          {
            name = "existing-plugin",
            repo = "https://github.com/owner/existing-plugin",
            commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
          },
        },
      })
      vim.fn.writefile({ config_content }, config_path)

      local original_cwd = vim.fn.getcwd()
      vim.fn.chdir(temp_dir)

      local notifications = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
      end

      commands.cmd_update({ "nonexistent-plugin" })

      vim.notify = original_notify
      vim.fn.chdir(original_cwd)
      vim.fn.delete(temp_dir, "rf")

      assert.is_true(#notifications > 0)
      assert.is_true(notifications[1].msg:match("Plugin not found") ~= nil)
    end)
  end)

  describe("cmd_clean", function()
    it("shows error when config file not found", function()
      local notifications = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
      end

      commands.cmd_clean()

      vim.notify = original_notify

      assert.is_true(#notifications > 0)
      assert.is_true(notifications[1].msg:match("Config file not found") ~= nil)
    end)

    it("shows message when install directory does not exist", function()
      -- Create config with at least one plugin (empty plugins array is invalid)
      local cfg = {
        plugins = {
          {
            name = "test-plugin",
            repo = "https://github.com/test/test-plugin",
            commit = "1234567890abcdef1234567890abcdef12345678",
          },
        },
      }
      vim.fn.writefile({ vim.json.encode(cfg) }, ".necromancer.json")

      -- Ensure install directory does not exist
      local install_dir = paths.get_default_install_dir()
      vim.fn.delete(install_dir, "rf")

      local notifications = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
      end

      commands.cmd_clean()

      vim.notify = original_notify

      assert.is_true(#notifications > 0, "Should have at least one notification")
      local found_message = false
      for _, notification in ipairs(notifications) do
        if notification.msg:match("No plugins installed") then
          found_message = true
          break
        end
      end
      assert.is_true(found_message, "Should show 'No plugins installed' message")
    end)

    it("shows message when no orphan plugins found", function()
      -- Create config with a plugin
      local cfg = {
        plugins = {
          {
            name = "test-plugin",
            repo = "https://github.com/test/test-plugin",
            commit = "1234567890abcdef1234567890abcdef12345678",
          },
        },
      }
      vim.fn.writefile({ vim.json.encode(cfg) }, ".necromancer.json")

      -- Create install directory with matching plugin only
      local install_dir = paths.get_default_install_dir()
      -- Clean up any existing plugins first
      vim.fn.delete(install_dir, "rf")
      vim.fn.mkdir(install_dir .. "/test-plugin", "p")

      local notifications = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
      end

      commands.cmd_clean()

      vim.notify = original_notify

      -- Clean up
      vim.fn.delete(install_dir, "rf")

      assert.is_true(#notifications > 0)
      local found_no_orphan = false
      for _, notification in ipairs(notifications) do
        if notification.msg:match("No orphan plugins found") then
          found_no_orphan = true
          break
        end
      end
      assert.is_true(found_no_orphan, "Should show 'No orphan plugins found' message")
    end)

    it("removes orphan plugin directories", function()
      -- Create config with only one plugin
      local cfg = {
        plugins = {
          {
            name = "configured-plugin",
            repo = "https://github.com/test/configured-plugin",
            commit = "1234567890abcdef1234567890abcdef12345678",
          },
        },
      }
      vim.fn.writefile({ vim.json.encode(cfg) }, ".necromancer.json")

      -- Create install directory with both configured and orphan plugin
      local install_dir = paths.get_default_install_dir()
      vim.fn.mkdir(install_dir .. "/configured-plugin", "p")
      vim.fn.mkdir(install_dir .. "/orphan-plugin", "p")

      local notifications = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
      end

      commands.cmd_clean()

      vim.notify = original_notify

      -- Verify orphan was removed
      assert.equals(0, vim.fn.isdirectory(install_dir .. "/orphan-plugin"))
      -- Verify configured plugin still exists
      assert.equals(1, vim.fn.isdirectory(install_dir .. "/configured-plugin"))

      -- Clean up
      vim.fn.delete(install_dir .. "/configured-plugin", "rf")

      -- Verify notifications
      local found_removed = false
      local found_complete = false
      for _, notification in ipairs(notifications) do
        if notification.msg:match("Removed orphan plugin: orphan%-plugin") then
          found_removed = true
        end
        if notification.msg:match("Clean complete: 1 orphan plugin") then
          found_complete = true
        end
      end
      assert.is_true(found_removed, "Should notify about removed plugin")
      assert.is_true(found_complete, "Should show completion message")
    end)

    it("updates lockfile when removing orphan plugins", function()
      -- Create config with only one plugin
      local cfg = {
        plugins = {
          {
            name = "configured-plugin",
            repo = "https://github.com/test/configured-plugin",
            commit = "1234567890abcdef1234567890abcdef12345678",
          },
        },
      }
      vim.fn.writefile({ vim.json.encode(cfg) }, ".necromancer.json")

      -- Create lockfile with orphan plugin entry
      local lock = lockfile.create_empty()
      lockfile.upsert_plugin(lock, {
        name = "orphan-plugin",
        repo = "https://github.com/test/orphan-plugin",
        commit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        path = "~/.local/share/nvim/necromancer/plugins/orphan-plugin",
        installedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      })
      lockfile.upsert_plugin(lock, {
        name = "configured-plugin",
        repo = "https://github.com/test/configured-plugin",
        commit = "1234567890abcdef1234567890abcdef12345678",
        path = "~/.local/share/nvim/necromancer/plugins/configured-plugin",
        installedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      })
      lockfile.write(".necromancer.lock", lock)

      -- Create install directory with orphan plugin
      local install_dir = paths.get_default_install_dir()
      vim.fn.mkdir(install_dir .. "/configured-plugin", "p")
      vim.fn.mkdir(install_dir .. "/orphan-plugin", "p")

      -- Suppress notifications
      local original_notify = vim.notify
      vim.notify = function() end

      commands.cmd_clean()

      vim.notify = original_notify

      -- Read updated lockfile
      local updated_lock = lockfile.read(".necromancer.lock")

      -- Verify orphan was removed from lockfile
      local orphan_entry = lockfile.find_plugin(updated_lock, "orphan-plugin")
      assert.is_nil(orphan_entry, "Orphan plugin should be removed from lockfile")

      -- Verify configured plugin still in lockfile
      local configured_entry = lockfile.find_plugin(updated_lock, "configured-plugin")
      assert.is_not_nil(configured_entry, "Configured plugin should remain in lockfile")

      -- Clean up
      vim.fn.delete(install_dir .. "/configured-plugin", "rf")
    end)

    it("handles multiple orphan plugins", function()
      -- Create config with one plugin
      local cfg = {
        plugins = {
          {
            name = "configured-plugin",
            repo = "https://github.com/test/configured-plugin",
            commit = "1234567890abcdef1234567890abcdef12345678",
          },
        },
      }
      vim.fn.writefile({ vim.json.encode(cfg) }, ".necromancer.json")

      -- Create install directory with multiple orphan plugins
      local install_dir = paths.get_default_install_dir()
      vim.fn.mkdir(install_dir .. "/configured-plugin", "p")
      vim.fn.mkdir(install_dir .. "/orphan-1", "p")
      vim.fn.mkdir(install_dir .. "/orphan-2", "p")
      vim.fn.mkdir(install_dir .. "/orphan-3", "p")

      local notifications = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
      end

      commands.cmd_clean()

      vim.notify = original_notify

      -- Verify all orphans were removed
      assert.equals(0, vim.fn.isdirectory(install_dir .. "/orphan-1"))
      assert.equals(0, vim.fn.isdirectory(install_dir .. "/orphan-2"))
      assert.equals(0, vim.fn.isdirectory(install_dir .. "/orphan-3"))

      -- Verify configured plugin still exists
      assert.equals(1, vim.fn.isdirectory(install_dir .. "/configured-plugin"))

      -- Verify completion message shows correct count
      local found_complete = false
      for _, notification in ipairs(notifications) do
        if notification.msg:match("Clean complete: 3 orphan plugin") then
          found_complete = true
        end
      end
      assert.is_true(found_complete, "Should show 3 orphan plugins removed")

      -- Clean up
      vim.fn.delete(install_dir .. "/configured-plugin", "rf")
    end)
  end)

  describe("cmd_self_update", function()
    it("shows error when necromancer path cannot be determined", function()
      -- Mock get_necromancer_path to return nil
      local original_fn = paths.get_necromancer_path
      paths.get_necromancer_path = function()
        return nil
      end

      -- Should not crash
      commands.cmd_self_update()

      -- Restore
      paths.get_necromancer_path = original_fn
    end)

    it("shows error when path is not a git repo", function()
      -- Create non-git directory
      local fake_path = test_dir .. "/fake-necromancer"
      vim.fn.mkdir(fake_path, "p")

      -- Mock get_necromancer_path
      local original_fn = paths.get_necromancer_path
      paths.get_necromancer_path = function()
        return fake_path
      end

      -- Should not crash
      commands.cmd_self_update()

      -- Restore
      paths.get_necromancer_path = original_fn
    end)
  end)
end)

describe("commands with custom config_path", function()
  local test_dir
  local config_dir
  local original_cwd

  before_each(function()
    -- Save current directory
    original_cwd = vim.fn.getcwd()

    -- テストディレクトリを作成
    test_dir = vim.fn.tempname()
    config_dir = vim.fn.tempname()
    vim.fn.mkdir(test_dir, "p")
    vim.fn.mkdir(config_dir, "p")

    -- 設定ファイルを config_dir に作成
    local cfg = {
      plugins = {
        {
          name = "test-plugin",
          repo = "https://github.com/test/test-plugin",
          commit = "1234567890abcdef1234567890abcdef12345678",
        },
      },
    }
    vim.fn.writefile({ vim.json.encode(cfg) }, config_dir .. "/.necromancer.json")
  end)

  after_each(function()
    vim.fn.chdir(original_cwd)
    vim.fn.delete(test_dir, "rf")
    vim.fn.delete(config_dir, "rf")
    pcall(vim.api.nvim_del_user_command, "Necromancer")
    -- モジュールキャッシュをクリア
    package.loaded["necromancer"] = nil
    package.loaded["necromancer.commands"] = nil
    package.loaded["necromancer.init"] = nil
  end)

  it("cmd_list uses config_path from setup", function()
    -- モジュールキャッシュをクリアしてリロード
    package.loaded["necromancer"] = nil
    package.loaded["necromancer.commands"] = nil
    package.loaded["necromancer.init"] = nil

    -- カスタム config_path で setup
    local necromancer = require("necromancer")
    necromancer.setup({ config_path = config_dir .. "/.necromancer.json" })

    local commands_module = require("necromancer.commands")
    local lockfile_module = require("necromancer.core.lockfile")

    -- ロックファイルを作成
    local lock = lockfile_module.create_empty()
    lockfile_module.upsert_plugin(lock, {
      name = "test-plugin",
      repo = "https://github.com/test/test-plugin",
      commit = "1234567890abcdef1234567890abcdef12345678",
      path = "~/.local/share/nvim/necromancer/plugins/test-plugin",
      installedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    })
    lockfile_module.write(config_dir .. "/.necromancer.lock", lock)

    -- test_dir に移動（設定ファイルがない場所）
    vim.fn.chdir(test_dir)

    -- cmd_list を実行（カレントディレクトリに設定ファイルがなくても動作する）
    commands_module.cmd_list()

    -- フローティングウィンドウが開くことを確認
    local wins = vim.api.nvim_list_wins()
    local found_float = false
    for _, win in ipairs(wins) do
      local win_config = vim.api.nvim_win_get_config(win)
      if win_config.relative ~= "" then
        found_float = true
        vim.api.nvim_win_close(win, true)
        break
      end
    end
    assert.is_true(found_float, "Should find config from setup and open floating window")
  end)
end)
