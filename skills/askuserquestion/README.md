# askuserquestion

**An OpenCode-compatible skill that emulates Claude Code's `AskUserQuestion` tool.**

## Overview

Claude Code has a built-in `AskUserQuestion` tool: the agent asks 1–4 structured
multiple-choice questions (header, 2–4 options with descriptions, optional multi-select,
a recommended default, and an implicit free-text "Other"), then waits for the answer.
OpenCode and most other agents have no such tool, so skills written for Claude Code that
say "use `AskUserQuestion`" fall apart there.

This skill supplies the same contract as a portable protocol:

1. **When to ask** — only when blocked on a decision that is genuinely the user's.
2. **Native first** — use `AskUserQuestion` (Claude Code) or a `question` tool (OpenCode) if available.
3. **Text emulation** — otherwise render a numbered, lettered question block, **stop the turn**, and wait.
4. **Parse the reply** — `1a 2bc`, option names, `defaults`, or free text (→ "Other"), then continue.
5. **Non-interactive runs** — in `opencode run` / CI, take the recommended defaults and state the assumption.

## Installation

### OpenCode

Copy the directory into any OpenCode skill location (the directory name must stay `askuserquestion`):

```
.opencode/skills/askuserquestion/SKILL.md          # per project
~/.config/opencode/skills/askuserquestion/SKILL.md # global
```

OpenCode also discovers Claude-compatible locations (`.claude/skills/…`, `~/.claude/skills/…`).
The agent loads it on demand through the `skill` tool when a clarifying question is needed.

### Claude Code

Install from this marketplace:

```
/plugin install askuserquestion@cgbarlow-skills
```

In Claude Code the skill simply defers to the native `AskUserQuestion` tool.

## License

CC-BY-SA 4.0
