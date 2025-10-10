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

# Type checking (no emit)
npm run lint

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

# Run tests matching a pattern (e.g., all files with "install")
npm test -- install

# Run a specific test within a file (by test name)
npm test -- -t "validates GitHub URLs"

# Run tests with coverage
npm test -- --coverage

# Run tests in UI mode (interactive)
npm test -- --ui
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

**ESM Module Requirements (CRITICAL)**
- All imports MUST use `.js` extensions in import paths (even for `.ts` source files)
- Example: `import { foo } from '../../src/core/validator.js'` (NOT `.ts`)
- This is required for proper ESM module resolution at runtime with TypeScript
- Forgetting this will cause runtime errors despite TypeScript compiling successfully

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
- `dependencies.ts`: Plugin dependency resolution and topological sorting

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

### Plugin Dependencies Architecture

**Dependency Resolution**
- Plugins can specify dependencies on other plugins in the config via the `dependencies` field
- Dependencies are resolved using **topological sorting** (Kahn's algorithm) to determine installation order
- Implementation: `src/core/dependencies.ts:11` - `resolveDependencies()` function

**Dependency Validation Rules**
1. All dependencies must reference existing plugins in the configuration
2. Circular dependencies are detected and rejected with ValidationError
3. Transitive dependencies are handled automatically
4. Missing dependencies cause immediate validation failure

**Example Dependency Graph**
```json
{
  "plugins": [
    { "name": "plenary.nvim", ... },
    { "name": "telescope.nvim", "dependencies": ["plenary.nvim"], ... },
    { "name": "telescope-ui-select.nvim", "dependencies": ["telescope.nvim"], ... }
  ]
}
```
Installation order: `plenary.nvim` → `telescope.nvim` → `telescope-ui-select.nvim`

**Key Implementation Details**
- Uses in-degree counting for each plugin (how many dependencies point to it)
- Plugins with zero in-degree (no dependents) are processed first
- Gradually removes edges and processes plugins as their dependencies are satisfied
- If not all plugins are processed, a circular dependency exists

## Testing Strategy

**Vitest Configuration** (vitest.config.ts)
- **Globals disabled** - always use explicit imports: `import { describe, it, expect } from 'vitest'`
- **ESM modules** - import from `.js` extensions even though source is `.ts` (TypeScript ESM requirement)
- **Test timeout**: 10 seconds (suitable for git operations in integration tests)
- **Coverage**: v8 provider with text/json/html reports (coverage in `./coverage`)
- **Test pattern**: `tests/**/*.test.ts`
- **Coverage includes**: `src/**/*.ts` (excludes test files and dist/)

**Unit Tests** (tests/unit/)
- Mock fs and child_process modules using Vitest's mock functions
- Test validation logic, path resolution, config parsing
- No I/O operations - purely synchronous logic testing
- Example: `tests/unit/validator.test.ts` validates regex patterns

**Integration Tests** (tests/integration/)
- Create local test git repositories (no network) using `execSync` in `beforeEach`
- Use `mkdtempSync` for isolated temporary directories per test
- Verify file system state after operations
- Test end-to-end workflows with real git operations
- Example: `tests/integration/install.test.ts` creates a local repo with known commits

**Test Data Setup Pattern**
```typescript
beforeEach(() => {
  testDir = mkdtempSync(join(tmpdir(), 'necromancer-test-'));
  testRepoPath = join(testDir, 'test-repo');

  // Create local git repo
  mkdirSync(testRepoPath);
  execSync('git init', { cwd: testRepoPath, stdio: 'pipe' });
  execSync('git config user.email "test@test.com"', { cwd: testRepoPath });

  // Create commits and capture hashes
  writeFileSync(join(testRepoPath, 'file.txt'), 'content');
  execSync('git add .', { cwd: testRepoPath, stdio: 'pipe' });
  execSync('git commit -m "commit"', { cwd: testRepoPath, stdio: 'pipe' });
  commit = execSync('git rev-parse HEAD', { cwd: testRepoPath, encoding: 'utf-8' }).trim();
});

afterEach(() => {
  rmSync(testDir, { recursive: true, force: true });
});
```

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
- `module: "ESNext"` (enables ES modules)
- `moduleResolution: "node"`
- `noUncheckedIndexedAccess: true` (array access returns `T | undefined`)
- `noUnusedLocals: true` / `noUnusedParameters: true`
- `noImplicitReturns: true`
- `noFallthroughCasesInSwitch: true`
- `sourceMap: false` (no source maps for smaller dist size)
- `declaration: true` (type definitions for consumers)
- `declarationMap: false` (no declaration maps for smaller dist size)

**Distribution Package**:
- Published files (package.json `files` field): `dist/`, `README.md`, `LICENSE`
- Typical dist size: ~168KB (JavaScript + type definitions, no source maps)
- Source maps disabled to reduce package size by ~47%

## File References Format

When referencing code locations, use the pattern: `file_path:line_number`

Example: "Plugin validation happens in `src/core/validator.ts:42`"
