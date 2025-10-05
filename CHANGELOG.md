# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.3] - 2025-10-06

### Changed
- Disabled source maps and declaration maps to reduce package size by ~47%.

### Updated
- Documentation about source map configuration in CLAUDE.md.

## [0.1.2] - 2025-10-06

### Changed
- Updated installation guide in documentation.
- Updated Claude command documentation.

### Fixed
- Enforced synchronous-only architecture in CLI commands to maintain constitutional principles.

## [0.1.1] - 2025-10-05

### Added
- Initial release of Necromancer - Git commit-based plugin manager for Neovim.
- Zero runtime dependencies - only Node.js built-ins.
- Synchronous-only architecture with no async/await or Promises.
- CLI commands: `install`, `update`, `list`, `clean`.
- Commit hash versioning with 40-character SHA-1 validation.
- TypeScript strict mode compilation to ES2020+ JavaScript.

[unreleased]: https://github.com/sontixyou/necromancer.nvim/compare/v0.1.3...HEAD
[0.1.3]: https://github.com/sontixyou/necromancer.nvim/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/sontixyou/necromancer.nvim/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/sontixyou/necromancer.nvim/releases/tag/v0.1.1
