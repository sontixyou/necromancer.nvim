# Necromancer.nvim v2.0 Lua Rewrite Design

Related Issue: [#37](https://github.com/sontixyou/necromancer.nvim/issues/37)

## Overview

Rewrite Necromancer.nvim from TypeScript/Node.js to pure Lua implementation, eliminating Node.js dependency entirely.

## Design Decisions

| Item | Decision |
|------|----------|
| Lazy.nvim relationship | Independent (no coexistence) |
| Bootstrap method | Auto-setup code in init.lua |
| Plugin loading | Auto runtimepath addition on startup |
| Config file | Keep `.necromancer.json` (100% backward compatible) |
| Testing | plenary.nvim |
| CLI | Deprecated (`:Necromancer` command only) |

## Priority

1. **Distribution simplification** - No Node.js required
2. **Neovim ecosystem integration** - Native plugin experience
3. **Performance** - Eliminate Node.js startup overhead
4. **Maintainability** - Unified Lua codebase

## Architecture

```
init.lua (bootstrap)
    |
plugin/necromancer.lua (auto-load)
    |
lua/necromancer/init.lua
    +-- config.lua (JSON loading)
    +-- commands.lua (Neovim command registration)
    +-- core/
        +-- validator.lua
        +-- git.lua
        +-- installer.lua
        +-- dependencies.lua
```

## Bootstrap

Users add this to their `init.lua`:

```lua
-- Necromancer bootstrap
local necromancer_path = vim.fn.stdpath("data") .. "/necromancer/necromancer.nvim"
if not vim.loop.fs_stat(necromancer_path) then
  vim.fn.system({
    "git", "clone",
    "https://github.com/sontixyou/necromancer.nvim",
    necromancer_path,
  })
end
vim.opt.rtp:prepend(necromancer_path)
require("necromancer").setup()
```

### setup() Behavior

1. Find `.necromancer.json` (current directory -> `~/.config/necromancer/`)
2. Add installed plugin directories to `runtimepath`
3. Register `:Necromancer` command

### Plugin Install Directory

- Unix: `~/.local/share/nvim/necromancer/plugins/<plugin-name>/`
- Windows: `%LOCALAPPDATA%\nvim\necromancer\plugins\<plugin-name>\`

(Same as current TypeScript version)

## Commands

```
:Necromancer install [plugin]  -- Install all or specified plugin
:Necromancer update [plugin]   -- Update all or specified plugin
:Necromancer list              -- Show installed plugins
:Necromancer verify [--fix]    -- Check commit hash integrity (--fix for auto-repair)
:Necromancer clean             -- Remove plugins deleted from config
:Necromancer init              -- Generate new .necromancer.json
```

### Command Completion

```lua
vim.api.nvim_create_user_command("Necromancer", function(opts)
  -- Subcommand dispatch
end, {
  nargs = "+",
  complete = function(arg_lead, cmd_line, cursor_pos)
    -- Complete "install", "update", "list"...
    -- Complete plugin names for second argument
  end,
})
```

### Output

- Success/failure via `vim.notify()`
- `list` command displays results in a new buffer

## Core Implementation

### Git Operations (Synchronous)

```lua
local function git_exec(args, cwd)
  local cmd = vim.list_extend({ "git" }, args)
  local output = vim.fn.system(cmd, nil, cwd)
  if vim.v.shell_error ~= 0 then
    error({ type = "GitError", message = output })
  end
  return vim.trim(output)
end

-- Usage
git_exec({ "clone", url, target_path })
git_exec({ "checkout", commit_hash }, target_path)
git_exec({ "rev-parse", "HEAD" }, target_path)
```

### Validation (Lua Patterns)

```lua
-- Commit hash: 40 hex characters
local function is_valid_commit_hash(hash)
  return type(hash) == "string"
    and #hash == 40
    and hash:match("^[a-fA-F0-9]+$") ~= nil
end

-- GitHub URL
local function is_valid_github_url(url)
  return type(url) == "string"
    and url:match("^https://github%.com/[%w_-]+/[%w%._-]+%.git$") ~= nil
end
```

### Dependency Resolution

- Port TypeScript `dependencies.ts` directly (Kahn's algorithm)
- Replace with Lua table operations, logic remains identical

## File Structure

```
necromancer.nvim/
+-- lua/
|   +-- necromancer/
|       +-- init.lua              -- setup(), runtimepath addition
|       +-- config.lua            -- JSON loading, path resolution
|       +-- commands.lua          -- :Necromancer command registration
|       +-- core/
|       |   +-- validator.lua     -- URL, hash, name validation
|       |   +-- git.lua           -- git clone/checkout/rev-parse
|       |   +-- installer.lua     -- Installation orchestration
|       |   +-- dependencies.lua  -- Topological sort
|       |   +-- lockfile.lua      -- .necromancer.lock read/write
|       +-- utils/
|           +-- paths.lua         -- Cross-platform paths
|           +-- errors.lua        -- Error type definitions
|           +-- fs.lua            -- File existence checks
+-- plugin/
|   +-- necromancer.lua           -- Auto-load entry (can be empty)
+-- doc/
|   +-- necromancer.txt           -- Vim help
+-- tests/
    +-- minimal_init.lua          -- Minimal test config
    +-- necromancer/
        +-- core/                 -- Unit tests
        +-- integration/          -- Integration tests
```

### TypeScript to Lua Mapping

| TypeScript | Lua |
|------------|-----|
| `src/core/git.ts` | `lua/necromancer/core/git.lua` |
| `src/core/validator.ts` | `lua/necromancer/core/validator.lua` |
| `src/cli/commands/install.ts` | `lua/necromancer/core/installer.lua` |

## Implementation Phases

### Phase 1: Foundation

- [ ] Set up Lua module structure
- [ ] Implement utils/ (paths, errors, fs)
- [ ] Implement core/validator.lua
- [ ] Implement core/git.lua
- [ ] Unit tests (validator, git)

### Phase 2: Core Logic

- [ ] config.lua (JSON loading)
- [ ] core/lockfile.lua
- [ ] core/dependencies.lua (topological sort)
- [ ] core/installer.lua
- [ ] Unit tests (dependencies, installer)

### Phase 3: Commands

- [ ] commands.lua (command registration)
- [ ] install, update, list, verify, clean, init commands
- [ ] Integration tests

### Phase 4: Polish

- [ ] init.lua (setup, runtimepath addition)
- [ ] doc/necromancer.txt (Vim help)
- [ ] Update README (bootstrap instructions)

### Phase 5: Release

- [ ] v2.0.0-beta release
- [ ] Address feedback
- [ ] v2.0.0 official release

## Testing

### Test Configuration

```lua
-- tests/minimal_init.lua
vim.opt.rtp:prepend(".")
vim.opt.rtp:prepend("../plenary.nvim")

-- tests/necromancer/core/validator_spec.lua
describe("validator", function()
  local validator = require("necromancer.core.validator")

  it("validates commit hash", function()
    local hash = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
    assert.is_true(validator.is_valid_commit_hash(hash))
  end)
end)
```

### Running Tests

```bash
nvim --headless -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/necromancer/"
```

## Migration

### For Existing Users

1. `.necromancer.json` - No changes required
2. `.necromancer.lock` - No changes required
3. Installed plugins - Continue working as-is
4. Add bootstrap code to `init.lua`

### TypeScript Version Handling

- Deprecated after v2.0.0 release
- Migration instructions in README
- npm package remains but no longer updated
