# :Necromancer status コマンド実装計画

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** プラグインごとの状態（up-to-date, outdated, update available, not installed）を表示する status コマンドを実装する

**Architecture:** git.lua に get_remote_head 関数を追加し、commands.lua に get_plugin_status ヘルパーと cmd_status コマンドを実装。フローティングウィンドウで表示。

**Tech Stack:** Lua, Neovim API, plenary.nvim (テスト)

---

## Task 1: git.get_remote_head 関数の追加

**Files:**
- Modify: `lua/necromancer/core/git.lua:91` (return M の前)
- Test: `tests/necromancer/core/git_spec.lua`

**Step 1: Write the failing test**

`tests/necromancer/core/git_spec.lua` の末尾（`end)` の前）に追加:

```lua
  describe("get_remote_head", function()
    it("returns remote HEAD commit hash", function()
      -- Clone to get a repo with remote
      local clone_path = test_dir .. "/cloned"
      git.clone(test_repo, clone_path)

      local remote_head = git.get_remote_head(clone_path)
      assert.is_not_nil(remote_head)
      assert.equals(40, #remote_head)
      assert.is_true(remote_head:match("^[a-f0-9]+$") ~= nil)
    end)

    it("returns nil when remote does not exist", function()
      -- test_repo has no remote
      local remote_head = git.get_remote_head(test_repo)
      assert.is_nil(remote_head)
    end)
  end)
```

**Step 2: Run test to verify it fails**

Run: `make test-file FILE=tests/necromancer/core/git_spec.lua`

Expected: FAIL with "attempt to call field 'get_remote_head' (a nil value)"

**Step 3: Write minimal implementation**

`lua/necromancer/core/git.lua` の `return M` の前に追加:

```lua
---Get remote HEAD commit hash
---@param repo_path string Path to repository
---@return string|nil commit 40-character hash, or nil if no remote
function M.get_remote_head(repo_path)
  -- Try to get remote HEAD (origin/HEAD -> origin/main or origin/master)
  local ok, result = pcall(function()
    -- First try origin/HEAD
    local head = git_exec({ "rev-parse", "origin/HEAD" }, repo_path)
    return head
  end)

  if ok then
    return result
  end

  -- Fallback: try origin/main, then origin/master
  ok, result = pcall(function()
    return git_exec({ "rev-parse", "origin/main" }, repo_path)
  end)

  if ok then
    return result
  end

  ok, result = pcall(function()
    return git_exec({ "rev-parse", "origin/master" }, repo_path)
  end)

  if ok then
    return result
  end

  return nil
end
```

**Step 4: Run test to verify it passes**

Run: `make test-file FILE=tests/necromancer/core/git_spec.lua`

Expected: PASS (7 tests)

**Step 5: Commit**

```bash
git add lua/necromancer/core/git.lua tests/necromancer/core/git_spec.lua
git commit -m "feat(git): add get_remote_head function for status command"
```

---

## Task 2: get_plugin_status ヘルパー関数の追加

**Files:**
- Modify: `lua/necromancer/commands.lua` (find_plugin_by_name 関数の後)
- Test: `tests/necromancer/commands_spec.lua`

**Step 1: Write the failing test**

