# Quickstart Guide: Necromancer Plugin Manager

**Date**: 2025-10-05
**Feature**: 001-neovim-typescript-commit

## Prerequisites
- Node.js 24+ installed
- Git installed and available in PATH
- Neovim installed (for actual plugin usage)

## Installation Test Scenarios

### Scenario 1: First-Time Setup
**Goal**: Initialize a new configuration and install plugins from scratch.

**Steps**:
```bash
# 1. Create a new configuration file
necromancer init

# 2. Edit .necromancer.json to add real plugins
# Example content:
cat > .necromancer.json << 'EOF'
{
  "plugins": [
    {
      "name": "plenary.nvim",
      "repo": "https://github.com/nvim-lua/plenary.nvim",
      "commit": "a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683"
    },
    {
      "name": "nvim-treesitter",
      "repo": "https://github.com/nvim-treesitter/nvim-treesitter",
      "commit": "0dfbf5e48e8551212c2a9f1c5614d008f4e86eba"
    }
  ]
}
EOF

# 3. Install all plugins
necromancer install

# 4. Verify installation
necromancer list
```

**Expected Output**:
```
✓ plenary.nvim [a3e3bc82] installed
✓ nvim-treesitter [0dfbf5e4] installed

Successfully installed 2 plugins

plenary.nvim      [a3e3bc82]  ✓ up-to-date
nvim-treesitter   [0dfbf5e4]  ✓ up-to-date

2 plugins total: 2 up-to-date, 0 outdated, 0 not installed
```

**Validation**:
- [ ] Config file created at `.necromancer.json`
- [ ] Lock file created at `.necromancer.lock`
- [ ] Plugins installed in `~/.local/share/nvim/necromancer/plugins/`
- [ ] Each plugin directory contains a `.git` folder
- [ ] `necromancer list` shows all plugins as up-to-date

---

### Scenario 2: Update Plugin Versions
**Goal**: Change commit hashes in config and update plugins.

**Steps**:
```bash
# 1. List current installations
necromancer list

# 2. Update commit hash in config file
# Change plenary.nvim commit to a different commit
cat > .necromancer.json << 'EOF'
{
  "plugins": [
    {
      "name": "plenary.nvim",
      "repo": "https://github.com/nvim-lua/plenary.nvim",
      "commit": "8aad4396840be7fc42526d8f5f8ab826d7664f1d"
    },
    {
      "name": "nvim-treesitter",
      "repo": "https://github.com/nvim-treesitter/nvim-treesitter",
      "commit": "0dfbf5e48e8551212c2a9f1c5614d008f4e86eba"
    }
  ]
}
EOF

# 3. Check status before update
necromancer list

# 4. Update plugins
necromancer update

# 5. Verify update
necromancer list
```

**Expected Output**:
```
# After step 3 (before update)
plenary.nvim      [8aad4396]  ⚠ outdated (installed: [a3e3bc82])
nvim-treesitter   [0dfbf5e4]  ✓ up-to-date

# After step 4 (update)
✓ nvim-treesitter [0dfbf5e4] already up-to-date
✓ plenary.nvim [8aad4396] updated from [a3e3bc82]

Updated 1 plugin, 1 already up-to-date

# After step 5 (verify)
plenary.nvim      [8aad4396]  ✓ up-to-date
nvim-treesitter   [0dfbf5e4]  ✓ up-to-date
```

**Validation**:
- [ ] `plenary.nvim` updated to new commit
- [ ] `nvim-treesitter` not re-downloaded (already correct)
- [ ] Lock file updated with new commit hash and timestamp
- [ ] Git repository in plugin directory shows correct commit

---

### Scenario 3: Add New Plugin
**Goal**: Add a new plugin to existing configuration.

**Steps**:
```bash
# 1. Add telescope.nvim to config
cat > .necromancer.json << 'EOF'
{
  "plugins": [
    {
      "name": "plenary.nvim",
      "repo": "https://github.com/nvim-lua/plenary.nvim",
      "commit": "8aad4396840be7fc42526d8f5f8ab826d7664f1d"
    },
    {
      "name": "nvim-treesitter",
      "repo": "https://github.com/nvim-treesitter/nvim-treesitter",
      "commit": "0dfbf5e48e8551212c2a9f1c5614d008f4e86eba"
    },
    {
      "name": "telescope.nvim",
      "repo": "https://github.com/nvim-telescope/telescope.nvim",
      "commit": "6258d50b09f9ae087317e6437868f5fb308c7026"
    }
  ]
}
EOF

# 2. Install (installs only the new plugin)
necromancer install

# 3. Verify
necromancer list
```

