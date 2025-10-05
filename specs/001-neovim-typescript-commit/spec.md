# Feature Specification: Neovim Plugin Manager with Commit-Based Versioning

**Feature Branch**: `001-neovim-typescript-commit`
**Created**: 2025-10-05
**Status**: Draft
**Input**: User description: "neovimn�鰤��������\�_DgY
  ^o�
  gM�`Q�����n�X�jOW_D
  Typescriptg\�_D
  �鰤�n������LD_Dcommit hashgn�gM��FkW_D"

## User Scenarios & Testing

### Primary User Story
A Neovim user wants to manage their editor plugins in a reproducible, deterministic way. They define a configuration file listing plugins with specific Git commit hashes, run a single command to install or update plugins, and expect all plugins to be checked out at exactly the specified commits. The process should be simple, transparent, and not rely on external package registries or complex dependency resolution.

### Acceptance Scenarios
1. **Given** a fresh installation with no plugins, **When** the user runs the install command with a configuration file, **Then** all specified plugins are cloned and checked out at their exact commit hashes
2. **Given** an existing installation with plugins at older commits, **When** the user updates commit hashes in the configuration and runs the update command, **Then** plugins are updated to the new commit hashes without re-cloning
3. **Given** a configuration file with 50 plugins, **When** the user runs the install command, **Then** all plugins install successfully within 2 minutes and a lock file records the installed state
4. **Given** a plugin repository that has moved or is unavailable, **When** the user runs the install command, **Then** the system reports a clear error message identifying the problematic plugin
5. **Given** a user on a different machine with the same configuration file, **When** they run the install command, **Then** they get identical plugin installations (same commits, same directory structure)

### Edge Cases
- What happens when a specified commit hash doesn't exist in the repository?
- How does the system handle network failures during git clone operations?
- What happens when a plugin's git repository requires authentication? (System fails with clear error; only public HTTPS repos supported)
- How does the system handle partial installations (some plugins installed, others failed)?
- What happens when a user manually modifies installed plugin files? (System automatically detects and repairs corruption during install/update)
- How does the system handle plugins that are already installed but at different commits? (System updates them to match configuration)

## Clarifications

### Session 2025-10-05
- Q: What is the maximum acceptable total time for installing 50 fresh plugins? → A: < 2 minutes total (aggressive - ~2.4s per plugin avg)
- Q: How should plugin removal work for plugins no longer in configuration? → A: Automatic with `--auto-clean` flag, otherwise skip orphaned plugins
- Q: When should corruption detection and repair occur? → A: Automatic detection on every install/update; auto-repair without prompt
- Q: What logging behavior is required for git operations? → A: Log to stdout/stderr only; use `--verbose` flag for detailed output
- Q: How should the system handle repositories requiring authentication? → A: Support only public HTTPS repos; fail with clear error for auth-required repos

## Requirements

### Functional Requirements
- **FR-001**: System MUST read plugin definitions from a declarative configuration file
- **FR-002**: System MUST validate that each plugin specifies a full 40-character Git commit hash
- **FR-003**: System MUST clone plugin repositories from public HTTPS Git URLs only; repositories requiring authentication MUST fail with a clear error message
- **FR-004**: System MUST checkout plugins to their exact specified commit hashes
- **FR-005**: System MUST install plugins to a predictable directory structure
- **FR-006**: System MUST generate a lock file recording successfully installed plugins and their commit hashes
- **FR-007**: System MUST detect when a plugin is already installed at the correct commit and skip re-installation
- **FR-008**: System MUST update plugins when commit hashes change in the configuration
- **FR-009**: System MUST support removal of orphaned plugins (plugins in lock file but not in configuration) via `--auto-clean` flag; by default orphaned plugins are skipped without deletion
- **FR-010**: System MUST report clear error messages for failures (network errors, invalid commits, git command failures)
- **FR-011**: System MUST validate configuration file format before attempting installations
- **FR-012**: System MUST complete all operations synchronously (no async/await or promises)
- **FR-013**: System MUST handle git operations using only Node.js built-in modules (child_process)
- **FR-014**: System MUST sanitize user input before executing shell commands to prevent injection attacks
- **FR-015**: Users MUST be able to list currently installed plugins and their commits
- **FR-016**: Users MUST be able to verify installation integrity (check if installed commits match configuration)
- **FR-017**: System MUST automatically detect corrupted plugin installations during install/update operations and repair them without user confirmation
- **FR-018**: System MUST log git operations to stdout/stderr; detailed git command output MUST be available via `--verbose` flag (no persistent log files)

### Out of Scope
- SSH protocol support (git@github.com URLs)
- Private repository access via credentials or tokens
- Git protocols other than HTTPS (git://, file://)
- Authentication credential management

### Non-Functional Requirements

#### Performance
- **NFR-001**: System MUST install 50 fresh plugins in under 2 minutes total (average ~2.4 seconds per plugin)
- **NFR-002**: System MUST complete configuration file parsing and validation in under 100ms for configurations with up to 100 plugins

### Key Entities
- **Plugin Definition**: Represents a plugin in the configuration file; includes plugin name, Git repository URL, and commit hash
- **Plugin Installation**: Represents an installed plugin on disk; includes installation path, actual commit hash, and installation timestamp
- **Configuration File**: Contains the list of plugin definitions; format and location to be determined in planning phase
- **Lock File**: Records the installed state of all plugins; ensures reproducibility and tracks what was successfully installed

## Review & Acceptance Checklist

### Content Quality
- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

### Requirement Completeness
- [x] No [NEEDS CLARIFICATION] markers remain (all 3 clarifications resolved)
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Execution Status

- [x] User description parsed
- [x] Key concepts extracted
- [x] Ambiguities marked (3 items need clarification)
- [x] User scenarios defined
- [x] Requirements generated
- [x] Entities identified
- [x] Review checklist passed (all clarifications resolved)

---
