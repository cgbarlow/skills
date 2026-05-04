# Iris skill

Drives the [`iris-cli`](https://github.com/cgbarlow/iris/tree/main/cli)
command-line tool to search, browse, ask AI questions about, and
export content from an Iris architecture-knowledge repository.

## When it triggers

- The user mentions Iris (the architecture tool, not the flower or
  eye anatomy), an Iris diagram / element / package / set /
  collection, asking iris's AI a question, or exporting an Iris
  artefact as JSON or Markdown.
- The user types iris CLI commands like `iris search`, `iris diagrams
  get`, `iris export`, `iris ask`, `iris login`.
- The user wants to query an Iris repository programmatically.

## What it does

- Walks the user through installing iris-cli (`uv tool install …`)
  and the one-time `uv tool update-shell` PATH fix.
- Routes login to the right backend host (the iris-api service —
  **not** the SvelteKit frontend or the iris-mcp service) and picks
  the right login flow for the deployment mode (interactive
  username+password in SQLite mode; PAT-via-curl in Supabase mode).
- Picks the right CLI command for the user's intent: search, browse,
  ask, export, conversations, whoami.
- Prefers `--json` for machine-parsable output when chaining results.
- Maps the CLI's exit codes (`0` / `1` / `2` / `3`) to actionable
  next steps.

## Files

- `SKILL.md` — the skill contents Claude reads.
- `evals/evals.json` — test prompts (for the skill-creator eval loop).

## See also

- iris repository: <https://github.com/cgbarlow/iris>
- iris-cli docs: <https://github.com/cgbarlow/iris/blob/main/docs/cli.md>
- iris HTTP API docs: <https://github.com/cgbarlow/iris/blob/main/docs/api.md>
