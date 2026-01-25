# Necromancer.nvim

**Pure Lua Neovim plugin manager with commit-based versioning**

Necromancer is a deterministic, zero-dependency Neovim plugin manager that uses Git commit hashes for precise version control. Built entirely in Lua with no external dependencies - just Neovim and Git.

> **Note:** v2.0 is a complete rewrite in pure Lua. The v1.x TypeScript/Node.js version is deprecated and no longer maintained.

## Features

- **Pure Lua implementation**: No Node.js, npm, or external runtime required
- **Commit-based versioning**: Pin plugins to exact Git commits (40-character SHA-1 hashes)
- **Plugin dependencies**: Automatic dependency resolution and installation ordering
- **Zero dependencies**: Only requires Neovim (0.9+) and Git
- **Deterministic installations**: Lock file ensures reproducible plugin environments
- **Native Neovim integration**: Use `:Necromancer` commands directly in Neovim
- **Auto-repair**: Detects and fixes corrupted plugin installations

## Installation

### Prerequisites

- Neovim 0.9+ (with Lua 5.1/LuaJIT support)
- Git installed and available in PATH

### Bootstrap Installation

Add the following to your `~/.config/nvim/init.lua`:

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
require("necromancer").setup({
  -- Optional: specify a custom config file path
  -- config_path = "~/.config/nvim/.necromancer.json",
  -- Optional: specify a custom plugin installation directory
  -- install_dir = "~/.local/share/nvim/necromancer/plugins",
})
```

This will:
1. Clone necromancer.nvim on first launch if not present
2. Add it to Neovim's runtime path
3. Initialize the plugin manager

### Verify Installation

Open Neovim and run:

```vim
:Necromancer list
```

## Quick Start

### 1. Create configuration

Create a `.necromancer.json` file in your Neovim config directory (`~/.config/nvim/`):

```json
{
  "plugins": [
    {
      "name": "plenary.nvim",
      "repo": "https://github.com/nvim-lua/plenary.nvim",
      "commit": "a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683"
    },
    {
      "name": "telescope.nvim",
      "repo": "https://github.com/nvim-telescope/telescope.nvim",
      "commit": "6312868392331c9c0f22af9b6c6957284e07e1a6",
      "dependencies": ["plenary.nvim"]
    }
  ]
}
```

### 2. Install plugins

In Neovim, run:

```vim
:Necromancer install
```

Plugins are installed to:
- **Unix/macOS**: `~/.local/share/nvim/necromancer/plugins/`
- **Windows**: `%LOCALAPPDATA%\nvim\necromancer\plugins\`

### 3. Configure plugins

After installation, configure your plugins in `init.lua`:

```lua
-- Plugins are automatically added to runtimepath by necromancer
require('telescope').setup{}
```

## Commands

All commands are available via the `:Necromancer` command:

### `:Necromancer install [plugin]`

Install all plugins from configuration file, or a specific plugin by name.

```vim
" Install all plugins
:Necromancer install

" Install a specific plugin
:Necromancer install telescope.nvim
```

### `:Necromancer list`

Show installed plugins in a floating window.

```vim
:Necromancer list
```

### `:Necromancer init`

Create a new `.necromancer.json` configuration file in the current directory.

```vim
:Necromancer init
```

### `:Necromancer status`

Show status of all configured plugins with update information.

```vim
:Necromancer status
```

This command fetches the latest commits from remote repositories and displays:
- Current installation state (up-to-date, outdated, update available, not installed, corrupted)
- Current commit vs. configured commit
- Available remote updates

### `:Necromancer update [plugin]`

Update plugins to the latest commit from their default branch (7 days ago for stability).

```vim
" Update all plugins
:Necromancer update

" Update a specific plugin
:Necromancer update telescope.nvim
```

This updates both the plugin files and the `.necromancer.json` configuration.

### `:Necromancer clean`

Remove orphan plugins that are no longer in the configuration file.

```vim
:Necromancer clean
```

### `:Necromancer self-update`

Update necromancer.nvim itself to the latest version.

```vim
:Necromancer self-update
```

## Setup Options

The `setup()` function accepts the following options:

```lua
require("necromancer").setup({
  -- Custom path to config file (optional)
  -- If not specified, searches for .necromancer.json in current directory,
  -- then falls back to ~/.config/necromancer/config.json
  config_path = "~/.config/nvim/.necromancer.json",

  -- Custom plugin installation directory (optional)
  -- Default: ~/.local/share/nvim/necromancer/plugins (Unix/macOS)
  --          %LOCALAPPDATA%\nvim\necromancer\plugins (Windows)
  install_dir = "~/my-plugins",

  -- Auto-fetch necromancer.nvim updates on startup (optional)
  -- Can be boolean or table with options
  autofetch = {
    enabled = true,        -- Enable/disable autofetch (default: true)
    notify_updates = true, -- Show notification when updates are available (default: true)
    quiet = false,         -- Suppress debug messages (default: false)
  },
})
```

### Global Configuration

You can use a global configuration by specifying `config_path` in your `init.lua`:

```lua
require("necromancer").setup({
  config_path = "~/.config/nvim/.necromancer.json",
})
```

This allows you to use the same plugin configuration from any directory.

## Configuration File Format

### Basic structure

```json
{
  "plugins": [
    {
      "name": "plugin-name",
      "repo": "https://github.com/owner/repository",
      "commit": "0000000000000000000000000000000000000000"
    }
  ],
  "installDir": "~/.local/share/nvim/necromancer/plugins"
}
```

### Fields

- **plugins** (required): Array of plugin definitions
  - **name** (required): Plugin directory name (alphanumeric, hyphens, underscores, dots; 1-100 chars)
  - **repo** (required): GitHub HTTPS URL (e.g., `https://github.com/owner/repo`)
  - **commit** (required): Full 40-character Git commit hash (SHA-1)
  - **dependencies** (optional): Array of plugin names this plugin depends on