**Expected Output**:
```
✓ plenary.nvim [8aad4396] already up-to-date
✓ nvim-treesitter [0dfbf5e4] already up-to-date
✓ telescope.nvim [6258d50b] installed

1 plugin installed, 2 already up-to-date

plenary.nvim      [8aad4396]  ✓ up-to-date
nvim-treesitter   [0dfbf5e4]  ✓ up-to-date
telescope.nvim    [6258d50b]  ✓ up-to-date

3 plugins total: 3 up-to-date, 0 outdated, 0 not installed
```

**Validation**:
- [ ] Only `telescope.nvim` downloaded (others skipped)
- [ ] Lock file contains all 3 plugins
- [ ] All plugins show as up-to-date

---

### Scenario 4: Remove Plugin and Clean
**Goal**: Remove a plugin from config and clean up orphaned files.

**Steps**:
```bash
# 1. Remove nvim-treesitter from config
cat > .necromancer.json << 'EOF'
{
  "plugins": [
    {
      "name": "plenary.nvim",
      "repo": "https://github.com/nvim-lua/plenary.nvim",
      "commit": "8aad4396840be7fc42526d8f5f8ab826d7664f1d"
    },
    {
      "name": "telescope.nvim",
      "repo": "https://github.com/nvim-telescope/telescope.nvim",
      "commit": "6258d50b09f9ae087317e6437868f5fb308c7026"
    }
  ]
}
EOF

# 2. Check for orphaned plugins (dry run)
necromancer clean --dry-run

# 3. Remove orphaned plugins
necromancer clean

# 4. Verify
necromancer list
ls ~/.local/share/nvim/necromancer/plugins/
```

**Expected Output**:
```
# After step 2 (dry run)
The following plugins would be removed:
  - nvim-treesitter (~/.local/share/nvim/necromancer/plugins/nvim-treesitter)

Run 'necromancer clean' to remove them.

# After step 3 (clean with confirmation)
The following plugins are no longer in your configuration:
  - nvim-treesitter

Remove these plugins? [y/N]: y
✓ Removed nvim-treesitter

Removed 1 orphaned plugin

# After step 4 (verify)
plenary.nvim      [8aad4396]  ✓ up-to-date
telescope.nvim    [6258d50b]  ✓ up-to-date

2 plugins total: 2 up-to-date, 0 outdated, 0 not installed

# Directory listing shows only remaining plugins
plenary.nvim  telescope.nvim
```

**Validation**:
- [ ] `nvim-treesitter` directory deleted
- [ ] `nvim-treesitter` removed from lock file
- [ ] Other plugins unaffected

---

### Scenario 5: Verify and Repair Installation
**Goal**: Detect corrupted installation and repair it.

**Steps**:
```bash
# 1. Manually corrupt a plugin (simulate corruption)
rm -rf ~/.local/share/nvim/necromancer/plugins/plenary.nvim/.git

# 2. Verify installations (should detect corruption)
necromancer verify

# 3. Repair corrupted plugin
necromancer verify --fix

# 4. Verify again (should be clean)
necromancer verify
```

**Expected Output**:
```
# After step 2 (verify)
✗ plenary.nvim: git repository corrupt (not a git repo)
✓ telescope.nvim verified

1 verified, 1 with issues
# Exit code: 2

# After step 3 (repair)
✗ plenary.nvim: git repository corrupt
  → Re-cloning plenary.nvim...
  ✓ plenary.nvim repaired
✓ telescope.nvim verified

2 plugins verified, 1 repaired
# Exit code: 0

# After step 4 (verify again)
✓ plenary.nvim verified
✓ telescope.nvim verified

All 2 plugins verified successfully
# Exit code: 0
```

**Validation**:
- [ ] Corrupted plugin detected
- [ ] `--fix` flag re-clones corrupted plugin
- [ ] Plugin restored to correct commit
- [ ] Lock file updated with repair timestamp

---

### Scenario 6: Error Handling - Invalid Commit
**Goal**: Gracefully handle invalid commit hash.

