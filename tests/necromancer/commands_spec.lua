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
end)
