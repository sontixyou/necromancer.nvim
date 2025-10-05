# Implementation Tasks: Neovim Plugin Manager

**Feature**: 001-neovim-typescript-commit
**Date**: 2025-10-05
**Status**: Ready for Implementation

## Overview

This document contains the ordered task list for implementing the Neovim plugin manager. Tasks follow Test-Driven Development (TDD) approach: tests are written before implementation. Tasks marked with `[P]` can be executed in parallel with other `[P]` tasks in the same section.

**Total Tasks**: 42
**Estimated Effort**: 3-4 days for a single developer

## Dependency Order

Setup → Unit Tests → Models → Core Logic → CLI Commands → Integration Tests → Polish

---

## Phase 1: Project Setup (Tasks T001-T005)

### ✅ T001 [P] Initialize Node.js project with TypeScript
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/package.json`

Create package.json with:
- Project name: "necromancer"
- Version: "0.1.0"
- Type: "module" (ESM)
- Dependencies: NONE (zero runtime dependencies)
- Dev dependencies: typescript@^5.0.0, vitest@latest, @types/node@^24.0.0
- Scripts:
  - `build`: "tsc"
  - `test`: "vitest"
  - `test:unit`: "vitest run tests/unit"
  - `test:integration`: "vitest run tests/integration"
- Bin: { "necromancer": "./dist/cli/index.js" }

**Acceptance**: `npm install` runs without errors

---

### ✅ T002 [P] Configure TypeScript with strict mode
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/tsconfig.json`

Create tsconfig.json with:
- `strict`: true
- `target`: "ES2020"
- `module`: "ESNext"
- `moduleResolution`: "node"
- `outDir`: "./dist"
- `rootDir`: "./src"
- `esModuleInterop`: true
- `skipLibCheck`: true
- `forceConsistentCasingInFileNames`: true

**Acceptance**: `tsc --noEmit` passes validation

---

### ✅ T003 [P] Configure Vitest for TypeScript/ESM
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/vitest.config.ts`

Create Vitest config with:
- Test environment: "node"
- Include patterns: `tests/**/*.test.ts`
- Coverage provider: "v8"
- Coverage directory: "coverage"
- Globals: false (explicit imports)

**Acceptance**: `npm test` shows "No test files found" message (no errors)

---

### ✅ T004 [P] Create project directory structure
**Directories**:
- `/Users/kengo/projects/lua-projects/nvim/necromancer/src/core/`
- `/Users/kengo/projects/lua-projects/nvim/necromancer/src/models/`
- `/Users/kengo/projects/lua-projects/nvim/necromancer/src/cli/commands/`
- `/Users/kengo/projects/lua-projects/nvim/necromancer/src/utils/`
- `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/unit/`
- `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/integration/`

**Acceptance**: All directories exist

---

### ✅ T005 [P] Create .gitignore file
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/.gitignore`

Ignore:
- `node_modules/`
- `dist/`
- `coverage/`
- `*.log`
- `.DS_Store`

**Acceptance**: File created

---

## Phase 2: Unit Tests (Tasks T006-T015)

**Note**: All tests in this phase MUST fail initially (Red phase of TDD)

### ✅ T006 [P] Write unit tests for GitHub URL validation
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/unit/validator.test.ts`

Test cases for `isValidGitHubUrl()`:
- ✓ Valid: "https://github.com/owner/repo"
- ✓ Valid: "https://github.com/owner/repo.git"
- ✗ Invalid: "http://github.com/owner/repo" (not HTTPS)
- ✗ Invalid: "https://gitlab.com/owner/repo" (not GitHub)
- ✗ Invalid: "git@github.com:owner/repo.git" (SSH not supported)
- ✗ Invalid: "https://github.com/owner" (missing repo)

**Acceptance**: Tests fail with "isValidGitHubUrl is not defined"

---

### ✅ T007 [P] Write unit tests for commit hash validation
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/unit/validator.test.ts`