**Steps**:
```bash
# 1. Add plugin with non-existent commit
cat > .necromancer.json << 'EOF'
{
  "plugins": [
    {
      "name": "plenary.nvim",
      "repo": "https://github.com/nvim-lua/plenary.nvim",
      "commit": "0000000000000000000000000000000000000000"
    }
  ]
}
EOF

# 2. Attempt installation
necromancer install
```

**Expected Output**:
```
✗ plenary.nvim [00000000] failed: commit 0000000000000000000000000000000000000000 not found in repository

0 plugins installed, 1 failed
# Exit code: 2
```

**Validation**:
- [ ] Clear error message identifying the problem
- [ ] Exit code 2 (partial failure)
- [ ] Lock file not updated for failed plugin
- [ ] No partial/corrupt files left behind

---

### Scenario 7: Error Handling - Invalid Config
**Goal**: Validate configuration file before operations.

**Steps**:
```bash
# 1. Create invalid config (duplicate plugin names)
cat > .necromancer.json << 'EOF'
{
  "plugins": [
    {
      "name": "plenary.nvim",
      "repo": "https://github.com/nvim-lua/plenary.nvim",
      "commit": "8aad4396840be7fc42526d8f5f8ab826d7664f1d"
    },
    {
      "name": "plenary.nvim",
      "repo": "https://github.com/nvim-lua/plenary.nvim",
      "commit": "a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683"
    }
  ]
}
EOF

# 2. Attempt installation
necromancer install
```

**Expected Output**:
```
Error: Invalid plugin configuration: Duplicate plugin name 'plenary.nvim'
# Exit code: 1
```

**Validation**:
- [ ] Config validated before any git operations
- [ ] Clear error message
- [ ] Exit code 1 (configuration error)
- [ ] No side effects (no files changed)

---

## Integration with Neovim

**Adding plugins to Neovim runtimepath**:

Create `~/.config/nvim/init.lua` or add to existing:
```lua
-- Add necromancer plugins to runtimepath
local necromancer_path = vim.fn.expand('~/.local/share/nvim/necromancer/plugins')
local plugins = vim.fn.globpath(necromancer_path, '*', false, true)

for _, plugin in ipairs(plugins) do
  vim.opt.runtimepath:append(plugin)
end

-- Now you can use the plugins
require('telescope').setup{}
require('nvim-treesitter.configs').setup{}
```

**Testing in Neovim**:
```bash
# Start Neovim
nvim

# In Neovim command mode:
:lua print(vim.inspect(vim.api.nvim_list_runtime_paths()))
# Should show necromancer plugin paths

:checkhealth telescope
# Should show telescope is loaded correctly
```

---

## Performance Benchmarks

**Expected performance targets** (from spec NFR-001, NFR-002):

| Operation | Target | Measurement |
|-----------|--------|-------------|
| Install 50 plugins (fresh) | <2 minutes | Time from `necromancer install` to completion (~2.4s per plugin avg) |
| Install 10 plugins (fresh) | <24s | Extrapolated from 50-plugin target |
| Update 1 plugin (existing) | <3s | Time to fetch and checkout new commit |
| Config parsing (100 plugins) | <100ms | Time to load and validate config |
| List command | <50ms | Time to display status |
| Verify command | <200ms | Time to check all installations |

**Test command**:
```bash
time necromancer install
```

---

## Troubleshooting

### Plugin not showing in Neovim
1. Verify installation: `necromancer list`
2. Check Neovim runtimepath: `:lua print(vim.inspect(vim.opt.runtimepath:get()))`
3. Verify plugin directory exists: `ls ~/.local/share/nvim/necromancer/plugins/`

### Git clone fails
1. Check network: `ping github.com`
2. Verify git is installed: `git --version`
3. Check repository URL: Try cloning manually
4. Use verbose mode: `necromancer install --verbose`

### Permission denied errors
1. Check plugin directory permissions: `ls -la ~/.local/share/nvim/necromancer/`
2. Ensure directory is writable: `touch ~/.local/share/nvim/necromancer/test && rm ~/.local/share/nvim/necromancer/test`

### Commit not found
1. Verify commit exists in repository: Visit GitHub and check commit history
2. Ensure full 40-character hash is used (not short hash)
3. Try updating repository: `necromancer verify --fix`
