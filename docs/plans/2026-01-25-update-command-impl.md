# :Necromancer update コマンド実装計画

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** プラグインを指定ブランチの1週間前コミットに更新するコマンドを実装する

**Architecture:** validator.lua にブランチ名検証を追加、git.lua にデフォルトブランチ検出と日付ベースコミット取得を追加、config.lua に設定ファイル更新機能を追加、commands.lua に update コマンドを追加

**Tech Stack:** Lua, Neovim API, plenary.nvim (テスト)

---

## Task 1: ブランチ名バリデーション（validator.lua）

**Files:**
- Modify: `lua/necromancer/core/validator.lua:41-54`
- Test: `tests/necromancer/core/validator_spec.lua`

**Step 1: Write the failing test**

`tests/necromancer/core/validator_spec.lua` の末尾（`end)` の前）に追加:

```lua
  describe("is_valid_branch_name", function()
    it("accepts simple branch name", function()
      assert.is_true(validator.is_valid_branch_name("main"))
    end)

    it("accepts branch with hyphens", function()
      assert.is_true(validator.is_valid_branch_name("feature-branch"))
    end)

    it("accepts branch with underscores", function()
      assert.is_true(validator.is_valid_branch_name("feature_branch"))
    end)

    it("accepts branch with slashes", function()
      assert.is_true(validator.is_valid_branch_name("feature/my-feature"))
    end)

    it("accepts branch with dots", function()
      assert.is_true(validator.is_valid_branch_name("release.1.0"))
    end)

    it("rejects branch starting with hyphen", function()
      assert.is_false(validator.is_valid_branch_name("-branch"))
    end)

    it("rejects branch starting with dot", function()
      assert.is_false(validator.is_valid_branch_name(".branch"))
    end)

    it("rejects branch starting with slash", function()
      assert.is_false(validator.is_valid_branch_name("/branch"))
    end)

    it("rejects empty string", function()
      assert.is_false(validator.is_valid_branch_name(""))
    end)

    it("rejects nil", function()
      assert.is_false(validator.is_valid_branch_name(nil))
    end)

    it("rejects branch with shell metacharacters", function()
      assert.is_false(validator.is_valid_branch_name("branch;rm"))
      assert.is_false(validator.is_valid_branch_name("branch`cmd`"))
    end)
  end)
```

**Step 2: Run test to verify it fails**

Run: `cd .worktrees/feature-update-command && make test-file FILE=tests/necromancer/core/validator_spec.lua`
Expected: FAIL with "attempt to call a nil value (field 'is_valid_branch_name')"

**Step 3: Write minimal implementation**

`lua/necromancer/core/validator.lua` の `has_shell_metachar` 関数の前に追加:

```lua
---Validate Git branch name
---@param name string
---@return boolean
function M.is_valid_branch_name(name)
  if type(name) ~= "string" then
    return false
  end
  if #name == 0 then
    return false
  end
  -- First char: alphanumeric or underscore (not hyphen, dot, or slash)
  -- Rest: alphanumeric, hyphen, underscore, dot, or slash
  -- No shell metacharacters
  if M.has_shell_metachar(name) then
    return false
  end
  return name:match("^[%w_][%w%.%-_/]*$") ~= nil
end
```

**Step 4: Run test to verify it passes**

Run: `cd .worktrees/feature-update-command && make test-file FILE=tests/necromancer/core/validator_spec.lua`
Expected: PASS

**Step 5: Commit**

