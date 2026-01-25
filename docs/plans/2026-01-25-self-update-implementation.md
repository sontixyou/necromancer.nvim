# self-update コマンド実装計画

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** necromancer.nvim 本体を最新版に更新する `:Necromancer self-update` コマンドを実装する

**Architecture:** git.lua に `pull` 関数を追加し、commands.lua に `cmd_self_update` 関数を追加する。TDD でテストを先に書いてから実装する。

**Tech Stack:** Lua, Neovim API, plenary.busted (テスト)

---

### Task 1: git.pull() のテストを追加

**Files:**
- Modify: `tests/necromancer/core/git_spec.lua:89-107`

**Step 1: pull のテストを追加**

`tests/necromancer/core/git_spec.lua` の末尾（`describe("get_remote_head"` の後）に以下を追加:

```lua
  describe("pull", function()
    it("pulls updates from remote", function()
      -- Create origin repo
      local origin_repo = test_dir .. "/origin"
      vim.fn.mkdir(origin_repo, "p")
      vim.fn.system({ "git", "-C", origin_repo, "init" })
      vim.fn.system({ "git", "-C", origin_repo, "config", "user.email", "test@test.com" })
      vim.fn.system({ "git", "-C", origin_repo, "config", "user.name", "Test" })
      vim.fn.writefile({ "initial" }, origin_repo .. "/file.txt")
      vim.fn.system({ "git", "-C", origin_repo, "add", "." })
      vim.fn.system({ "git", "-C", origin_repo, "commit", "-m", "initial" })

      -- Clone
      local clone_path = test_dir .. "/clone"
      git.clone(origin_repo, clone_path)
      local initial_commit = git.get_current_commit(clone_path)

      -- Add commit to origin
      vim.fn.writefile({ "updated" }, origin_repo .. "/file.txt")
      vim.fn.system({ "git", "-C", origin_repo, "add", "." })
      vim.fn.system({ "git", "-C", origin_repo, "commit", "-m", "update" })
      local new_commit = git.get_current_commit(origin_repo)

      -- Fetch and pull
      git.fetch(clone_path)
      git.pull(clone_path)

      local current = git.get_current_commit(clone_path)
      assert.equals(new_commit, current)
      assert.is_not.equals(initial_commit, current)
    end)

    it("fails when local changes exist", function()
      -- Create origin repo
      local origin_repo = test_dir .. "/origin"
      vim.fn.mkdir(origin_repo, "p")
      vim.fn.system({ "git", "-C", origin_repo, "init" })
      vim.fn.system({ "git", "-C", origin_repo, "config", "user.email", "test@test.com" })
      vim.fn.system({ "git", "-C", origin_repo, "config", "user.name", "Test" })
      vim.fn.writefile({ "initial" }, origin_repo .. "/file.txt")
      vim.fn.system({ "git", "-C", origin_repo, "add", "." })
      vim.fn.system({ "git", "-C", origin_repo, "commit", "-m", "initial" })

      -- Clone
      local clone_path = test_dir .. "/clone"
      git.clone(origin_repo, clone_path)

      -- Make local uncommitted change
      vim.fn.writefile({ "local change" }, clone_path .. "/file.txt")

      -- Add divergent commit to origin
      vim.fn.writefile({ "remote change" }, origin_repo .. "/file.txt")
      vim.fn.system({ "git", "-C", origin_repo, "add", "." })
      vim.fn.system({ "git", "-C", origin_repo, "commit", "-m", "remote" })

      -- Fetch and try pull - should fail due to local changes
      git.fetch(clone_path)
      assert.has_error(function()
        git.pull(clone_path)
      end)
    end)
  end)
```

**Step 2: テストが失敗することを確認**

Run: `make test-file FILE=tests/necromancer/core/git_spec.lua`
Expected: FAIL with "attempt to call field 'pull' (a nil value)"

**Step 3: コミット**

```bash
git add tests/necromancer/core/git_spec.lua
git commit -m "test: add git.pull() test cases"
```

---

### Task 2: git.pull() を実装

**Files:**
- Modify: `lua/necromancer/core/git.lua:126`

**Step 1: pull 関数を実装**

`lua/necromancer/core/git.lua` の末尾（`return M` の前）に以下を追加:

```lua
---Pull updates from remote (fast-forward only)
---@param repo_path string Path to repository
function M.pull(repo_path)
  local ok, err = pcall(function()
    git_exec({ "pull", "--ff-only" }, repo_path)
  end)

  if not ok then
    local msg = type(err) == "table" and err.message or tostring(err)
    error(errors.GitError("Failed to pull: " .. msg))
  end
end
```

**Step 2: テストが成功することを確認**

Run: `make test-file FILE=tests/necromancer/core/git_spec.lua`
Expected: PASS

**Step 3: コミット**

```bash
git add lua/necromancer/core/git.lua
git commit -m "feat(git): add pull function for self-update"
```

---

### Task 3: cmd_self_update() のテストを追加

