<!--
Sync Impact Report:
- Version change: [NEW] → 1.0.0
- Initial constitution creation for Necromancer project
- Added principles: Minimal Dependencies, Synchronous-First, Commit-Based Versioning, TypeScript Foundation, Simplicity
- Templates requiring updates:
  ✅ plan-template.md - Compatible (constitution check section will reference these principles)
  ✅ spec-template.md - Compatible (no changes needed)
  ✅ tasks-template.md - Compatible (task generation follows principles)
- Follow-up TODOs: None
-->

# Necromancer Constitution

## Core Principles

### I. Minimal Dependencies (NON-NEGOTIABLE)
External library dependencies MUST be avoided unless absolutely critical. The plugin manager MUST rely primarily on Node.js built-in modules (fs, child_process, path, crypto). TypeScript compiler is allowed as a development dependency only. Any external runtime dependency MUST be explicitly justified and approved.

**Rationale**: Neovim plugin managers should be lightweight and self-contained. Reducing dependencies minimizes security risks, installation complexity, and maintenance burden.

### II. Synchronous-First Architecture
All core operations MUST be implemented synchronously. No async/await, Promises, or asynchronous patterns are permitted in the core functionality. Use synchronous variants of Node.js APIs (execSync, readFileSync, writeFileSync, etc.).

**Rationale**: Simplifies code reasoning, eliminates callback complexity, and aligns with the project's explicit "no async" requirement. Plugin management operations (clone, checkout, install) are infrequent enough that synchronous execution is acceptable.

### III. Commit-Based Versioning (NON-NEGOTIABLE)
Plugin versions MUST be specified exclusively via Git commit hashes. No support for tags, branches, or semantic versions. Each plugin entry MUST include an exact 40-character SHA-1 commit hash.

**Rationale**: Commit hashes provide immutable, reproducible builds. This eliminates version ambiguity and ensures deterministic plugin installations across environments.

### IV. TypeScript Foundation
All source code MUST be written in TypeScript with strict type checking enabled (`strict: true` in tsconfig.json). Runtime code MUST compile to plain JavaScript with no TypeScript runtime dependencies.

**Rationale**: TypeScript provides compile-time safety and better developer experience while compiling to portable JavaScript that runs in Node.js without additional runtime overhead.

### V. Simplicity Over Features
Every feature MUST justify its complexity. Prefer simple, obvious implementations over clever or abstract ones. Avoid patterns like dependency injection, repository abstractions, or complex inheritance hierarchies unless solving a proven concrete problem.

**Rationale**: Plugin managers are critical infrastructure—predictability and debuggability outweigh extensibility. Simple code is easier to audit, maintain, and debug when issues arise.

## Development Workflow

### Code Organization
- Core logic in `src/` directory
- Unit tests in `tests/` directory
- No monorepo, subprojects, or workspaces
- File-based modules with explicit exports

### Testing Requirements
- Unit tests MUST verify core functionality (parsing config, resolving commits, executing git operations)
- Integration tests SHOULD verify end-to-end plugin installation flows
- Tests MUST NOT require network access (mock git operations or use local test repositories)
- All tests MUST pass before merging

### Git Operations
- Use `execSync` for all git commands (clone, fetch, checkout)
- Capture stdout/stderr for error handling
- Operations MUST be idempotent where possible
- Failed git operations MUST provide actionable error messages

## Technical Constraints

### Language & Runtime
- **Language**: TypeScript 5.x (compiled to JavaScript ES2020+)
- **Runtime**: Node.js 18+ (for native ESM support and modern APIs)
- **Package Manager**: npm (standard, minimal tooling)
- **Module System**: ESM (import/export)

### Performance Standards
- Plugin installation SHOULD complete within 30 seconds for typical repositories
- Config parsing MUST handle 100+ plugin definitions without noticeable delay
- Disk operations SHOULD be batched to minimize I/O overhead

### Storage & State
- Plugin configuration stored in a single declarative file (e.g., `plugins.json` or `necromancer.json`)
- Installed plugins stored in predictable directory structure (e.g., `~/.local/share/nvim/necromancer/plugins/`)
- No database, no complex state management
- Lock file SHOULD track installed commit hashes for reproducibility

### Security Principles
- MUST validate commit hashes format (40-character hex)
- MUST sanitize all user input before passing to shell commands
- SHOULD verify git repository URLs are well-formed
- MUST NOT execute arbitrary code from plugin repositories during installation

## Governance

### Amendment Process
1. Proposed changes MUST be documented with rationale
2. Breaking changes require MAJOR version bump
3. New principles or constraints require community review (if project becomes public)
4. All amendments MUST update dependent templates within same commit

### Compliance Review
- All pull requests MUST verify adherence to Core Principles
- Code reviews MUST reject violations unless explicitly justified in PR description
- Complexity additions MUST document "Simpler Alternative Rejected Because" reasoning

### Version Control
- Constitution follows semantic versioning
- MAJOR: Principle removal or incompatible changes
- MINOR: New principle additions
- PATCH: Clarifications, typo fixes, non-semantic updates

**Version**: 1.0.0 | **Ratified**: 2025-10-05 | **Last Amended**: 2025-10-05
