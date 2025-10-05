# Research: Neovim Plugin Manager

**Date**: 2025-10-05
**Feature**: 001-neovim-typescript-commit

## 1. Node.js 24+ Features

**Decision**: Use Node.js 24 LTS with native ESM, modern file system APIs, and enhanced crypto module

**Rationale**:
- Node.js 24 provides stable ESM support without experimental flags
- `fs` module has synchronous variants for all operations needed
- `crypto` module includes built-in hash validation utilities
- Better error messages and stack traces for debugging

**Alternatives Considered**:
- Node.js 18 LTS: More widely adopted but lacks some modern features
- Node.js 22: Not LTS, less stable for production use

## 2. Vitest Configuration

**Decision**: Use Vitest with TypeScript, ESM mode, and in-source testing disabled

**Rationale**:
- Native TypeScript support without additional setup
- Fast execution with Vite's transformation pipeline
- Compatible with ESM module system
- Good mocking capabilities for file system and child_process

**Configuration**:
```typescript
// vitest.config.ts
export default {
  test: {
    globals: false,  // Explicit imports for better IDE support
    environment: 'node',
    include: ['tests/**/*.test.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html'],
      exclude: ['tests/**', 'dist/**']
    }
  }
}
```

**Alternatives Considered**:
- Node.js native test runner: Minimal but lacks ecosystem maturity
- Jest: Heavy dependencies, slower with TypeScript
- uvu/tape: Lightweight but less feature-complete

## 3. Git Command Patterns

**Decision**: Use `execSync` with explicit error handling and output capture

**Pattern**:
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

**Rationale**:
- `stdio: 'pipe'` captures output for logging
- `windowsHide: true` prevents console flashing on Windows
- Quoting paths prevents injection and handles spaces
- Synchronous execution aligns with constitutional requirement

**Alternatives Considered**:
- Using git library (e.g., isomorphic-git): Violates minimal dependencies principle
- spawn/spawnSync: More complex API for no benefit in synchronous use case

## 4. Configuration File Format

**Decision**: JSON format with `.necromancer.json` filename in project root or `~/.config/necromancer/config.json`

**Schema**:
```json
{
  "plugins": [
    {
      "name": "plugin-name",
      "repo": "https://github.com/owner/repo",
      "commit": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0"
    }
  ],
  "installDir": "~/.local/share/nvim/necromancer/plugins"
}
```

**Rationale**:
- JSON is built-in to Node.js (no parser dependency)
- Standard format familiar to developers
- TypeScript provides excellent type checking for JSON
- Easy to validate and parse

**Alternatives Considered**:
- TOML: Requires external parser (violates minimal dependencies)
- YAML: Requires external parser, more complex
- Custom format: Unnecessary complexity

## 5. Lock File Format

**Decision**: JSON format with `.necromancer.lock` filename

**Schema**:
```json
{
  "version": "1",
  "generated": "2025-10-05T12:00:00Z",
  "plugins": [
    {
      "name": "plugin-name",
      "repo": "https://github.com/owner/repo",
      "commit": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0",
      "installedAt": "2025-10-05T12:00:00Z",
      "path": "~/.local/share/nvim/necromancer/plugins/plugin-name"
    }
  ]
}
```

**Rationale**:
- Matches industry standards (package-lock.json, yarn.lock concept)
- Records installation timestamp for debugging
- Stores actual installed paths for verification
- Version field allows future format migrations

**Alternatives Considered**:
- Binary format: Harder to debug and inspect
- Same file as config: Mixes user intent with system state

## 6. Neovim Plugin Directory Standards

**Decision**: `~/.local/share/nvim/necromancer/plugins/<plugin-name>`

**Rationale**:
- Follows XDG Base Directory specification
- Separates necromancer plugins from other package managers
- Per-plugin directory allows easy removal and isolation
- Standard location across Unix-like systems

**Windows Path**: `%LOCALAPPDATA%\nvim\necromancer\plugins\<plugin-name>`

**Alternatives Considered**:
- `~/.config/nvim/necromancer/`: Config directory should not contain code
- `~/.nvim/necromancer/`: Non-standard, clutters home directory
- `/opt/necromancer/`: Requires root permissions

## 7. GitHub URL Validation

**Decision**: Regex validation for `https://github.com/owner/repo` format (with optional `.git` suffix)

**Pattern**:
```typescript
const GITHUB_URL_REGEX = /^https:\/\/github\.com\/[\w-]+\/[\w.-]+(?:\.git)?$/;

function validateGitHubUrl(url: string): boolean {
  return GITHUB_URL_REGEX.test(url);
}
```

