# Claude Code Development Guide: Necromancer

**Last Updated**: 2025-10-05
**Project**: Neovim Plugin Manager with Commit-Based Versioning
**Feature**: 001-neovim-typescript-commit

## Project Overview

Necromancer is a TypeScript-based Neovim plugin manager that uses Git commit hashes for deterministic version control. The project emphasizes:
- Zero runtime dependencies (Node.js built-ins only)
- Synchronous operations (no async/await)
- Commit hash-based versioning (no tags or branches)
- Simplicity over abstraction

## Tech Stack

**Language**: TypeScript 5.x (strict mode)
**Runtime**: Node.js 24+
**Module System**: ESM (import/export)
**Testing**: Vitest
**Build**: TypeScript compiler (tsc)

**Dependencies**:
- Runtime: NONE (only Node.js built-ins: fs, child_process, path, crypto)
- Development: TypeScript, Vitest, @types/node

## Constitutional Principles

When developing, ALWAYS adhere to these non-negotiable principles:

### 1. Minimal Dependencies (NON-NEGOTIABLE)
- Use ONLY Node.js built-in modules for runtime code
- Acceptable: fs, child_process, path, crypto, url
- NOT acceptable: external npm packages in dependencies
- Dev dependencies OK: TypeScript, Vitest, type definitions

### 2. Synchronous-First Architecture
- ALL operations MUST be synchronous
- Use execSync, readFileSync, writeFileSync
- NO async/await, Promises, or callbacks
- Exception: Tests may use async for Vitest compatibility

### 3. Commit-Based Versioning (NON-NEGOTIABLE)
- Plugins MUST specify 40-character SHA-1 commit hashes
- NO support for tags, branches, or semantic versions
- Validation: `/^[a-f0-9]{40}$/i`

### 4. TypeScript Foundation
- Enable strict mode: `"strict": true`
- Compile to ES2020+ JavaScript
- No TypeScript runtime dependencies

### 5. Simplicity Over Features
- Prefer direct implementations over abstractions
- No dependency injection, repository patterns, or complex OOP
- Simple functions and data structures

## Project Structure

```
src/
├── core/           # Core business logic
│   ├── config.ts       # Config parsing & validation
│   ├── git.ts         # Git operations (execSync)
│   ├── installer.ts   # Installation orchestration
│   └── validator.ts   # Input validation
├── models/         # TypeScript types & schemas
│   ├── plugin.ts
│   ├── lockfile.ts
│   └── config-file.ts
├── cli/            # CLI interface
│   ├── commands/      # Individual commands
│   └── index.ts      # Entry point
└── utils/          # Utilities
    ├── logger.ts
    ├── paths.ts
    └── errors.ts

tests/
├── unit/          # Unit tests (no I/O)
└── integration/   # Integration tests (local git repos)
```

## Key Design Decisions

### Configuration Format
- File: `.necromancer.json` (project root) or `~/.config/necromancer/config.json`
- Format: JSON (native Node.js parsing)
- Schema: `{ plugins: PluginDefinition[], installDir?: string }`

### Lock File
- File: `.necromancer.lock` (same directory as config)
- Format: JSON
- Purpose: Track installed state for reproducibility

### Plugin Installation Directory
- Unix-like: `~/.local/share/nvim/necromancer/plugins/<plugin-name>/`
- Windows: `%LOCALAPPDATA%\nvim\necromancer\plugins\<plugin-name>\`
- Each plugin in separate directory

### Git Operations Pattern
```typescript
import { execSync } from 'child_process';

function gitClone(url: string, targetPath: string): void {
  try {
    execSync(`git clone "${url}" "${targetPath}"`, {
      encoding: 'utf-8',
      stdio: 'pipe',
      windowsHide: true
    });
  } catch (error) {
    throw new GitError(`Failed to clone ${url}: ${error.message}`);
  }
}
```

### Error Handling
```typescript
class NecromancerError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'NecromancerError';
  }
}