```bash
cd .worktrees/feature-update-command
git add lua/necromancer/core/validator.lua tests/necromancer/core/validator_spec.lua
git commit -m "feat(validator): add branch name validation

Add is_valid_branch_name function to validate Git branch names.
Allows alphanumeric, hyphens, underscores, dots, and slashes.
First character must be alphanumeric or underscore.
Rejects shell metacharacters for security.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 2: デフォルトブランチ検出（git.lua）

**Files:**
- Modify: `lua/necromancer/core/git.lua:91-93`
- Test: `tests/necromancer/core/git_spec.lua`

**Step 1: Write the failing test**

`tests/necromancer/core/git_spec.lua` の `describe("fetch"` ブロックの後に追加:

```lua
  describe("get_default_branch", function()
    it("returns default branch name for repo with remote", function()
      -- Clone to get a repo with remote
      local clone_path = test_dir .. "/cloned-for-default"
      git.clone(test_repo, clone_path)

      local branch = git.get_default_branch(clone_path)
      -- Should return main or master (depending on git config)
      assert.is_true(branch == "main" or branch == "master")
    end)

    it("falls back to main for repo without remote", function()
      -- test_repo has no remote configured
      local branch = git.get_default_branch(test_repo)
      assert.equals("main", branch)
    end)
  end)
```

**Step 2: Run test to verify it fails**

Run: `cd .worktrees/feature-update-command && make test-file FILE=tests/necromancer/core/git_spec.lua`
Expected: FAIL with "attempt to call a nil value (field 'get_default_branch')"

**Step 3: Write minimal implementation**

`lua/necromancer/core/git.lua` の末尾（`return M` の前）に追加:

```lua
---Get default branch name from remote
---@param repo_path string Path to repository
---@return string branch Default branch name
function M.get_default_branch(repo_path)
  -- Try to get from remote
  local ok, result = pcall(function()
    return git_exec({ "remote", "show", "origin" }, repo_path)
  end)

  if ok and result then
    local branch = result:match("HEAD branch: ([^\n]+)")
    if branch and #branch > 0 then
      return vim.trim(branch)
    end
  end

  -- Fallback: check if main or master exists
  local main_ok = pcall(function()
    git_exec({ "rev-parse", "--verify", "main" }, repo_path)
  end)
  if main_ok then
    return "main"
  end

  local master_ok = pcall(function()
    git_exec({ "rev-parse", "--verify", "master" }, repo_path)
  end)
  if master_ok then
    return "master"
  end

  -- Default to main
  return "main"
end
```

**Step 4: Run test to verify it passes**

Run: `cd .worktrees/feature-update-command && make test-file FILE=tests/necromancer/core/git_spec.lua`
Expected: PASS

**Step 5: Commit**

```bash
cd .worktrees/feature-update-command
git add lua/necromancer/core/git.lua tests/necromancer/core/git_spec.lua
git commit -m "feat(git): add default branch detection

Add get_default_branch function that detects the default branch
from remote origin. Falls back to main, then master if remote
detection fails.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 3: 日付ベースコミット取得（git.lua）

**Files:**
- Modify: `lua/necromancer/core/git.lua`
- Test: `tests/necromancer/core/git_spec.lua`

**Step 1: Write the failing test**

`tests/necromancer/core/git_spec.lua` の `describe("get_default_branch"` ブロックの後に追加:

```lua
  describe("get_commit_before_date", function()
    it("returns commit from before specified days", function()
      -- Clone to get a repo with remote tracking
      local clone_path = test_dir .. "/cloned-for-date"
      git.clone(test_repo, clone_path)

      -- For a fresh repo, any days_ago should return the only commit
      local commit = git.get_commit_before_date(clone_path, "origin/master", 7)
      assert.equals(40, #commit)
      assert.is_true(commit:match("^[a-f0-9]+$") ~= nil)
    end)

    it("returns oldest commit if no commit before date", function()
      local clone_path = test_dir .. "/cloned-for-oldest"
      git.clone(test_repo, clone_path)

      -- Request commit from 1000 days ago (before repo existed)
      local commit = git.get_commit_before_date(clone_path, "origin/master", 1000)
      assert.equals(40, #commit)
    end)
  end)
```

**Step 2: Run test to verify it fails**

Run: `cd .worktrees/feature-update-command && make test-file FILE=tests/necromancer/core/git_spec.lua`
Expected: FAIL with "attempt to call a nil value (field 'get_commit_before_date')"

**Step 3: Write minimal implementation**

`lua/necromancer/core/git.lua` の `get_default_branch` 関数の後に追加:

```lua
---Get commit hash from before specified number of days ago
---@param repo_path string Path to repository
---@param branch string Branch name (e.g., "origin/main")
---@param days_ago number Number of days ago
---@return string commit 40-character hash
function M.get_commit_before_date(repo_path, branch, days_ago)
  local date_spec = string.format("%d days ago", days_ago)

  -- Try to get commit before the specified date
  local ok, result = pcall(function()
    return git_exec({
      "log",
      branch,
      "--before=" .. date_spec,
      "-1",
      "--format=%H",
    }, repo_path)
  end)

  if ok and result and #result == 40 then
    return result
  end

  -- Fallback: get the oldest commit on the branch
  local oldest_ok, oldest = pcall(function()
    return git_exec({
      "rev-list",
      "--max-parents=0",
      branch,
    }, repo_path)
  end)

  if oldest_ok and oldest then
    -- rev-list may return multiple lines, take the first
    local first_line = oldest:match("^([^\n]+)")
    if first_line and #first_line == 40 then
      return first_line
    end
  end

  -- Last resort: just get HEAD of the branch
  local head_ok, head = pcall(function()
    return git_exec({ "rev-parse", branch }, repo_path)
  end)

  if head_ok and head and #head == 40 then
    return head
  end

  error(errors.GitError("Failed to get commit for branch: " .. branch))
end
```

**Step 4: Run test to verify it passes**

Run: `cd .worktrees/feature-update-command && make test-file FILE=tests/necromancer/core/git_spec.lua`
Expected: PASS

**Step 5: Commit**

```bash
cd .worktrees/feature-update-command
git add lua/necromancer/core/git.lua tests/necromancer/core/git_spec.lua
git commit -m "feat(git): add date-based commit retrieval

Add get_commit_before_date function that finds the latest commit
from before a specified number of days ago. Falls back to the
oldest commit if no commits exist before that date.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 4: 設定ファイル更新機能（config.lua）

**Files:**
- Modify: `lua/necromancer/core/config.lua:112-114`
- Test: `tests/necromancer/core/config_spec.lua`

**Step 1: Write the failing test**

`tests/necromancer/core/config_spec.lua` の末尾（最後の `end)` の前）に追加:

```lua
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
      assert.equals("main", result.plugins[1].branch)
      assert.same({ "dep1" }, result.plugins[1].dependencies)
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
```

**Step 2: Run test to verify it fails**

Run: `cd .worktrees/feature-update-command && make test-file FILE=tests/necromancer/core/config_spec.lua`
Expected: FAIL with "attempt to call a nil value (field 'update_plugins_commits')"

**Step 3: Write minimal implementation**

`lua/necromancer/core/config.lua` の末尾（`return M` の前）に追加:

```lua
---Update plugin commits in config file
---@param config_path string Path to config file
---@param updates table[] List of {name, commit} pairs
function M.update_plugins_commits(config_path, updates)
  -- Read and parse current config
  local lines = vim.fn.readfile(config_path)
  if vim.tbl_isempty(lines) then
    error(errors.ConfigError("Failed to read configuration file at " .. config_path))
  end

  local content = table.concat(lines, "\n")
  local ok, cfg = pcall(vim.json.decode, content)
  if not ok then
    error(errors.ConfigError("Invalid JSON in configuration file: " .. tostring(cfg)))
  end

  -- Build lookup table for updates
  local update_map = {}
  for _, update in ipairs(updates) do
    update_map[update.name] = update.commit
  end

  -- Apply updates
  for _, plugin in ipairs(cfg.plugins) do
    if update_map[plugin.name] then
      plugin.commit = update_map[plugin.name]
    end
  end

  -- Write back
  local json = vim.json.encode(cfg)
  vim.fn.writefile({ json }, config_path)
