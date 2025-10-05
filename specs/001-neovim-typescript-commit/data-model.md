# Data Model: Neovim Plugin Manager

**Date**: 2025-10-05
**Feature**: 001-neovim-typescript-commit

## Core Entities

### PluginDefinition
Represents a plugin entry in the user's configuration file.

**Fields**:
- `name: string` - Unique plugin identifier (used for directory name)
- `repo: string` - GitHub repository URL (https://github.com/owner/repo)
- `commit: string` - 40-character SHA-1 commit hash

**Validation Rules**:
- `name`: Must be non-empty, alphanumeric with hyphens/underscores, max 100 chars
- `repo`: Must match GitHub URL regex pattern
- `commit`: Must be exactly 40 hexadecimal characters (SHA-1 hash)

**Example**:
```typescript
{
  name: "nvim-treesitter",
  repo: "https://github.com/nvim-treesitter/nvim-treesitter",
  commit: "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0"
}
```

### ConfigFile
Represents the entire user configuration.

**Fields**:
- `plugins: PluginDefinition[]` - Array of plugin definitions
- `installDir?: string` - Optional custom installation directory (defaults to standard path)

**Validation Rules**:
- `plugins`: Array must not be empty
- `plugins`: All plugin names must be unique
- `installDir`: If provided, must be an absolute path or start with `~`

**Default Values**:
- `installDir`: `~/.local/share/nvim/necromancer/plugins` (Unix-like)
- `installDir`: `%LOCALAPPDATA%\nvim\necromancer\plugins` (Windows)

**Example**:
```json
{
  "plugins": [
    {
      "name": "nvim-treesitter",
      "repo": "https://github.com/nvim-treesitter/nvim-treesitter",
      "commit": "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0"
    },
    {
      "name": "telescope.nvim",
      "repo": "https://github.com/nvim-telescope/telescope.nvim",
      "commit": "b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0"
    }
  ]
}
```

### InstalledPlugin
Represents a plugin that has been successfully installed.

**Fields**:
- `name: string` - Plugin identifier (matches PluginDefinition.name)
- `repo: string` - GitHub repository URL
- `commit: string` - Installed commit hash
- `installedAt: string` - ISO 8601 timestamp of installation
- `path: string` - Absolute path to installed plugin directory

**Validation Rules**:
- `name`, `repo`, `commit`: Same as PluginDefinition
- `installedAt`: Must be valid ISO 8601 datetime
- `path`: Must be absolute path and exist on filesystem

**State Tracking**:
- Plugin is "up-to-date" if `commit` matches config file commit
- Plugin is "outdated" if commits differ
- Plugin is "orphaned" if not in config file but exists in lock file

**Example**:
```typescript
{
  name: "nvim-treesitter",
  repo: "https://github.com/nvim-treesitter/nvim-treesitter",
  commit: "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0",
  installedAt: "2025-10-05T12:34:56Z",
  path: "/home/user/.local/share/nvim/necromancer/plugins/nvim-treesitter"
}
```

### LockFile
Represents the lock file that tracks installation state.

**Fields**:
- `version: string` - Lock file format version (currently "1")
- `generated: string` - ISO 8601 timestamp of lock file generation
- `plugins: InstalledPlugin[]` - Array of installed plugins

**Validation Rules**:
- `version`: Must be "1" (reject if different version)
- `generated`: Must be valid ISO 8601 datetime
- `plugins`: All plugin names must be unique

**File Location**: `.necromancer.lock` in project root or `~/.config/necromancer/lock.json`

**Example**:
```json
{
  "version": "1",
  "generated": "2025-10-05T12:34:56Z",
  "plugins": [
    {
      "name": "nvim-treesitter",
      "repo": "https://github.com/nvim-treesitter/nvim-treesitter",
      "commit": "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0",
      "installedAt": "2025-10-05T12:34:56Z",
      "path": "/home/user/.local/share/nvim/necromancer/plugins/nvim-treesitter"
    }
  ]
}
```

### GitOperationResult
Represents the result of a git operation.

**Fields**:
- `success: boolean` - Whether operation succeeded
- `output: string` - stdout from git command
- `error?: string` - stderr if operation failed
- `command: string` - The git command that was executed (for logging)

**Usage**: Returned by all git operations for uniform error handling.

**Example**:
```typescript
{
  success: true,
  output: "Cloning into 'nvim-treesitter'...",
  command: "git clone https://github.com/nvim-treesitter/nvim-treesitter"
}
```

### InstallationStatus
Represents the status of a plugin installation operation.

**Fields**:
- `plugin: PluginDefinition` - Plugin being installed
- `status: 'success' | 'failed' | 'skipped' | 'updated'`
- `message: string` - Human-readable status message
- `error?: Error` - Error object if failed

**Status Values**:
- `success`: Plugin newly installed
- `failed`: Installation failed (error field populated)
- `skipped`: Already installed at correct commit
- `updated`: Existing installation updated to new commit

**Example**:
```typescript
{
  plugin: { name: "nvim-treesitter", repo: "...", commit: "..." },
  status: "success",
  message: "Successfully installed nvim-treesitter at commit a1b2c3d4"
}
```

## Relationships

```
ConfigFile (1) ──────has many──────▶ PluginDefinition (*)
                                           │
                                           │ matches
                                           ▼
LockFile (1) ────────has many──────▶ InstalledPlugin (*)
                                           │
                                           │ stored at
                                           ▼
                                    Filesystem Directory
```

**Key Relationships**:
- Each ConfigFile contains multiple PluginDefinitions
- Each LockFile contains multiple InstalledPlugins
- PluginDefinition and InstalledPlugin match by `name` field
- Install operation creates InstalledPlugin from PluginDefinition

## State Transitions

### Plugin Installation Lifecycle

```
[Not in Config] ──add to config──▶ [Defined]
                                      │
                                      │ necromancer install
                                      ▼
                                   [Installing]
                                      │
                  ┌───────────────────┴───────────────────┐
                  │                                       │
                  ▼                                       ▼
             [Installed] ◀──necromancer update──   [Update Failed]
                  │
                  │ modify commit in config
                  ▼
              [Outdated] ──necromancer update──▶ [Updating]
                  │                                   │
                  │                                   ▼
                  │                              [Installed]
                  │
                  │ remove from config
                  ▼
              [Orphaned] ──necromancer clean──▶ [Removed]
```

**State Descriptions**:
- **Defined**: In config file but not installed
- **Installing**: Git clone/checkout in progress
- **Installed**: Successfully installed, matches config
- **Outdated**: Installed but commit doesn't match config
- **Updating**: Git fetch/checkout in progress
- **Orphaned**: In lock file but removed from config
- **Removed**: Deleted from filesystem and lock file

## Validation Rules Summary

### Plugin Name Validation
```typescript
function isValidPluginName(name: string): boolean {
  return /^[\w-]{1,100}$/.test(name);
}
```

### GitHub URL Validation
```typescript
function isValidGitHubUrl(url: string): boolean {
  return /^https:\/\/github\.com\/[\w-]+\/[\w.-]+(?:\.git)?$/.test(url);
}
```

### Commit Hash Validation
```typescript
function isValidCommitHash(hash: string): boolean {
  return /^[a-f0-9]{40}$/i.test(hash);
}
```

### Path Validation
```typescript
function isValidInstallPath(path: string): boolean {
  return path.startsWith('/') || path.startsWith('~') || /^[A-Z]:\\/.test(path);
}
```

## Invariants

1. **Unique Plugin Names**: No two plugins in ConfigFile can have the same name
2. **Unique Plugin Names in Lock**: No two plugins in LockFile can have the same name
3. **Valid Commits**: All commit hashes must be valid SHA-1 format
4. **Valid URLs**: All repo URLs must be valid GitHub HTTPS URLs
5. **Path Existence**: All InstalledPlugin.path values must exist on filesystem
6. **Lock File Subset**: LockFile plugins are a subset or equal to ConfigFile plugins (after successful install)
7. **Timestamp Ordering**: InstalledPlugin.installedAt must not be in the future