- **installDir** (optional): Custom installation directory (default: platform-specific)

### Plugin Dependencies

Necromancer supports plugin dependencies to ensure proper loading order. When a plugin specifies dependencies, those dependencies will be installed before the dependent plugin.

```json
{
  "plugins": [
    {
      "name": "telescope.nvim",
      "repo": "https://github.com/nvim-telescope/telescope.nvim",
      "commit": "abc1234567890123456789012345678901234567",
      "dependencies": ["plenary.nvim"]
    },
    {
      "name": "plenary.nvim",
      "repo": "https://github.com/nvim-lua/plenary.nvim",
      "commit": "def1234567890123456789012345678901234567"
    },
    {
      "name": "telescope-ui-select.nvim",
      "repo": "https://github.com/nvim-telescope/telescope-ui-select.nvim",
      "commit": "ghi1234567890123456789012345678901234567",
      "dependencies": ["telescope.nvim"]
    }
  ]
}
```

**Installation order**: `plenary.nvim` -> `telescope.nvim` -> `telescope-ui-select.nvim`

**Dependency features:**
- **Topological sorting**: Dependencies are resolved using topological sorting to determine the correct installation order
- **Circular dependency detection**: Configuration validation will detect and reject circular dependencies
- **Missing dependency validation**: All dependencies must be defined in the configuration
- **Transitive dependencies**: Dependencies of dependencies are handled automatically

### Validation rules

- Plugin names must be unique
- GitHub URLs must use HTTPS (not SSH)
- Commit hashes must be exactly 40 hexadecimal characters
- No shell metacharacters allowed in any field
- All dependencies must reference existing plugin names in the configuration
- Circular dependencies are not allowed

## Lock File

Necromancer maintains a `.necromancer.lock` file that tracks:

- Installed plugin versions (commit hashes)
- Installation timestamps
- Lock file format version

**Do not edit lock files manually.** They are automatically updated by install/update/clean commands.

## Troubleshooting

### Plugin not showing in Neovim

1. Verify installation: `:Necromancer list`
2. Check Neovim runtimepath: `:lua print(vim.inspect(vim.opt.runtimepath:get()))`
3. Verify plugin directory exists: `ls ~/.local/share/nvim/necromancer/plugins/`

### Git clone fails

1. Check network: `ping github.com`
2. Verify git is installed: `git --version`
3. Check repository URL: Try cloning manually with `git clone <url>`

### Permission denied errors

1. Check plugin directory permissions:
   ```bash
   ls -la ~/.local/share/nvim/necromancer/
   ```
2. Ensure directory is writable:
   ```bash
   touch ~/.local/share/nvim/necromancer/test && rm ~/.local/share/nvim/necromancer/test
   ```

### Commit not found

1. Verify commit exists in repository: Visit GitHub and check commit history
2. Ensure full 40-character hash is used (not short hash like `abc1234`)
3. Try reinstalling: `:Necromancer install <plugin-name>`

### Corrupted installation

If a plugin installation is corrupted, reinstall it:

```vim
:Necromancer install <plugin-name>
```

Necromancer will detect and auto-repair corrupted installations during install.

## Migration from v1.x (TypeScript)

If you were using the TypeScript version (v1.x):

1. Remove the npm global package: `npm uninstall -g necromancer.nvim`
2. Your `.necromancer.json` config files are compatible - no changes needed
3. Add the bootstrap code to your `init.lua` (see Installation section)
4. Run `:Necromancer install` to reinstall plugins

## Development

### Project structure

```
necromancer.nvim/
├── lua/
│   └── necromancer/
│       ├── init.lua              # Main entry point, setup()
│       ├── commands.lua          # :Necromancer command definitions
│       ├── core/
│       │   ├── autofetch.lua     # Async update checking on startup
│       │   ├── config.lua        # Configuration file parsing
│       │   ├── dependencies.lua  # Dependency resolution (topological sort)
│       │   ├── git.lua           # Git operations (clone, fetch, checkout)
│       │   ├── installer.lua     # Plugin installation logic
│       │   ├── lockfile.lua      # Lock file management
│       │   └── validator.lua     # Input validation
│       └── utils/
│           ├── errors.lua        # Custom error types
│           └── paths.lua         # Path utilities
├── tests/
│   └── necromancer/              # Test files (*_spec.lua)
└── README.md
```

### Running tests

```bash
# Run all tests
make test-lua

# Run specific test file
make test-file FILE=tests/necromancer/core/validator_spec.lua

# Install test dependencies (plenary.nvim)
make test-deps
```

## License

MIT

## Contributing

Contributions are welcome! Please ensure:

1. All tests pass
2. Code follows existing Lua patterns
3. New features include tests

## Acknowledgments

Inspired by the need for deterministic, reproducible Neovim plugin management.

---

**Built with simplicity and reliability in mind.**
