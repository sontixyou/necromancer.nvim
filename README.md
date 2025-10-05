# Necromancer

**Neovim plugin manager with commit-based versioning**

Necromancer is a deterministic, zero-dependency Neovim plugin manager that uses Git commit hashes for precise version control. Built with TypeScript and designed for simplicity, reliability, and reproducibility.

## Features

- **Commit-based versioning**: Pin plugins to exact Git commits (40-character SHA-1 hashes)
- **Zero runtime dependencies**: Only Node.js built-ins (fs, child_process, path, crypto)
- **Deterministic installations**: Lock file ensures reproducible plugin environments
- **Fast and lightweight**: Synchronous operations, no network overhead
- **Auto-repair**: Detects and fixes corrupted plugin installations
- **Simple CLI**: Intuitive commands for all plugin management tasks

## Installation

### Prerequisites

- Node.js 24+ (or any version with ES2020+ support)
- Git installed and available in PATH
- Neovim (for using the installed plugins)
- Deno (required for denops-based plugins) - [Installation guide](https://deno.land/)

### Install globally via npm

```bash
npm install -g necromancer
```

### Verify installation

```bash
necromancer --help
```

## Quick Start

### 1. Initialize configuration

```bash
necromancer init
```

This creates a `.necromancer.json` file in the current directory.

### 2. Edit configuration

Edit `.necromancer.json` to add your Neovim plugins:

```json
{
  "plugins": [
    {
      "name": "denops.vim",
      "repo": "https://github.com/vim-denops/denops.vim",
      "commit": "a278b8342459e4687f24d4d575d72ff593326cee"
    },
    {
      "name": "denops-helloworld",
      "repo": "https://github.com/vim-denops/denops-helloworld.vim",
      "commit": "f975281571191cfd4e3f9e5ba77103932f7dd6e5"
    }
  ]
}
```

### 3. Install plugins

```bash
necromancer install
```

Plugins are installed to:
- **Unix/macOS**: `~/.local/share/nvim/necromancer/plugins/`
- **Windows**: `%LOCALAPPDATA%\nvim\necromancer\plugins\`

### 4. Configure Neovim

Add to your `~/.config/nvim/init.lua`:

```lua
-- Configure Deno path for denops.vim (required for denops-based plugins)
-- Adjust the path based on your Deno installation:
-- - macOS (Homebrew): '/opt/homebrew/bin/deno'
-- - macOS (Intel): '/usr/local/bin/deno'
-- - Linux: '/usr/bin/deno' or '~/.deno/bin/deno'
-- - Windows: 'C:/Users/USERNAME/scoop/shims/deno.exe'
vim.g['denops#deno'] = '/opt/homebrew/bin/deno'

-- Load necromancer plugins
local plugin_dir = vim.fn.expand('~/.local/share/nvim/necromancer/plugins')
for _, plugin in ipairs(vim.fn.readdir(plugin_dir)) do
  vim.opt.runtimepath:append(plugin_dir .. '/' .. plugin)
end

-- Now you can use the plugins
require('telescope').setup{}
require('nvim-treesitter.configs').setup{}
```

**Note**: If you plan to use denops-based plugins (like ddc.vim, ddu.vim, etc.), you must:
1. Install Deno (see Prerequisites)
2. Include `denops.vim` in your plugin configuration
3. Set the correct Deno path in your Neovim config

## Commands

### `necromancer init`

Create a new configuration file with example plugin.

```bash
necromancer init
necromancer init --config /path/to/config.json
necromancer init --force  # Overwrite existing config
```

### `necromancer install`

Install all plugins from configuration file.

```bash
necromancer install
necromancer install --verbose         # Show detailed output
necromancer install --auto-clean      # Remove orphaned plugins after install
necromancer install --config ./custom.json
```

**Exit codes:**
- `0`: Success
- `1`: Configuration error
- `2`: Partial failure (some plugins failed)
- `3`: Fatal error

### `necromancer update`

Update plugins to versions specified in config.

```bash
necromancer update
necromancer update plugin1 plugin2  # Update specific plugins (planned feature)
```

Same exit codes as `install`.

### `necromancer list`

List all plugins and their status.

```bash
necromancer list
```

**Output:**
```
plenary.nvim      [a3e3bc82]  ✓ up-to-date
nvim-treesitter   [0dfbf5e4]  ⚠ outdated (installed: [abc12345])
telescope.nvim    -            ✗ not installed

3 plugins total: 1 up-to-date, 1 outdated, 1 not installed
```

### `necromancer verify`

Verify plugin installations are intact.

```bash
necromancer verify
necromancer verify --fix  # Auto-repair corrupted installations
```

**Exit codes:**
- `0`: All verified
- `2`: Issues found

### `necromancer clean`

Remove plugins no longer in configuration.

```bash
necromancer clean --dry-run  # Show what would be removed
necromancer clean            # Interactive confirmation
necromancer clean --force    # Skip confirmation
```

### `necromancer help`

Show help message.

```bash
necromancer help
necromancer --help
```

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

- **installDir** (optional): Custom installation directory (default: platform-specific)

### Validation rules

- Plugin names must be unique
- GitHub URLs must use HTTPS (not SSH)
- Commit hashes must be exactly 40 hexadecimal characters
- No shell metacharacters allowed in any field

## Lock File

Necromancer maintains a `.necromancer.lock` file (or `lock.json` for global configs) that tracks:

- Installed plugin versions (commit hashes)
- Installation timestamps
- Lock file format version

**Do not edit lock files manually.** They are automatically updated by install/update/clean commands.

## Performance Characteristics

Based on specification requirements:

| Operation | Target Performance |
|-----------|-------------------|
| Install 50 plugins (fresh) | < 2 minutes (~2.4s per plugin) |
| Install 10 plugins (fresh) | < 24 seconds |
| Update 1 plugin | < 3 seconds |
| Config parsing (100 plugins) | < 100ms |
| List command | < 50ms |
| Verify command | < 200ms |

## Constitutional Principles

Necromancer is built on strict design principles:

1. **Zero runtime dependencies**: Only Node.js built-ins
2. **Synchronous-first architecture**: No async/await in core logic
3. **Commit hash versioning only**: No tags or branches
4. **TypeScript strict mode**: Full type safety
5. **Simplicity over abstraction**: Direct implementations

## Troubleshooting

### Plugin not showing in Neovim

1. Verify installation: `necromancer list`
2. Check Neovim runtimepath: `:lua print(vim.inspect(vim.opt.runtimepath:get()))`
3. Verify plugin directory exists: `ls ~/.local/share/nvim/necromancer/plugins/`

### Git clone fails

1. Check network: `ping github.com`
2. Verify git is installed: `git --version`
3. Check repository URL: Try cloning manually with `git clone <url>`
4. Use verbose mode: `necromancer install --verbose`

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
3. Try updating repository: `necromancer verify --fix`

### Corrupted installation

If a plugin installation is corrupted:

```bash
# Detect corruption
necromancer verify

# Auto-repair
necromancer verify --fix
```

Necromancer will re-clone the corrupted plugin at the correct commit.

## Development

### Building from source

```bash
git clone https://github.com/your-username/necromancer
cd necromancer
npm install
npm run build
```

### Running tests

```bash
# All tests
npm test

# Unit tests only
npm run test:unit

# Integration tests only
npm run test:integration

# Watch mode
npm test -- --watch
```

### Project structure

```
necromancer/
├── src/
│   ├── cli/
│   │   ├── commands/      # CLI command implementations
│   │   └── index.ts       # CLI entry point
│   ├── core/              # Core business logic
│   ├── models/            # TypeScript interfaces
│   └── utils/             # Utility functions
├── tests/
│   ├── unit/              # Unit tests
│   └── integration/       # Integration tests
├── dist/                  # Compiled JavaScript (gitignored)
└── package.json
```

## License

MIT

## Contributing

Contributions are welcome! Please ensure:

1. All tests pass: `npm test`
2. TypeScript compiles: `npm run build`
3. Code follows existing patterns (synchronous, no dependencies)
4. New features include tests

## Acknowledgments

Inspired by the need for deterministic, reproducible Neovim plugin management.

---

**Built with simplicity and reliability in mind.**
