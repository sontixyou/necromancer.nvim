# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Necromancer is a TypeScript-based Neovim plugin manager that uses Git commit hashes (not tags/branches) for deterministic version control. The project follows strict constitutional principles:

- **Zero runtime dependencies** - Only Node.js built-ins (fs, child_process, path, crypto)
- **Synchronous-only architecture** - No async/await, Promises, or callbacks
- **Commit hash versioning** - 40-character SHA-1 hashes only (validated: `/^[a-f0-9]{40}$/i`)
- **TypeScript strict mode** - Compiles to ES2020+ JavaScript
- **Simplicity over abstraction** - Direct implementations, no DI/OOP patterns

## Development Commands

### Build & Test
```bash
# Build TypeScript to JavaScript
npm run build

# Run all tests (unit + integration)
npm test

# Run only unit tests
npm run test:unit

# Run only integration tests
npm run test:integration

# Run tests in watch mode
npm test -- --watch

# Run specific test file
npm test -- tests/unit/validator.test.ts
```

### Running the CLI (Development)
```bash
# After building
node dist/cli/index.js <command>

# Example: install plugins
node dist/cli/index.js install

# With verbose logging
node dist/cli/index.js install --verbose
```

## Architecture

### Core Design Principles

**Synchronous Execution Flow**
- All operations use sync APIs: `execSync`, `readFileSync`, `writeFileSync`
- No Promises or async/await (except in test helpers for Vitest compatibility)
- Git operations execute sequentially with `execSync`

**Data Flow**
```
Config File (.necromancer.json)
  → Validation (validator.ts)
    → Installation (installer.ts)
      → Git Operations (git.ts)
        → Lock File Update (.necromancer.lock)
```

**Git Command Safety Pattern**
All git commands MUST:
1. Quote paths to prevent injection
2. Use `stdio: 'pipe'` to capture output
3. Validate inputs before execution
4. Handle errors with custom error types (GitError, ValidationError)

Example:
```typescript
execSync(`git clone "${url}" "${targetPath}"`, {
  encoding: 'utf-8',
  stdio: 'pipe',
  windowsHide: true
});
```

### Module Organization

**src/models/** - Pure TypeScript types and data structures
- `plugin.ts`: PluginDefinition, InstalledPlugin, InstallationStatus
- `config-file.ts`: ConfigFile schema and default paths
- `lockfile.ts`: LockFile schema and version management

**src/core/** - Core business logic (all synchronous)
- `config.ts`: Config parsing and validation
- `git.ts`: Git operations via execSync
- `installer.ts`: Installation orchestration
- `validator.ts`: Input validation and sanitization

**src/cli/** - CLI interface
- `cli/commands/`: Individual command handlers
- `cli/index.ts`: Entry point and argument parsing

**src/utils/** - Cross-cutting utilities
- `logger.ts`: Logging to stdout/stderr
- `paths.ts`: Cross-platform path resolution
- `errors.ts`: Custom error types

### Key Patterns

**Config File Location**
1. Project root: `.necromancer.json`
2. Global fallback: `~/.config/necromancer/config.json`

**Plugin Installation Directory**
- Unix: `~/.local/share/nvim/necromancer/plugins/<plugin-name>/`
- Windows: `%LOCALAPPDATA%\nvim\necromancer\plugins\<plugin-name>\`

**Lock File Management**
- Stored alongside config file
- JSON format with version tracking
- Updated atomically after successful installations

**Input Validation Regexes**
- GitHub URLs: `/^https:\/\/github\.com\/[\w-]+\/[\w.-]+(?:\.git)?$/`
- Commit hashes: `/^[a-f0-9]{40}$/i`
- Plugin names: `/^[\w-]{1,100}$/`

## Testing Strategy

**Unit Tests** (tests/unit/)
- Mock fs and child_process modules
- Test validation logic, path resolution, config parsing
- No I/O operations

**Integration Tests** (tests/integration/)
- Use local test git repositories (no network)
- Verify file system state after operations
- Test end-to-end workflows

**Test Data Setup**
- Create fixture repos with known commits
- Use predictable commit hashes for assertions
- Simulate edge cases (invalid commits, corrupted repos)

## Common Development Scenarios

### Adding a New Validation Rule
1. Add test in `tests/unit/validator.test.ts`
2. Implement in `src/core/validator.ts`
3. Update relevant types in `src/models/`

### Adding a New CLI Command
1. Define contract in `specs/001-neovim-typescript-commit/contracts/cli-commands.md`
2. Create test in `tests/integration/<command>.test.ts`
3. Implement in `src/cli/commands/<command>.ts`
4. Register in `src/cli/index.ts`

### Modifying Git Operations
1. **Always** validate inputs before passing to execSync
2. **Always** quote paths and URLs
3. **Always** handle errors with specific error types
4. Test with local repos (no network calls)

## Performance Targets

- Plugin installation: <30 seconds for typical repos
- Config parsing: <100ms for 100+ plugins
- List command: <50ms
- Update operation: <5 seconds per plugin

## Constitutional Violations to Avoid

❌ **Don't:**
```typescript
// Async operations
async function install() { await ... }

// External dependencies
import axios from 'axios';

// Unquoted shell commands (injection risk)
execSync(`git clone ${url}`);

// Complex abstractions
class PluginRepositoryFactory { ... }
```

✅ **Do:**
```typescript
// Synchronous operations
function install(): void { ... }

// Built-ins only
import { execSync } from 'child_process';

// Safe command execution
execSync(`git clone "${url}"`);

// Simple functions
function clonePlugin(def: PluginDefinition): void { ... }
```

## Project Documentation

For detailed specifications, see `specs/001-neovim-typescript-commit/`:
- `plan.md`: Implementation phases and architecture decisions
- `research.md`: Technology choices and rationale
- `data-model.md`: Entity definitions and validation rules
- `contracts/cli-commands.md`: CLI interface specifications
- `quickstart.md`: User testing scenarios
- `.specify/memory/constitution.md`: Constitutional principles (non-negotiable)

## TypeScript Configuration

Key compiler options (tsconfig.json):
- `strict: true` (all strict checks enabled)
- `target: "ES2020"`
- `module: "ESNext"`
- `noUncheckedIndexedAccess: true`
- `moduleResolution: "node"`

## File References Format

When referencing code locations, use the pattern: `file_path:line_number`

Example: "Plugin validation happens in `src/core/validator.ts:42`"
