# Changelog

All notable changes to Knowledge Database will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.2] - 2026-08-21

### Added
- Clear auto-capture trigger table (what records, what doesn't)
- Priority guidance (errors > investigations > decisions > solutions)
- "Rename with reasoning" now triggers recording (it's a decision)

### Changed
- Rule of thumb: "If there was reasoning, record it. Future you will ask why?"

## [0.2.1] - 2026-08-21

### Changed
- Auto-capture is now mandatory, not an optional prompt
- Non-trivial work automatically creates KB entry
- User reviews entry content, not whether to create it

## [0.2.0] - 2026-08-21

### Added
- **Auto-capture enforcement** (Mechanism 8): Always prompt user at task end to create KB entry
- **Consent for superseding** (Mechanism 9): Ask before marking verified entries as superseded
- **Test suite**: 23 tests covering all CLI tools (init, lint, ingest, discover)
- **Security**: Input sanitization for YAML and sed injection prevention
- **.gitignore handling**: init script auto-adds knowledge-db/ to .gitignore
- **Worked examples**: Real KB entries demonstrating the pattern

### Changed
- Upgraded from 8 to 9 enforcement mechanisms
- kb-lint --fix now uses awk instead of sed for safer INDEX.md updates
- Phase 1 milestones updated to reflect completion status

### Fixed
- YAML injection vulnerability in kb-ingest (title/tags)
- sed injection vulnerability in kb-lint --fix
- Template tags no longer flagged as typos in kb-lint

## [0.1.0] - 2026-08-20

### Added
- Initial release
- Four-bucket structure (explorations, solutions, errors, decisions)
- Eight enforcement mechanisms
- CLI tools: init-knowledge-db.sh, kb-ingest, kb-discover, kb-lint
- CLAUDE.md with HARD RULE pattern
- Advanced Usage guide (Context Workspace pattern)
- Roadmap for Phase 2 (git hooks) and Phase 3 (GitHub Action)

[0.2.2]: https://github.com/dcoferraz/knowledge-database/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/dcoferraz/knowledge-database/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/dcoferraz/knowledge-database/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/dcoferraz/knowledge-database/releases/tag/v0.1.0