end
```

**Step 4: Run test to verify it passes**

Run: `cd .worktrees/feature-update-command && make test-file FILE=tests/necromancer/core/config_spec.lua`
Expected: PASS

**Step 5: Commit**

```bash
cd .worktrees/feature-update-command
git add lua/necromancer/core/config.lua tests/necromancer/core/config_spec.lua
git commit -m "feat(config): add plugin commit update function

Add update_plugins_commits function that updates commit hashes
for specified plugins in the config file. Preserves all other
plugin fields and skips plugins not in the update list.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 5: update コマンド実装（commands.lua）

**Files:**
- Modify: `lua/necromancer/commands.lua`
- Test: `tests/necromancer/commands_spec.lua`

**Step 1: Write the failing test**

`tests/necromancer/commands_spec.lua` の末尾（最後の `end)` の前）に追加:

```lua
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
```

**Step 2: Run test to verify it fails**

Run: `cd .worktrees/feature-update-command && make test-file FILE=tests/necromancer/commands_spec.lua`
Expected: FAIL with "attempt to call a nil value (field 'cmd_update')"

**Step 3: Write minimal implementation**

`lua/necromancer/commands.lua` に以下の変更を加える:

1. 先頭の require に git を追加:
```lua
local git = require("necromancer.core.git")
```

