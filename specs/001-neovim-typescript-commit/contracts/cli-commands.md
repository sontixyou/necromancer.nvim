# CLI Command Contracts

**Date**: 2025-10-05
**Feature**: 001-neovim-typescript-commit

## Command: `necromancer install`

### Purpose
Install all plugins defined in the configuration file.

### Arguments
- `--config <path>` (optional): Path to config file (defaults to `.necromancer.json` in cwd or `~/.config/necromancer/config.json`)
- `--verbose` (optional): Enable verbose logging (shows git commands and output)
- `--auto-clean` (optional): Automatically remove orphaned plugins (plugins in lock file but not in config)

### Behavior
1. Read and validate configuration file
2. Read existing lock file (if present)
3. Detect and automatically repair any corrupted installations
4. For each plugin in config:
   - If already installed at correct commit: skip
   - If installed at different commit: update
   - If not installed: clone and checkout
5. If `--auto-clean` flag provided: remove orphaned plugins (in lock file but not in config)
6. Update lock file with installation results
7. Report summary of operations

### Exit Codes
- `0`: All plugins installed successfully
- `1`: Configuration file not found or invalid
- `2`: One or more plugins failed to install (partial success)
- `3`: Git command execution failed

### Output Format

**Success (all plugins installed)**:
```
✓ nvim-treesitter [a1b2c3d4] installed
✓ telescope.nvim [b1c2d3e4] already up-to-date
✓ plenary.nvim [c1d2e3f4] updated from [old-hash]

Successfully installed 3 plugins
```

**Partial Success (some failures)**:
```
✓ nvim-treesitter [a1b2c3d4] installed
✗ telescope.nvim [b1c2d3e4] failed: commit not found in repository
✓ plenary.nvim [c1d2e3f4] installed

2 plugins installed, 1 failed
```

**Verbose Output**:
```
[DEBUG] Executing: git clone https://github.com/nvim-treesitter/nvim-treesitter /path/to/plugins/nvim-treesitter
[DEBUG] Executing: git -C /path/to/plugins/nvim-treesitter checkout a1b2c3d4
✓ nvim-treesitter [a1b2c3d4] installed
```

### Error Cases
| Condition | Exit Code | Error Message |
|-----------|-----------|---------------|
| Config file not found | 1 | `Error: Configuration file not found at <path>` |
| Invalid JSON in config | 1 | `Error: Invalid JSON in configuration file: <details>` |
| Invalid plugin definition | 1 | `Error: Invalid plugin '<name>': <validation error>` |
| Git not installed | 3 | `Error: Git command not found. Please install git.` |
| Network failure | 2 | `Error: Failed to clone <repo>: network error` |
| Invalid commit hash | 2 | `Error: Commit <hash> not found in repository <repo>` |
| Permission denied | 2 | `Error: Permission denied writing to <path>` |

---

## Command: `necromancer update`

### Purpose
Update plugins to match configuration file (same as `install` but emphasizes updating existing installations).

### Arguments
- `--config <path>` (optional): Path to config file
- `--verbose` (optional): Enable verbose logging
- `--auto-clean` (optional): Automatically remove orphaned plugins
- `<plugin-name>` (optional): Update only specific plugin(s)

### Behavior
- Detect and automatically repair any corrupted installations
- If no plugin names provided: update all plugins
- If plugin names provided: update only those plugins
- Skip plugins already at correct commit
- If `--auto-clean` flag provided: remove orphaned plugins

### Exit Codes
Same as `install` command

### Output Format

**Update all plugins**:
```
✓ nvim-treesitter [a1b2c3d4] already up-to-date
✓ telescope.nvim [b1c2d3e4] updated from [old-hash]
✓ plenary.nvim [c1d2e3f4] updated from [old-hash]

Updated 2 plugins, 1 already up-to-date
```

**Update specific plugin**:
```
necromancer update nvim-treesitter
✓ nvim-treesitter [a1b2c3d4] updated from [old-hash]
```

### Error Cases
| Condition | Exit Code | Error Message |
|-----------|-----------|---------------|
| Plugin not in config | 1 | `Error: Plugin '<name>' not found in configuration` |
| Other errors | Same as install | Same as install |

---

## Command: `necromancer list`

### Purpose
List all installed plugins and their status.

### Arguments
- `--config <path>` (optional): Path to config file
- `--verbose` (optional): Show full commit hashes and paths

### Behavior
1. Read configuration file and lock file
2. Compare installed plugins with config
3. Show status for each plugin

### Exit Codes
- `0`: Success

### Output Format

**Standard output**:
```
nvim-treesitter   [a1b2c3d4]  ✓ up-to-date
telescope.nvim    [b1c2d3e4]  ⚠ outdated (installed: [old-hash])
plenary.nvim      [c1d2e3f4]  ✗ not installed

3 plugins total: 1 up-to-date, 1 outdated, 1 not installed
```

**Verbose output**:
```
nvim-treesitter
  Status: ✓ up-to-date
  Repo: https://github.com/nvim-treesitter/nvim-treesitter
  Commit: a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0
  Path: /home/user/.local/share/nvim/necromancer/plugins/nvim-treesitter
  Installed: 2025-10-05T12:34:56Z
```

