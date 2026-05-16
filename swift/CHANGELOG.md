# Swift App Changelog (Claude-MTW-Replay)

All notable changes specific to the Swift macOS app live here. Web changelog: `../CHANGELOG.md`.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — Unreleased (first public release)

### Added
- Interactive Chats tab via `@anthropic-ai/claude-agent-sdk` (Sprint 4-A through 5-E coverage):
  full session lifecycle (start/stop/resume), streaming assistant output,
  tool-use rendering, MCP-aware composer affordances.
- Sessions table reaches full web parity (CM2 milestone): filtering, sorting,
  grouping, multi-select, bulk actions.
- Replay viewer wired to the same parser pipeline as the web app — tool blocks,
  diffs, redaction toggle, theme switching, code-block syntax highlighting.
- Discovery scan across all configured Claude account roots
  (`~/.claude`, `~/.claude-yahoo`, `~/.claude-outlook`, …) with Docker volume
  mounts where applicable.
- Export pipeline: single-session HTML, multi-session ZIP, “open in browser”
  passthrough that reuses the web template build.
- Statistics tab (token/cost rollups), Git tab (commit overlay on replay),
  Stub Inspector for audit-driven cleanup.
- Release engineering scaffolding: `swift/scripts/verify-universal.sh`,
  `notarize.sh`, `sparkle-appcast.sh`, `RELEASE.md`.

### Changed
- Marketing version synchronized to **1.0.0** across `swift/project.yml`,
  `swift/sidecar/package.json`, and the DMG output name.
- DMG version now read from `swift/project.yml` (`MARKETING_VERSION`) instead of
  the root `package.json` — Swift app and web CLI versions are now decoupled.
- `Info.plist` defers `CFBundleShortVersionString` / `CFBundleVersion` to the
  build settings injected by xcodegen, keeping `project.yml` as the single
  source of truth.

### Fixed
- 18 known stubs/issues from the initial audit (`docs/AUDIT_SWIFT.md`)
  resolved during Sprints 1–3 (P0/P1/P2 backlog).

## [0.8.1-swift] — historical
- Declared the “web parity” milestone for the Swift app.
- Web feature parity for parser, redaction, themes, discovery, export, replay,
  statistics, and git overlay.

## [0.8.0-swift] — historical
- Interactive Chats tab introduced via Claude Agent SDK.
- Initial Node sidecar bridging Swift UI to `@anthropic-ai/claude-agent-sdk`
  over stdio.
