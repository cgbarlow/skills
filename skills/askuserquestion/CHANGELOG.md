# Changelog

All notable changes to the **askuserquestion** skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this skill follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-09-25

Initial release.

### Added

- **`askuserquestion` skill** — emulates Claude Code's `AskUserQuestion` tool for OpenCode and other agents without a structured-question tool:
  - Same contract: 1–4 questions, ≤ 12-char header, 2–4 options with label + description, `multiSelect`, first-option `(Recommended)` convention, implicit free-text "Other".
  - Prefers a native tool (`AskUserQuestion` in Claude Code, `question` in OpenCode) when present.
  - Text rendering format, a hard stop-and-wait rule, and a reply-parsing table (`1a 2bc`, labels, `defaults`, free text → Other).
  - Non-interactive fallback (`opencode run`, CI): take recommended defaults and state the assumption.
- OpenCode-compatible frontmatter (`name` matches the directory, `description`, `license`, `compatibility`, `metadata`).
- `evals/evals.json` with trigger and behaviour test cases.