2. `cmd_init` 関数の後に `cmd_update` 関数を追加:
```lua
---Update plugins to commits from specified days ago on their branch
---@param args string[] Command arguments (optional plugin name)
function M.cmd_update(args)
  -- Validate args - at most one plugin name allowed
  if #args > 1 then
    vim.notify("Usage: :Necromancer update [plugin_name]", vim.log.levels.ERROR)
    return
  end
  local plugin_name = args[1]

  -- Find config file
  local config_path = paths.resolve_config_path()
  if not config_path then
    vim.notify("Config file not found. Run :Necromancer init to create one.", vim.log.levels.ERROR)
    return
  end

  -- Parse config
  local ok, cfg = pcall(config.parse_config_file, config_path)
  if not ok then
    vim.notify("Failed to parse config: " .. tostring(cfg), vim.log.levels.ERROR)
    return
  end

  -- Get install directory
  local install_dir = paths.get_default_install_dir()

  -- Determine which plugins to update
  local plugins_to_update = {}
  if plugin_name then
    local plugin_def = find_plugin_by_name(cfg.plugins, plugin_name)
    if not plugin_def then
      vim.notify("Plugin not found in config: " .. plugin_name, vim.log.levels.ERROR)
      return
    end
    table.insert(plugins_to_update, plugin_def)
  else
    plugins_to_update = cfg.plugins
  end

  -- Track results
  local updates = {}
  local updated_count = 0
  local skipped_count = 0
  local failed_count = 0
  local days_ago = 7

  -- Process each plugin
  for _, plugin in ipairs(plugins_to_update) do
    local plugin_path = paths.resolve_plugin_path(plugin.name, install_dir)

    -- Check if plugin is installed
    if vim.fn.isdirectory(plugin_path) ~= 1 then
      vim.notify(string.format("Plugin not installed: %s (run :Necromancer install first)", plugin.name), vim.log.levels.WARN)
      failed_count = failed_count + 1
      goto continue
    end

    vim.notify(string.format("Fetching %s...", plugin.name), vim.log.levels.INFO)

    -- Fetch latest from remote
    local fetch_ok, fetch_err = pcall(function()
      git.fetch(plugin_path)
    end)
    if not fetch_ok then
      vim.notify(string.format("Failed to fetch %s: %s", plugin.name, tostring(fetch_err)), vim.log.levels.ERROR)
      failed_count = failed_count + 1
      goto continue
    end

    -- Determine branch
    local branch = plugin.branch
    if not branch then
      local branch_ok, detected_branch = pcall(function()
        return git.get_default_branch(plugin_path)
      end)
      if branch_ok then
        branch = detected_branch
      else
        branch = "main"
      end
    end

    -- Get commit from days_ago
    local remote_branch = "origin/" .. branch
    local commit_ok, new_commit = pcall(function()
      return git.get_commit_before_date(plugin_path, remote_branch, days_ago)
    end)
    if not commit_ok then
      vim.notify(string.format("Failed to get commit for %s: %s", plugin.name, tostring(new_commit)), vim.log.levels.ERROR)
      failed_count = failed_count + 1
      goto continue
    end

    -- Check if already at this commit
    if new_commit == plugin.commit then
      vim.notify(string.format("%s is already up to date", plugin.name), vim.log.levels.INFO)
      skipped_count = skipped_count + 1
      goto continue
    end

    -- Checkout new commit
    local checkout_ok, checkout_err = pcall(function()
      git.checkout(plugin_path, new_commit)
    end)
    if not checkout_ok then
      vim.notify(string.format("Failed to checkout %s: %s", plugin.name, tostring(checkout_err)), vim.log.levels.ERROR)
      failed_count = failed_count + 1
      goto continue
    end

    -- Record successful update
    table.insert(updates, { name = plugin.name, commit = new_commit })
    updated_count = updated_count + 1
    vim.notify(string.format(
      "Updated %s: %s -> %s (branch: %s, %d days ago)",
      plugin.name,
      plugin.commit:sub(1, 8),
      new_commit:sub(1, 8),
      branch,
      days_ago
    ), vim.log.levels.INFO)

    ::continue::
  end

  -- Update config file with successful updates
  if #updates > 0 then
    local update_ok, update_err = pcall(function()
      config.update_plugins_commits(config_path, updates)
    end)
    if not update_ok then
      vim.notify("Failed to update config file: " .. tostring(update_err), vim.log.levels.ERROR)
    end

    -- Update lockfile
    local lock_path = paths.get_lock_file_path(config_path)
    local lock = lockfile.read(lock_path)
    for _, update in ipairs(updates) do
      local plugin_def = find_plugin_by_name(cfg.plugins, update.name)
      if plugin_def then
        local lock_entry = {
          name = update.name,
          repo = plugin_def.repo,
          commit = update.commit,
          path = paths.compress_tilde(paths.resolve_plugin_path(update.name, install_dir)),
          installedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }
        lockfile.upsert_plugin(lock, lock_entry)
      end
    end
    lockfile.write(lock_path, lock)
  end

  -- Summary
  local summary = string.format("Update complete: %d updated, %d skipped, %d failed", updated_count, skipped_count, failed_count)
  vim.notify(summary, failed_count > 0 and vim.log.levels.WARN or vim.log.levels.INFO)
end
```