**Files:**
- Modify: `tests/necromancer/commands_spec.lua:301`

**Step 1: cmd_self_update のテストを追加**

`tests/necromancer/commands_spec.lua` の末尾（最後の `end)` の前）に以下を追加:

```lua
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
```

**Step 2: テストが失敗することを確認**

Run: `make test-file FILE=tests/necromancer/commands_spec.lua`
Expected: FAIL with "attempt to call field 'cmd_self_update' (a nil value)"

**Step 3: コミット**

```bash
git add tests/necromancer/commands_spec.lua
git commit -m "test: add cmd_self_update() test cases"
```

---

### Task 4: cmd_self_update() を実装

**Files:**
- Modify: `lua/necromancer/commands.lua:363-395`

**Step 1: cmd_self_update 関数を実装**

`lua/necromancer/commands.lua` の `cmd_status` 関数の後（`cmd_init` の前）に以下を追加:

```lua
---Update necromancer.nvim itself
function M.cmd_self_update()
  local necromancer_path = paths.get_necromancer_path()

  if not necromancer_path then
    vim.notify("Could not determine necromancer.nvim path", vim.log.levels.ERROR)
    return
  end

  -- Check if it's a git repo
  if vim.fn.isdirectory(necromancer_path .. "/.git") ~= 1 then
    vim.notify("necromancer.nvim is not a git repository", vim.log.levels.ERROR)
    return
  end

  vim.notify("Checking for updates...", vim.log.levels.INFO)

  -- Fetch updates
  local ok, err = pcall(git.fetch, necromancer_path)
  if not ok then
    local msg = type(err) == "table" and err.message or tostring(err)
    vim.notify("Failed to fetch updates: " .. msg, vim.log.levels.ERROR)
    return
  end

  -- Compare commits
  local current_ok, current = pcall(git.get_current_commit, necromancer_path)
  if not current_ok then
    vim.notify("Failed to get current commit", vim.log.levels.ERROR)
    return
  end

  local remote = git.get_remote_head(necromancer_path)
  if not remote then
    vim.notify("Could not determine remote HEAD", vim.log.levels.ERROR)
    return
  end

  if current == remote then
    vim.notify("necromancer.nvim is already up-to-date", vim.log.levels.INFO)
    return
  end

  -- Pull updates
  ok, err = pcall(git.pull, necromancer_path)
  if not ok then
    local msg = type(err) == "table" and err.message or tostring(err)
    vim.notify("Failed to update: " .. msg, vim.log.levels.ERROR)
    return
  end

  vim.notify("necromancer.nvim updated! Please restart Neovim to apply changes.", vim.log.levels.INFO)
end
```

**Step 2: テストが成功することを確認**

Run: `make test-file FILE=tests/necromancer/commands_spec.lua`
Expected: PASS

**Step 3: コミット**

```bash
git add lua/necromancer/commands.lua
git commit -m "feat(commands): add cmd_self_update function"
```

---

### Task 5: dispatch とコマンド補完を更新

**Files:**
- Modify: `lua/necromancer/commands.lua:394-396` (get_subcommands)
- Modify: `lua/necromancer/commands.lua:445-466` (dispatch)

**Step 1: get_subcommands に self-update を追加**

`get_subcommands` 関数を更新:

```lua
local function get_subcommands()
  return { "install", "list", "status", "init", "self-update" }
end
```

**Step 2: dispatch に self-update を追加**

`dispatch` 関数内の条件分岐に追加（`elseif subcommand == "init" then` の後）:

```lua
  elseif subcommand == "self-update" then
    M.cmd_self_update()
```

**Step 3: Usage メッセージを更新**

dispatch 関数内の Usage メッセージを更新:

```lua
  if not subcommand then
    vim.notify("Usage: :Necromancer <install|list|status|init|self-update> [args]", vim.log.levels.ERROR)
    return
  end
```

Unknown コマンドのメッセージも更新:

```lua
    vim.notify("Available commands: install, list, status, init, self-update", vim.log.levels.INFO)
```

**Step 4: コマンド補完が動作することを確認**

手動テスト: Neovim で `:Necromancer self<Tab>` と入力して `self-update` が補完されることを確認

**Step 5: コミット**

```bash
git add lua/necromancer/commands.lua
git commit -m "feat(commands): register self-update subcommand"
```

---

### Task 6: 最終確認とマージ準備

**Step 1: 全テストを実行**

Run: `make test-lua`
Expected: All tests pass

**Step 2: 手動テスト**

1. `:Necromancer self-update` を実行
2. 「already up-to-date」または「updated」メッセージを確認

**Step 3: squash merge 用のコミットメッセージを準備**

Feature branch をメインにマージする際のコミットメッセージ:

```
feat(commands): add :Necromancer self-update command

Add a command to update necromancer.nvim itself to the latest version.

- Add git.pull() function for fast-forward only updates
- Add cmd_self_update() that fetches, compares, and pulls
- Register self-update subcommand with completion support
- Show appropriate messages for all states (up-to-date, updated, errors)
```