**Rationale**:
- Only GitHub.com repositories supported (per requirement)
- Prevents arbitrary git URLs
- Allows optional .git suffix (common in git URLs)
- Validates owner and repo name formats

**Alternatives Considered**:
- URL parsing: More complex, allows non-GitHub hosts
- Git protocol URLs: Not supported by requirement
- SSH URLs: Authentication complexity not needed

## 8. Commit Hash Validation

**Decision**: Regex validation for 40-character hex strings (SHA-1 format)

**Pattern**:
```typescript
const COMMIT_HASH_REGEX = /^[a-f0-9]{40}$/;

function validateCommitHash(hash: string): boolean {
  return COMMIT_HASH_REGEX.test(hash.toLowerCase());
}
```

**Rationale**:
- SHA-1 is Git's standard hash format (40 hex characters)
- Case-insensitive comparison (Git accepts both)
- Prevents short hashes or invalid characters
- Future-proof: SHA-256 migration can be added later if needed

**Alternatives Considered**:
- Allow short hashes: Not deterministic enough
- SHA-256 support: Git doesn't use SHA-256 widely yet
- Tag/branch support: Violates commit-only requirement

## 9. Error Handling Strategy

**Decision**: Custom error classes with synchronous throw/catch patterns

**Implementation**:
```typescript
class NecromancerError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'NecromancerError';
  }
}

class GitError extends NecromancerError {
  constructor(message: string, public command?: string) {
    super(message);
    this.name = 'GitError';
  }
}

class ValidationError extends NecromancerError {
  constructor(message: string, public field?: string) {
    super(message);
    this.name = 'ValidationError';
  }
}
```

**Rationale**:
- Type-safe error handling with instanceof checks
- Preserves stack traces
- Additional context via custom fields
- Standard JavaScript pattern

**Alternatives Considered**:
- Result types (Rust-style): More complex, not idiomatic JavaScript
- Error codes: Less type-safe
- Throwing strings: No stack trace, not extendable

## 10. Input Sanitization for Command Injection

**Decision**: Whitelist validation + parameter quoting + no shell mode

**Pattern**:
```typescript
function sanitizePath(input: string): string {
  // Validate path doesn't contain shell metacharacters
  if (/[;&|`$()]/.test(input)) {
    throw new ValidationError('Invalid characters in path');
  }
  return input;
}

function executeGit(args: string[], cwd?: string): string {
  // Use array form with explicit git binary
  const cmd = ['git', ...args].map(arg => `"${arg}"`).join(' ');
  return execSync(cmd, {
    cwd,
    encoding: 'utf-8',
    shell: '/bin/sh'  // Explicit shell, not user's shell
  });
}
```

**Rationale**:
- Explicit quoting prevents path-based injection
- Shell metacharacter detection catches obvious attacks
- Using known shell path prevents environment manipulation
- Validation happens before execution

**Alternatives Considered**:
- Escaping only: Incomplete, error-prone
- No shell mode: Some git commands need shell features
- Blacklist approach: Easy to bypass, incomplete

## Clarification Resolutions

### FR-009: Plugin Removal Behavior
**Decision**: Plugins removed from config require manual cleanup via `necromancer clean` command

**Rationale**:
- Safer: Prevents accidental data loss
- Users may temporarily remove plugins for testing
- Explicit cleanup command provides control
- Aligns with "Simplicity Over Features" principle

### FR-017: Corrupted Installation Detection
**Decision**: Manual trigger via `necromancer verify` command

**Rationale**:
- Automatic detection adds complexity
- Users explicitly request verification when needed
- Clear separation of concerns (install vs verify)
- Performance: No automatic checks on every operation

### FR-018: Logging Configuration
**Decision**: Simple stdout/stderr logging with optional `--verbose` flag, no log files initially

**Rationale**:
- Simplicity: No log file management needed
- Standard Unix pattern (stdout for info, stderr for errors)
- Verbose flag for debugging (prints git commands and output)
- Can add file logging later if needed

## Technology Stack Summary

| Component | Choice | Type |
|-----------|--------|------|
| Runtime | Node.js 24+ | Required |
| Language | TypeScript 5.x | Required |
| Module System | ESM | Required |
| Testing | Vitest | Dev Dependency |
| Config Format | JSON | Built-in |
| Git Interface | execSync | Built-in |
| File System | fs (sync) | Built-in |
| Path Handling | path | Built-in |
| Hashing | crypto | Built-in |

**Total Runtime Dependencies**: 0
**Dev Dependencies**: TypeScript, Vitest, @types/node