class GitError extends NecromancerError { /* ... */ }
class ValidationError extends NecromancerError { /* ... */ }
```

## Recent Changes

### 2025-10-05: Initial Feature Specification
- Created feature spec with 18 functional requirements
- Defined 7 core entities (PluginDefinition, ConfigFile, InstalledPlugin, etc.)
- Established CLI command contracts (install, update, list, verify, clean, init)
- Resolved 3 clarifications from spec

## Implementation Guidelines

### When Adding a New Feature
1. Check constitutional compliance FIRST
2. Prefer synchronous APIs
3. Avoid external dependencies
4. Write tests before implementation (TDD)
5. Update this file with new patterns

### When Writing Git Operations
- ALWAYS use execSync (never spawn/exec)
- ALWAYS quote paths to prevent injection
- ALWAYS capture stdout/stderr for logging
- ALWAYS validate inputs before execution
- Use `stdio: 'pipe'` to capture output

### When Handling File System
- Use synchronous fs methods (readFileSync, writeFileSync)
- Use path.join() for cross-platform paths
- Expand `~` using path resolution
- Handle ENOENT gracefully with clear error messages

### When Validating Input
- GitHub URLs: `/^https:\/\/github\.com\/[\w-]+\/[\w.-]+(?:\.git)?$/`
- Commit hashes: `/^[a-f0-9]{40}$/i`
- Plugin names: `/^[\w-]{1,100}$/`
- ALWAYS sanitize before passing to execSync

### When Writing Tests
- Unit tests: Mock fs and child_process
- Integration tests: Use local test git repositories (no network)
- Test both success and error paths
- Verify constitutional compliance in tests

## Common Patterns

### Reading Config File
```typescript
function readConfig(configPath: string): ConfigFile {
  const content = readFileSync(configPath, 'utf-8');
  const config = JSON.parse(content) as ConfigFile;
  validateConfig(config);
  return config;
}
```

### Executing Git Commands Safely
```typescript
function safeGitExec(args: string[], cwd?: string): string {
  const command = `git ${args.map(arg => `"${arg}"`).join(' ')}`;
  return execSync(command, {
    cwd,
    encoding: 'utf-8',
    stdio: 'pipe'
  });
}
```

### Path Resolution
```typescript
function resolvePluginPath(name: string): string {
  const baseDir = process.platform === 'win32'
    ? path.join(process.env.LOCALAPPDATA!, 'nvim', 'necromancer', 'plugins')
    : path.join(os.homedir(), '.local', 'share', 'nvim', 'necromancer', 'plugins');
  return path.join(baseDir, name);
}
```

## Testing Strategy

### Unit Tests
- Test individual functions in isolation
- Mock fs, child_process modules
- Focus on validation logic, path resolution, config parsing

### Integration Tests
- Test end-to-end workflows
- Use local test git repositories (fixture repos)
- Verify file system state after operations
- Check lock file updates

### Test Data
- Create fixture repos with known commits
- Use predictable commit hashes for assertions
- Test edge cases: invalid commits, network failures (simulated)

## Performance Targets

From constitution:
- Plugin installation: <30 seconds for typical repositories
- Config parsing: Handle 100+ plugins without noticeable delay
- List command: Near-instant (<50ms)
- Update operation: <5 seconds per plugin

## Common Pitfalls to Avoid

### ❌ DON'T DO THIS
```typescript
// Async operations
async function install() { await ... }

// External dependencies
import axios from 'axios';

// Shell injection vulnerable
execSync(`git clone ${url}`); // Not quoted!

// Complex abstractions
class PluginRepositoryFactory { ... }
```

### ✅ DO THIS
```typescript
// Synchronous operations
function install(): void { ... }

// Node.js built-ins only
import { execSync } from 'child_process';

// Safe command execution
execSync(`git clone "${url}"`);

// Simple functions
function clonePlugin(def: PluginDefinition): void { ... }
```

## Debugging Tips

### Enable Verbose Logging
```bash
necromancer install --verbose
```

### Check Git Operations
```typescript
// Add logging in git.ts
console.error(`[DEBUG] Executing: ${command}`);
const output = execSync(command, ...);
console.error(`[DEBUG] Output: ${output}`);
```

### Verify File System State
```bash
# Check plugin directory
ls -la ~/.local/share/nvim/necromancer/plugins/

# Check lock file
cat .necromancer.lock | jq
```

## Next Steps

See `/specs/001-neovim-typescript-commit/` for:
- `plan.md`: Implementation plan and phases
- `research.md`: Technology decisions and rationale
- `data-model.md`: Entity definitions and validation rules
- `contracts/cli-commands.md`: CLI interface specifications
- `quickstart.md`: User testing scenarios
- `tasks.md`: Implementation task list (created by `/tasks` command)

## Questions or Clarifications

If unclear about implementation details:
1. Check the constitution first (`.specify/memory/constitution.md`)
2. Review research decisions (`specs/001-neovim-typescript-commit/research.md`)
3. Consult data model (`specs/001-neovim-typescript-commit/data-model.md`)
4. When in doubt, prefer simplicity and ask for clarification