### Error Cases
| Condition | Exit Code | Error Message |
|-----------|-----------|---------------|
| Config file not found | 1 | `Error: Configuration file not found` |
| Invalid config | 1 | `Error: Invalid configuration: <details>` |

---

## Command: `necromancer verify`

### Purpose
Verify that installed plugins match configuration and detect corruption.

### Arguments
- `--config <path>` (optional): Path to config file
- `--fix` (optional): Attempt to repair corrupted installations

### Behavior
1. Read configuration and lock file
2. For each installed plugin:
   - Verify directory exists
   - Verify git repository is valid
   - Verify checked out commit matches lock file
3. Report discrepancies
4. If `--fix`: re-checkout corrupt plugins

### Exit Codes
- `0`: All plugins verified successfully
- `1`: Configuration error
- `2`: One or more plugins have issues

### Output Format

**All verified**:
```
✓ nvim-treesitter verified
✓ telescope.nvim verified
✓ plenary.nvim verified

All 3 plugins verified successfully
```

**Issues found**:
```
✓ nvim-treesitter verified
✗ telescope.nvim: directory not found
✗ plenary.nvim: git repository corrupt (not a git repo)

1 verified, 2 with issues
```

**With --fix**:
```
✓ nvim-treesitter verified
✗ telescope.nvim: directory not found
  → Re-installing telescope.nvim...
  ✓ telescope.nvim repaired
✗ plenary.nvim: git repository corrupt
  → Re-cloning plenary.nvim...
  ✓ plenary.nvim repaired

3 plugins verified, 2 repaired
```

### Error Cases
| Condition | Exit Code | Error Message |
|-----------|-----------|---------------|
| Lock file not found | 2 | `Warning: No lock file found. Run 'necromancer install' first.` |
| Git not installed | 3 | `Error: Git command not found` |

---

## Command: `necromancer clean`

### Purpose
Remove plugins that are no longer in the configuration file (orphaned plugins).

### Arguments
- `--config <path>` (optional): Path to config file
- `--dry-run` (optional): Show what would be removed without removing
- `--force` (optional): Skip confirmation prompt

### Behavior
1. Find plugins in lock file but not in config file
2. Show list of orphaned plugins
3. Prompt for confirmation (unless `--force`)
4. Remove orphaned plugin directories
5. Update lock file

### Exit Codes
- `0`: Success or no orphaned plugins
- `1`: Configuration error
- `2`: Failed to remove some plugins

### Output Format

**No orphaned plugins**:
```
No orphaned plugins found.
```

**Dry run**:
```
necromancer clean --dry-run
The following plugins would be removed:
  - old-plugin-1 (/path/to/plugins/old-plugin-1)
  - old-plugin-2 (/path/to/plugins/old-plugin-2)

Run 'necromancer clean' to remove them.
```

**With confirmation**:
```
The following plugins are no longer in your configuration:
  - old-plugin-1
  - old-plugin-2

Remove these plugins? [y/N]: y
✓ Removed old-plugin-1
✓ Removed old-plugin-2

Removed 2 orphaned plugins
```

**With --force**:
```
necromancer clean --force
✓ Removed old-plugin-1
✓ Removed old-plugin-2

Removed 2 orphaned plugins
```

### Error Cases
| Condition | Exit Code | Error Message |
|-----------|-----------|---------------|
| Permission denied | 2 | `Error: Failed to remove <plugin>: permission denied` |
| Plugin in use | 2 | `Error: Failed to remove <plugin>: directory in use` |

---

## Command: `necromancer init`

### Purpose
Create a new configuration file with example plugins.

### Arguments
- `--config <path>` (optional): Path for new config file (defaults to `.necromancer.json`)
- `--force` (optional): Overwrite existing config file

### Behavior
1. Check if config file exists
2. If exists and no `--force`: error
3. Create config file with example structure

### Exit Codes
- `0`: Config file created successfully
- `1`: Config file already exists (without --force)
- `2`: Failed to write config file

### Output Format

**Success**:
```
Created configuration file at .necromancer.json

Edit the file to add your Neovim plugins, then run:
  necromancer install
```

**File exists**:
```
Error: Configuration file already exists at .necromancer.json
Use --force to overwrite.
```

### Created Config Template
```json
{
  "plugins": [
    {
      "name": "example-plugin",
      "repo": "https://github.com/owner/repository",
      "commit": "0000000000000000000000000000000000000000"
    }
  ]
}
```

---

## Common Behaviors

### Configuration File Resolution
1. If `--config` specified: use that path
2. Else if `.necromancer.json` exists in cwd: use it
3. Else if `~/.config/necromancer/config.json` exists: use it
4. Else: error

### Lock File Location
- Same directory as config file with `.lock` extension
- `.necromancer.json` → `.necromancer.lock`
- `~/.config/necromancer/config.json` → `~/.config/necromancer/lock.json`

### Logging Levels
- **Normal**: Only summary and errors
- **Verbose** (`--verbose`): Git commands, detailed progress
- **Quiet** (`--quiet`): Only errors (future enhancement)

### Signal Handling
- `SIGINT` (Ctrl+C): Clean up partial operations, save lock file state, exit with code 130
- `SIGTERM`: Same as SIGINT

### Color Output
- Use color if stdout is a TTY
- Disable color if stdout is not a TTY (piping, redirection)
- `--no-color` flag to force disable (future enhancement)