`tests/necromancer/commands_spec.lua` に追加（describe("commands", function() 内の適切な場所）:

```lua
  describe("get_plugin_status", function()
    local git = require("necromancer.core.git")
    local installer = require("necromancer.core.installer")

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
```

**Step 2: Run test to verify it fails**

Run: `make test-file FILE=tests/necromancer/commands_spec.lua`

Expected: FAIL with "attempt to call field 'get_plugin_status' (a nil value)"

**Step 3: Write minimal implementation**

`lua/necromancer/commands.lua` の `find_plugin_by_name` 関数の後に追加:

```lua
local git = require("necromancer.core.git")

---Get status of a single plugin
---@param plugin_def table Plugin definition from config
---@param install_dir string Installation directory
---@param lock table Lock file data (unused for now)
---@return table status {name, state, current_commit, config_commit, remote_commit, error_msg}
function M.get_plugin_status(plugin_def, install_dir, lock)
  local plugin_path = paths.resolve_plugin_path(plugin_def.name, install_dir)
  local result = {
    name = plugin_def.name,
    state = "unknown",
    config_commit = plugin_def.commit,
    current_commit = nil,
    remote_commit = nil,
    error_msg = nil,
  }

  -- Check if directory exists
  if vim.fn.isdirectory(plugin_path) ~= 1 then
    result.state = "not_installed"
    return result
  end

  -- Check if it's a git repo
  if vim.fn.isdirectory(plugin_path .. "/.git") ~= 1 then
    result.state = "corrupted"
    return result
  end

  -- Get current commit
  local ok, current_commit = pcall(git.get_current_commit, plugin_path)
  if not ok then
    result.state = "corrupted"
    result.error_msg = tostring(current_commit)
    return result
  end
  result.current_commit = current_commit

  -- Fetch and get remote HEAD
  local fetch_ok = pcall(git.fetch, plugin_path)
  if fetch_ok then
    result.remote_commit = git.get_remote_head(plugin_path)
  else
    result.error_msg = "fetch_failed"
  end

  -- Determine state
  if current_commit ~= plugin_def.commit then
    result.state = "outdated"
  elseif result.remote_commit and result.remote_commit ~= plugin_def.commit then
    result.state = "update_available"
  else
    result.state = "up_to_date"
  end

  return result
end
```

**Step 4: Run test to verify it passes**

Run: `make test-file FILE=tests/necromancer/commands_spec.lua`

Expected: PASS (12 tests)

**Step 5: Commit**

```bash
git add lua/necromancer/commands.lua tests/necromancer/commands_spec.lua
git commit -m "feat(commands): add get_plugin_status helper function"
```

---

## Task 3: cmd_status コマンドの実装

**Files:**
- Modify: `lua/necromancer/commands.lua`
- Test: `tests/necromancer/commands_spec.lua`

**Step 1: Write the failing test**

`tests/necromancer/commands_spec.lua` に追加:

```lua
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
```

**Step 2: Run test to verify it fails**

Run: `make test-file FILE=tests/necromancer/commands_spec.lua`

Expected: FAIL with "attempt to call field 'cmd_status' (a nil value)"

**Step 3: Write minimal implementation**

`lua/necromancer/commands.lua` の `cmd_init` 関数の後に追加:

```lua
---Status icons and labels
local STATUS_INFO = {
  up_to_date = { icon = "✓", label = "up-to-date" },
  update_available = { icon = "⬆", label = "update available" },
  outdated = { icon = "!", label = "outdated" },
  not_installed = { icon = "✗", label = "not installed" },
  corrupted = { icon = "⚠", label = "corrupted" },
  fetch_failed = { icon = "?", label = "fetch failed" },
}

---Show status of all configured plugins
function M.cmd_status()
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

  -- Get install directory and lock file
  local install_dir = paths.get_default_install_dir()
  local lock_path = paths.get_lock_file_path(config_path)
  local lock = lockfile.read(lock_path)

  -- Get status for each plugin
  local statuses = {}
  local total = #cfg.plugins
  for i, plugin_def in ipairs(cfg.plugins) do
    vim.notify(string.format("Fetching updates... (%d/%d) %s", i, total, plugin_def.name), vim.log.levels.INFO)
    local status = M.get_plugin_status(plugin_def, install_dir, lock)
    table.insert(statuses, status)
  end

  -- Build output lines
  local timestamp = os.date("%H:%M:%S")
  local lines = { string.format("Plugin Status (fetched at %s):", timestamp), "" }

  -- Track summary counts
  local counts = {}
  for _, status in ipairs(statuses) do
    counts[status.state] = (counts[status.state] or 0) + 1
  end

  -- Find max plugin name length for alignment
  local max_name_len = 0
  for _, status in ipairs(statuses) do
    max_name_len = math.max(max_name_len, #status.name)
  end

  -- Format each plugin line
  for _, status in ipairs(statuses) do
    local info = STATUS_INFO[status.state] or { icon = "?", label = status.state }
    local name_padded = status.name .. string.rep(" ", max_name_len - #status.name)
    local line

    if status.state == "not_installed" then
      line = string.format("  %s %s  %s", info.icon, name_padded, info.label)
    elseif status.state == "corrupted" then
      line = string.format("  %s %s  %s", info.icon, name_padded, info.label)
    elseif status.state == "outdated" then
      local short_current = status.current_commit and status.current_commit:sub(1, 8) or "????????"
      local short_config = status.config_commit:sub(1, 8)
      line = string.format("  %s %s  %-16s @ %s ≠ %s", info.icon, name_padded, info.label, short_current, short_config)
    elseif status.state == "update_available" then
      local short_current = status.current_commit:sub(1, 8)
      local short_remote = status.remote_commit and status.remote_commit:sub(1, 8) or "????????"
      line = string.format("  %s %s  %-16s @ %s → %s", info.icon, name_padded, info.label, short_current, short_remote)
    else
      local short_commit = status.current_commit and status.current_commit:sub(1, 8) or "????????"
      line = string.format("  %s %s  %-16s @ %s", info.icon, name_padded, info.label, short_commit)
    end

    table.insert(lines, line)
  end

  -- Add summary
  table.insert(lines, "")
  local summary_parts = {}
  for _, state in ipairs({ "up_to_date", "update_available", "outdated", "not_installed", "corrupted" }) do
    if counts[state] and counts[state] > 0 then
      local info = STATUS_INFO[state]
      table.insert(summary_parts, string.format("%d %s", counts[state], info.label))
    end
  end
  table.insert(lines, "Summary: " .. table.concat(summary_parts, ", "))

  -- Show in floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "necromancer", { buf = buf })

  -- Calculate window size
  local width = 70
  local height = math.min(#lines + 2, 20)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Necromancer Status ",
    title_pos = "center",
  })

  -- Close on q or <Esc>
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true })
end
```

**Step 4: Run test to verify it passes**

Run: `make test-file FILE=tests/necromancer/commands_spec.lua`

Expected: PASS (14 tests)

**Step 5: Commit**

```bash
git add lua/necromancer/commands.lua tests/necromancer/commands_spec.lua
git commit -m "feat(commands): add cmd_status for plugin status display"
```

---

## Task 4: サブコマンドの登録

**Files:**
- Modify: `lua/necromancer/commands.lua` (get_subcommands と dispatch 関数)

**Step 1: Update get_subcommands**

`lua/necromancer/commands.lua` の `get_subcommands` 関数を更新:

```lua
---Get list of available subcommands
---@return string[]
local function get_subcommands()
  return { "install", "list", "init", "status" }
end
```

**Step 2: Update dispatch**

`dispatch` 関数内の条件分岐に追加:

```lua
  elseif subcommand == "status" then
    M.cmd_status()
```

**Step 3: Update usage message**

`dispatch` 関数内の usage メッセージを更新:

```lua
  if not subcommand then
    vim.notify("Usage: :Necromancer <install|list|init|status> [args]", vim.log.levels.ERROR)
    return
  end
```

また、unknown subcommand のメッセージも更新:

```lua
    vim.notify("Available commands: install, list, init, status", vim.log.levels.INFO)
```

**Step 4: Run all tests**

Run: `make test-lua`

Expected: All tests PASS

**Step 5: Commit**

```bash
git add lua/necromancer/commands.lua
git commit -m "feat(commands): register status subcommand"
```

---

## Task 5: 全テスト実行と最終確認

**Step 1: Run all tests**

Run: `make test-lua`

Expected: All tests PASS (at least 97 tests)

**Step 2: Manual verification (optional)**

Neovim で実際にコマンドを実行して確認:

```vim
:Necromancer status
```

**Step 3: Final commit (if any fixes needed)**

もし修正が必要な場合のみコミット。

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | git.get_remote_head 追加 | git.lua, git_spec.lua |
| 2 | get_plugin_status ヘルパー追加 | commands.lua, commands_spec.lua |
| 3 | cmd_status 実装 | commands.lua, commands_spec.lua |
| 4 | サブコマンド登録 | commands.lua |
| 5 | 全テスト実行 | - |
