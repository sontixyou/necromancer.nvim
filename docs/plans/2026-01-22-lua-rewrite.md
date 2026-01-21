# Necromancer.nvim Lua Rewrite Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rewrite Necromancer.nvim from TypeScript to pure Lua, eliminating Node.js dependency.

**Architecture:** Lua modules under `lua/necromancer/` mirroring TypeScript structure. Uses `vim.fn.system()` for git operations, `vim.json` for JSON, and Neovim API for commands.

**Tech Stack:** Lua 5.1 (LuaJIT), Neovim API, plenary.nvim (testing only)

---

## Phase 1: Foundation

### Task 1: Create Module Structure

**Files:**
- Create: `lua/necromancer/init.lua`
- Create: `lua/necromancer/utils/errors.lua`
- Create: `plugin/necromancer.lua`

**Step 1: Create directory structure**

Run:
```bash
mkdir -p lua/necromancer/utils lua/necromancer/core plugin tests/necromancer/core tests/necromancer/utils
```

**Step 2: Create errors.lua**

```lua
-- lua/necromancer/utils/errors.lua
local M = {}

function M.NecromancerError(message)
  return { name = "NecromancerError", message = message }
end

function M.ValidationError(message)
  return { name = "ValidationError", message = message }
end

function M.GitError(message)
  return { name = "GitError", message = message }
end

function M.ConfigError(message)
  return { name = "ConfigError", message = message }
end

function M.is_necromancer_error(err)
  return type(err) == "table" and err.name ~= nil and err.message ~= nil
end

return M
```

**Step 3: Create minimal init.lua**

```lua
-- lua/necromancer/init.lua
local M = {}
M._VERSION = "2.0.0-dev"
function M.setup(opts) end
return M
```

**Step 4: Create plugin entry point**

```lua
-- plugin/necromancer.lua
-- Auto-loaded by Neovim - intentionally minimal
```

**Step 5: Commit**

```bash
git add lua/ plugin/
git commit -m "feat(lua): create initial module structure"
```

---

### Task 2: Implement Validator Module

**Files:**
- Create: `lua/necromancer/core/validator.lua`
- Create: `tests/necromancer/core/validator_spec.lua`

See full implementation in design document.

**Step 1: Create validator.lua with validation functions**
**Step 2: Create test file with plenary.nvim tests**
**Step 3: Run tests**
**Step 4: Commit**

---

### Task 3: Implement Paths Module

**Files:**
- Create: `lua/necromancer/utils/paths.lua`
- Create: `tests/necromancer/utils/paths_spec.lua`

See full implementation in design document.

---

### Task 4: Implement Git Module

**Files:**
- Create: `lua/necromancer/core/git.lua`
- Create: `tests/necromancer/core/git_spec.lua`

See full implementation in design document.

---

## Phase 2: Core Logic

### Task 5: Implement Dependencies Module

**Files:**
- Create: `lua/necromancer/core/dependencies.lua`
- Create: `tests/necromancer/core/dependencies_spec.lua`

Kahn's algorithm for topological sort.

---

### Task 6: Implement Config Module

**Files:**
- Create: `lua/necromancer/core/config.lua`
- Create: `tests/necromancer/core/config_spec.lua`

JSON parsing and validation.

---

### Task 7: Implement Lockfile Module

**Files:**
- Create: `lua/necromancer/core/lockfile.lua`
- Create: `tests/necromancer/core/lockfile_spec.lua`

Read/write lock file.

---

### Task 8: Implement Installer Module

**Files:**
- Create: `lua/necromancer/core/installer.lua`
- Create: `tests/necromancer/core/installer_spec.lua`

Plugin installation logic.

---

## Phase 3: Commands

### Task 9: Implement Commands Module

**Files:**
- Create: `lua/necromancer/commands.lua`
- Update: `lua/necromancer/init.lua`

`:Necromancer install`, `:Necromancer list`, `:Necromancer init`

---

## Phase 4: Documentation

### Task 10: Create Vim Help

**Files:**
- Create: `doc/necromancer.txt`

---

### Task 11: Update README

**Files:**
- Update: `README.md`

Add Lua v2.0+ installation instructions.

---

## Summary

11 tasks total:
- Phase 1: 4 tasks (foundation)
- Phase 2: 4 tasks (core logic)
- Phase 3: 1 task (commands)
- Phase 4: 2 tasks (documentation)

Each task uses TDD approach with plenary.nvim tests.