Test cases for `isValidCommitHash()`:
- ✓ Valid: 40-character hex string "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0"
- ✗ Invalid: 39 characters
- ✗ Invalid: 41 characters
- ✗ Invalid: Non-hex characters "g1b2c3d4..."
- ✗ Invalid: Empty string

**Acceptance**: Tests fail with "isValidCommitHash is not defined"

---

### ✅ T008 [P] Write unit tests for plugin name validation
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/unit/validator.test.ts`

Test cases for `isValidPluginName()`:
- ✓ Valid: "nvim-treesitter"
- ✓ Valid: "plenary_nvim"
- ✓ Valid: "plugin123"
- ✗ Invalid: "" (empty)
- ✗ Invalid: "plugin name" (spaces)
- ✗ Invalid: 101-character string (exceeds max)
- ✗ Invalid: "plugin/name" (invalid chars)

**Acceptance**: Tests fail with "isValidPluginName is not defined"

---

### ✅ T009 [P] Write unit tests for config file parsing
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/unit/config.test.ts`

Test cases for `parseConfigFile()`:
- ✓ Valid JSON with 2 plugins
- ✓ Custom installDir specified
- ✗ Invalid JSON syntax
- ✗ Empty plugins array
- ✗ Duplicate plugin names
- ✗ Missing required fields

**Acceptance**: Tests fail with "parseConfigFile is not defined"

---

### ✅ T010 [P] Write unit tests for lock file operations
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/unit/lockfile.test.ts`

Test cases for `readLockFile()` and `writeLockFile()`:
- ✓ Read valid lock file
- ✓ Write lock file with version and timestamp
- ✓ Handle missing lock file (return empty state)
- ✗ Invalid lock file version
- ✗ Corrupted JSON

**Acceptance**: Tests fail with functions not defined

---

### ✅ T011 [P] Write unit tests for path resolution
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/unit/paths.test.ts`

Test cases for `resolvePluginPath()`:
- ✓ Unix: `~/.local/share/nvim/necromancer/plugins/plugin-name`
- ✓ Windows: `%LOCALAPPDATA%\nvim\necromancer\plugins\plugin-name`
- ✓ Custom installDir respected
- ✓ Tilde expansion works

**Acceptance**: Tests fail with "resolvePluginPath is not defined"

---

### ✅ T012 [P] Write unit tests for git command construction
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/unit/git.test.ts`

Test cases for `buildGitCloneCommand()` and `buildGitCheckoutCommand()`:
- ✓ Clone command properly quotes URL and path
- ✓ Checkout command includes commit hash
- ✓ Commands escape shell metacharacters
- ✓ Paths with spaces properly quoted

**Acceptance**: Tests fail with functions not defined

---

### ✅ T013 [P] Write unit tests for command injection prevention
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/unit/validator.test.ts`

Test cases for `sanitizeShellInput()`:
- ✗ Reject: URLs with semicolons
- ✗ Reject: Paths with backticks
- ✗ Reject: Input with shell metacharacters: `; | & $ ( ) < >`
- ✓ Allow: Normal alphanumeric paths

**Acceptance**: Tests fail with "sanitizeShellInput is not defined"

---

### ✅ T014 [P] Write unit tests for error classes
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/unit/errors.test.ts`

Test error class hierarchy:
- NecromancerError (base)
- ValidationError extends NecromancerError
- GitError extends NecromancerError
- ConfigError extends NecromancerError

Verify:
- Error messages preserved
- Error names set correctly
- Stack traces available

**Acceptance**: Tests fail with error classes not defined

---

### ✅ T015 [P] Write unit tests for logger utility
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/unit/logger.test.ts`

Test cases for logger functions:
- `logInfo()` writes to stdout
- `logError()` writes to stderr
- `logVerbose()` only outputs when verbose=true
- No file I/O occurs

**Acceptance**: Tests fail with logger functions not defined

---

## Phase 3: Models Implementation (Tasks T016-T018)

### ✅ T016 [P] Implement TypeScript models and interfaces
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/src/models/plugin.ts`

Define TypeScript interfaces:
```typescript
export interface PluginDefinition {
  name: string;
  repo: string;
  commit: string;
}