3. `get_subcommands` 関数を更新:
```lua
local function get_subcommands()
  return { "install", "list", "init", "update" }
end
```

4. `complete` 関数の `install` 補完部分を更新して `update` も含める:
```lua
  -- Second argument for install or update: plugin names
  if num_args == 3 and (parts[2] == "install" or parts[2] == "update") then
```

5. `dispatch` 関数に update ケースを追加:
```lua
  elseif subcommand == "update" then
    M.cmd_update(subargs)
```

**Step 4: Run test to verify it passes**

Run: `cd .worktrees/feature-update-command && make test-file FILE=tests/necromancer/commands_spec.lua`
Expected: PASS

**Step 5: Commit**

```bash
cd .worktrees/feature-update-command
git add lua/necromancer/commands.lua tests/necromancer/commands_spec.lua
git commit -m "feat(commands): add update command

Add :Necromancer update [plugin] command that updates plugins
to commits from 7 days ago on their tracked branch.

Features:
- Fetches from remote and finds commit from 7 days ago
- Auto-detects default branch if not specified in config
- Updates config file and lockfile on success
- Supports single plugin or all plugins update
- Handles partial failures gracefully

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 6: config.lua に branch バリデーション追加

**Files:**
- Modify: `lua/necromancer/core/config.lua:86-108`
- Test: `tests/necromancer/core/config_spec.lua`

**Step 1: Write the failing test**

`tests/necromancer/core/config_spec.lua` の `validate_config` describe ブロック内に追加:

```lua
    it("accepts valid branch field", function()
      local cfg = {
        plugins = {
          {
            name = "test-plugin",
            repo = "https://github.com/owner/test-plugin",
            commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
            branch = "main",
          },
        },
      }
      assert.has_no_error(function()
        config.validate_config(cfg)
      end)
    end)

    it("errors on invalid branch field", function()
      local cfg = {
        plugins = {
          {
            name = "test-plugin",
            repo = "https://github.com/owner/test-plugin",
            commit = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
            branch = ";malicious",
          },
        },
      }
      assert.has_error(function()
        config.validate_config(cfg)
      end)
    end)
```

**Step 2: Run test to verify it fails**

Run: `cd .worktrees/feature-update-command && make test-file FILE=tests/necromancer/core/config_spec.lua`
Expected: FAIL (the invalid branch test should pass when it should error)

**Step 3: Write minimal implementation**

`lua/necromancer/core/config.lua` の `validate_config` 関数内、dependencies 検証の前に追加:

```lua
    -- Validate branch if present
    if plugin.branch then
      if type(plugin.branch) ~= "string" then
        error(errors.ValidationError(
          string.format('Branch for plugin "%s" must be a string', plugin.name)
        ))
      end
      if not validator.is_valid_branch_name(plugin.branch) then
        error(errors.ValidationError(
          string.format('Invalid branch name for plugin "%s": %s', plugin.name, plugin.branch)
        ))
      end
    end
```

**Step 4: Run test to verify it passes**

Run: `cd .worktrees/feature-update-command && make test-file FILE=tests/necromancer/core/config_spec.lua`
Expected: PASS

**Step 5: Commit**

```bash
cd .worktrees/feature-update-command
git add lua/necromancer/core/config.lua tests/necromancer/core/config_spec.lua
git commit -m "feat(config): validate branch field in plugin definitions

Add validation for optional branch field in plugin definitions.
Ensures branch names are valid and don't contain shell metacharacters.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 7: 全テスト実行と最終確認

**Step 1: Run all tests**

Run: `cd .worktrees/feature-update-command && make test-lua`
Expected: All tests pass (except the known environment-dependent sample_spec test)

**Step 2: Verify command registration**

Run: `cd .worktrees/feature-update-command && nvim --headless -u tests/minimal_init.lua -c "lua require('necromancer.commands').setup()" -c "echo 'Commands registered'" -c "q"`
Expected: No errors

**Step 3: Final commit if any fixes needed**

If any fixes were needed, commit them with appropriate message.

---

## Summary

| Task | Description | Files Modified |
|------|-------------|----------------|
| 1 | Branch name validation | validator.lua, validator_spec.lua |
| 2 | Default branch detection | git.lua, git_spec.lua |
| 3 | Date-based commit retrieval | git.lua, git_spec.lua |
| 4 | Config file update function | config.lua, config_spec.lua |
| 5 | Update command implementation | commands.lua, commands_spec.lua |
| 6 | Branch field validation in config | config.lua, config_spec.lua |
| 7 | Final verification | - |