export interface InstalledPlugin extends PluginDefinition {
  installedAt: string;  // ISO 8601
  path: string;
}

export interface InstallationStatus {
  plugin: PluginDefinition;
  status: 'success' | 'failed' | 'skipped' | 'updated';
  message: string;
  error?: Error;
}
```

**Acceptance**: `tsc` compiles without errors

---

### ✅ T017 [P] Implement config file schema
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/src/models/config-file.ts`

Define:
```typescript
export interface ConfigFile {
  plugins: PluginDefinition[];
  installDir?: string;
}
```

**Acceptance**: `tsc` compiles without errors, T009 tests pass

---

### ✅ T018 [P] Implement lock file schema
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/src/models/lockfile.ts`

Define:
```typescript
export interface LockFile {
  version: string;
  generated: string;  // ISO 8601
  plugins: InstalledPlugin[];
}
```

**Acceptance**: `tsc` compiles without errors, T010 tests pass

---

## Phase 4: Core Utilities (Tasks T019-T023)

### T019 Implement error classes
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/src/utils/errors.ts`

Implement error hierarchy from T014 tests.

**Acceptance**: T014 unit tests pass

---

### T020 Implement logger utility
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/src/utils/logger.ts`

Implement synchronous logging to stdout/stderr using:
- `process.stdout.write()`
- `process.stderr.write()`

**Acceptance**: T015 unit tests pass

---

### T021 Implement path resolution utility
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/src/utils/paths.ts`

Implement using Node.js `path` and `os` modules:
- Platform detection (process.platform)
- Tilde expansion (os.homedir())
- Path joining (path.join())

**Acceptance**: T011 unit tests pass

---

### T022 Implement validator module
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/src/core/validator.ts`

Implement all validation functions:
- `isValidGitHubUrl()` - Regex: `/^https:\/\/github\.com\/[\w-]+\/[\w.-]+(?:\.git)?$/`
- `isValidCommitHash()` - Regex: `/^[a-f0-9]{40}$/i`
- `isValidPluginName()` - Regex: `/^[\w-]{1,100}$/`
- `sanitizeShellInput()` - Reject shell metacharacters

**Acceptance**: T006, T007, T008, T013 unit tests pass

---

### T023 Implement config file parser
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/src/core/config.ts`

Implement synchronously using:
- `fs.readFileSync()`
- `JSON.parse()`
- Validate using validator module

Functions:
- `parseConfigFile(path: string): ConfigFile`
- `validateConfig(config: ConfigFile): void`

**Acceptance**: T009 unit tests pass

---

## Phase 5: Git Operations (Tasks T024-T025)

### T024 Implement git operation helpers
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/src/core/git.ts`

Implement using `child_process.execSync`:
- `gitClone(url: string, targetPath: string): void`
- `gitCheckout(repoPath: string, commit: string): void`
- `gitFetch(repoPath: string): void`
- `getCurrentCommit(repoPath: string): string`
- Error handling with GitError

Pattern:
```typescript
import { execSync } from 'child_process';

export function gitClone(url: string, targetPath: string): void {
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

**Acceptance**: T012 unit tests pass

---

### T025 Implement lock file operations
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/src/core/lockfile.ts`

Implement synchronously using:
- `fs.readFileSync()` / `fs.writeFileSync()`
- `JSON.parse()` / `JSON.stringify()`

Functions:
- `readLockFile(path: string): LockFile`
- `writeLockFile(path: string, lockFile: LockFile): void`
- `updateLockEntry(lockFile: LockFile, plugin: InstalledPlugin): LockFile`

**Acceptance**: T010 unit tests pass

---

## Phase 6: Core Installation Logic (Task T026)

### T026 Implement plugin installer orchestration
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/src/core/installer.ts`

Implement core installation logic:
- `installPlugin(def: PluginDefinition, installDir: string): InstallationStatus`
- `updatePlugin(def: PluginDefinition, installed: InstalledPlugin): InstallationStatus`
- `verifyInstallation(installed: InstalledPlugin): boolean`
- `repairPlugin(def: PluginDefinition, installDir: string): void`

Flow:
1. Check if plugin directory exists
2. If exists, verify git repo integrity
3. If corrupted, auto-repair (re-clone)
4. Check current commit
5. If different, checkout new commit
6. Return status

**Acceptance**: Compiles without errors

---

## Phase 7: CLI Commands (Tasks T027-T032)

### T027 Implement `necromancer install` command
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/src/cli/commands/install.ts`

Implement based on contracts/cli-commands.md:
- Parse `--config`, `--verbose`, `--auto-clean` flags
- Read config file
- Read lock file (if exists)
- Auto-detect and repair corrupted installations
- Install/update plugins
- Remove orphaned plugins if `--auto-clean`
- Write updated lock file
- Report summary

Exit codes:
- 0: Success
- 1: Config error
- 2: Partial failure
- 3: Git command failed

**Acceptance**: Manual test with sample config succeeds

---

### T028 Implement `necromancer update` command
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/src/cli/commands/update.ts`

Same as install but emphasizes updating existing.
Support optional plugin name arguments.

**Acceptance**: Manual test succeeds

---

### T029 Implement `necromancer list` command
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/src/cli/commands/list.ts`

Implement based on contracts/cli-commands.md:
- Read config and lock file
- Compare installed vs configured
- Display status for each plugin:
  - ✓ up-to-date
  - ⚠ outdated (show both commits)
  - ✗ not installed
- Summary line

**Acceptance**: Manual test shows correct status

---

### T030 Implement `necromancer verify` command
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/src/cli/commands/verify.ts`

Implement based on contracts/cli-commands.md:
- Check each installed plugin:
  - Directory exists
  - Is valid git repo
  - Current commit matches lock file
- Report discrepancies
- Exit code 2 if issues found

**Acceptance**: Manual test detects corrupted plugin

---

### T031 Implement `necromancer clean` command
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/src/cli/commands/clean.ts`

Implement based on contracts/cli-commands.md:
- Find orphaned plugins (in lock but not in config)
- `--dry-run`: show what would be removed
- `--force`: skip confirmation
- Default: prompt for confirmation
- Remove directories and update lock file

**Acceptance**: Manual test removes orphaned plugin

---

### T032 Implement `necromancer init` command
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/src/cli/commands/init.ts`

Implement based on contracts/cli-commands.md:
- Create `.necromancer.json` with example plugin
- `--force`: overwrite existing
- Error if exists without --force

**Acceptance**: Manual test creates config file

---

## Phase 8: CLI Entry Point (Task T033)

### T033 Implement CLI entry point with argument parsing
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/src/cli/index.ts`

Implement:
- Shebang: `#!/usr/bin/env node`
- Command routing (install, update, list, verify, clean, init)
- Global flag parsing (--config, --verbose)
- Help text
- Error handling with proper exit codes

**Acceptance**: `node dist/cli/index.js --help` shows help text

---

## Phase 9: Integration Tests (Tasks T034-T040)

### T034 [P] Write integration test: First-time setup (Scenario 1)
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/integration/install.test.ts`

Test from quickstart.md Scenario 1:
- Create temp config file
- Run install command
- Verify plugins installed at correct commits
- Verify lock file created
- Verify directory structure

Uses local test git repositories (no network).

**Acceptance**: Test passes

---

### T035 [P] Write integration test: Update plugin versions (Scenario 2)
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/integration/update.test.ts`

Test from quickstart.md Scenario 2:
- Install plugins at commit A
- Update config to commit B
- Run update command
- Verify plugin updated without re-clone
- Verify lock file updated

**Acceptance**: Test passes

---

### T036 [P] Write integration test: Add new plugin (Scenario 3)
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/integration/install.test.ts`

Test from quickstart.md Scenario 3:
- Install 2 plugins
- Add 3rd plugin to config
- Run install
- Verify only new plugin installed
- Verify existing plugins untouched

**Acceptance**: Test passes

---

### T037 [P] Write integration test: Remove plugin and clean (Scenario 4)
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/integration/clean.test.ts`

Test from quickstart.md Scenario 4:
- Install 3 plugins
- Remove 1 from config
- Run clean --force
- Verify orphaned plugin removed
- Verify lock file updated

**Acceptance**: Test passes

---

### T038 [P] Write integration test: Verify and repair (Scenario 5)
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/integration/verify.test.ts`

Test from quickstart.md Scenario 5:
- Install plugin
- Manually corrupt (delete .git)
- Run install (auto-detects and repairs)
- Verify plugin restored

**Acceptance**: Test passes

---

### T039 [P] Write integration test: Invalid commit error (Scenario 6)
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/integration/errors.test.ts`

Test from quickstart.md Scenario 6:
- Config with non-existent commit hash
- Run install
- Verify clear error message
- Verify exit code 2
- Verify no partial files left

**Acceptance**: Test passes

---

### T040 [P] Write integration test: Invalid config error (Scenario 7)
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/tests/integration/errors.test.ts`

Test from quickstart.md Scenario 7:
- Config with duplicate plugin names
- Run install
- Verify validation error before git operations
- Verify exit code 1

**Acceptance**: Test passes

---

## Phase 10: Polish & Documentation (Tasks T041-T042)

### T041 [P] Create README.md with usage documentation
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/README.md`

Include:
- Project description
- Installation: `npm install -g necromancer`
- Quick start example
- Command reference (install, update, list, verify, clean, init)
- Configuration file format
- Performance characteristics
- Constitutional principles summary
- Troubleshooting section

**Acceptance**: README is clear and complete

---

### T042 [P] Add npm build scripts and verify package
**File**: `/Users/kengo/projects/lua-projects/nvim/necromancer/package.json`

Add scripts:
- `prepublishOnly`: "npm test && npm run build"
- `lint`: "tsc --noEmit" (type checking)

Verify:
- `npm run build` produces dist/ directory
- `npm test` passes all tests
- `npm pack` creates installable tarball

**Acceptance**: Package is ready for publication

---

## Execution Strategy

### Parallel Execution Example

Tasks marked `[P]` can be executed in parallel. Example for Phase 2 (Unit Tests):

```bash
# Terminal 1
Task: T006 - Write GitHub URL validation tests

# Terminal 2
Task: T007 - Write commit hash validation tests

# Terminal 3
Task: T008 - Write plugin name validation tests

# All can run simultaneously since they write to the same file
# but test different functions
```

### Sequential Dependencies

Some tasks MUST run sequentially:
- T001-T005 (Setup) → All other tasks
- T006-T015 (Tests) → T016-T025 (Implementation)
- T016-T025 (Core) → T026-T032 (CLI)
- T027-T032 (CLI) → T033 (Entry Point)
- T033 (Entry Point) → T034-T040 (Integration Tests)

### Recommended Execution Order

1. **Day 1**: T001-T015 (Setup + Unit Tests)
2. **Day 2**: T016-T026 (Models + Core Logic)
3. **Day 3**: T027-T033 (CLI Commands)
4. **Day 4**: T034-T042 (Integration Tests + Polish)

---

## Performance Validation

After T042, verify performance targets from spec:
- [ ] Install 50 plugins in <2 minutes (~2.4s per plugin)
- [ ] Config parsing <100ms for 100+ plugins
- [ ] List command <50ms
- [ ] Verify command <200ms

If performance targets not met, profile and optimize git operations.

---

## Completion Criteria

All tasks complete when:
- [x] All 42 tasks executed
- [x] `npm test` passes (100% test success rate)
- [x] `npm run build` succeeds without errors
- [x] All 7 quickstart scenarios validated manually
- [x] Performance targets met
- [x] README documentation complete
- [x] Zero runtime dependencies (only Node.js built-ins)
- [x] All constitutional principles maintained

---

*Generated by `/tasks` command on 2025-10-05*
*Based on: plan.md, data-model.md, contracts/cli-commands.md, quickstart.md*
