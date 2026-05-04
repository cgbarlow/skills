---
name: iris
description: Drive the iris-cli command-line tool to search, browse, ask AI questions about, and export content from an Iris architecture-knowledge repository (https://github.com/cgbarlow/iris). Use whenever the user mentions iris in an architecture/systems context, references an iris diagram/element/package/set/collection, asks iris's AI a question about systems, or wants to export an iris artefact as JSON or Markdown — even when the user doesn't say "iris-cli" by name. The skill ensures iris-cli is installed (uv tool), guides login (SQLite mode is interactive; Supabase deployments require --token with an externally-minted PAT because /api/auth/login is disabled), prefers --json for machine-parsable output when chaining results, and routes the user to the correct iris-api backend host (not the SvelteKit frontend, not the iris-mcp service).
---

# Iris — drive the iris-cli command-line tool

This skill drives [`iris-cli`](https://github.com/cgbarlow/iris/tree/main/cli),
the Python command-line client for an **Iris architecture-knowledge
repository**. Iris models systems as a graph of *collections → sets →
packages → elements → diagrams*. The CLI exposes read-only browse,
search, AI Q&A, and export operations against any Iris backend over
HTTP.

When the user mentions iris in this context, prefer the CLI over
inventing your own HTTP calls — the CLI handles auth, rate-limit
buckets, output formatting, and the SQLite-vs-Supabase deployment-
mode split for you.

---

## 1. When this skill applies (and when it doesn't)

### MCP-first rule (read this before reaching for the CLI)

**If `mcp__*__Iris__*` tools are loaded in the current session, ALWAYS
use those — never the CLI.** The MCP tools are typed, validated, run
server-side, work in every Claude surface (Cowork, Desktop chat,
claude.ai web), and don't need a shell. The CLI exists for environments
where there's a real local shell *and* no MCP is configured — namely
Claude Code in a terminal or in Desktop "Code" mode.

| Environment | Best path |
|---|---|
| Claude Code CLI / Desktop "Code" tab | iris-cli (this skill, full body below) |
| Cowork — Desktop or web | `mcp__claude_ai_Iris__*` tools (don't read further; pick the right MCP tool for the user's intent) |
| Standard Claude Desktop chat / claude.ai web | `mcp__claude_ai_Iris__*` tools |

The iris-cli sandbox in Cowork is ephemeral, slow to boot, sometimes
fails outright, and doesn't have iris-cli pre-installed. The MCP
sidesteps every one of those failure modes.

### CLI triggers

If MCP isn't available, this skill is the right answer when the user:
- Mentions an Iris diagram, element, package, set, or collection.
- Wants to search or browse an Iris repository.
- Wants to ask Iris's AI a question grounded in one or more sets
  (with optional file contexts).
- Wants to export an Iris artefact as JSON or Markdown.
- Types any `iris …` command verbatim — even when MCP is loaded the
  user has explicitly asked for the CLI; respect that.

### Skip entirely

- The user is asking about *iris* the flower, *iris* the eye anatomy,
  or *Iris* the Greek goddess. (The repo's eye favicon makes the
  context obvious in conversation but worth a beat of judgement
  before reaching for either CLI or MCP.)

---

## 2. Setup — install + first login

### Install

iris-cli is a Python tool installed via `uv`. The user might already
have it (`which iris`); if not:

```sh
uv tool install --from "git+https://github.com/cgbarlow/iris#subdirectory=cli" iris-cli
```

If the user doesn't have `uv` itself, suggest the official installer
(`curl -LsSf https://astral.sh/uv/install.sh | sh`) — but check
`uv --version` first to avoid re-installing.

### One-time PATH fix

On the first `uv tool install` ever performed on a machine, `uv` warns
that `~/.local/bin` isn't on `PATH`. Run this **once** so every
future uv-installed tool resolves automatically:

```sh
uv tool update-shell
exec $SHELL -l           # reload shell so the new PATH takes effect
```

### What URL is the backend?

`iris login --url <URL>` requires the **iris-api backend service** —
the host that serves `/api/*`. It is **not**:
- The SvelteKit frontend (e.g. `https://iris-uat.chrisbarlow.nz`),
  which serves the SPA shell at every path and would 404 every API
  call from the CLI.
- The iris-mcp service (e.g. `https://iris-mcp.onrender.com`), which
  speaks MCP, not REST.

Known backends:
- **UAT**: `https://iris-api-gtb3.onrender.com`
- **Local self-host**: `http://localhost:8000` (the default)
- **Other**: whatever host the user's `iris-api` Render / Docker /
  uvicorn service is on.

If unsure, ask the user, or check the frontend's `VITE_API_BASE_URL`
env var — that's the backend host the SPA points at.

### Login — two paths

The right path depends on which mode the backend runs in. If you
don't know, try **(a)** first; on a 404 with "Supabase deployment
mode" in the detail, switch to **(b)**.

**(a) SQLite-mode backend** (local dev, single-tenant self-host) —
interactive username + password, mints a PAT, saves to
`~/.config/iris/config.toml`:

```sh
iris login --url https://iris-api.example.com
# Prompts for username + password.
# Result: { url, token = "iris_pat_…" } stored at
# $XDG_CONFIG_HOME/iris/config.toml (mode 0600).
```

**(b) Supabase-mode backend** (UAT, multi-tenant prod) — the
backend's `/api/auth/login` is intentionally disabled (auth flows
through Supabase Auth, not the iris backend). Mint a PAT externally
and hand it to the CLI with `--token`:

```sh
# 1. Sign in via the frontend (e.g. https://iris-uat.chrisbarlow.nz).
#    In browser DevTools → Application → Local Storage, find the
#    sb-<project-ref>-auth-token entry and copy the access_token field.
SUPABASE_JWT='eyJhbGciOi…'

# 2. Mint a PAT with that JWT:
PAT=$(curl -sX POST https://iris-api-gtb3.onrender.com/api/users/me/tokens \
  -H "Authorization: Bearer $SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{"name":"iris-cli"}' \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')

# 3. Persist it via iris login (no API call — just writes the config):
iris login --url https://iris-api-gtb3.onrender.com --token "$PAT"
```

The PAT is shown **exactly once** at mint time. If the user loses it,
mint a new one — they're cheap to revoke and recreate.

### Anonymous mode

Login is optional. With no PAT configured, the CLI runs against the
backend's anonymous rate-limit buckets (`anon` / `anon_ai`) and can
do read-only browse, search, AI ask, and export — same scope an
unauthenticated browser visitor has. Useful for quick exploration; for
sustained work, log in so the user gets the more generous `pat`
bucket and any role-gated content.

### Config resolution order

Every command resolves `--url` and `--token` in this order:
1. CLI flags (`--url`, `--token`).
2. Env vars (`IRIS_URL`, `IRIS_TOKEN`).
3. `$XDG_CONFIG_HOME/iris/config.toml` (defaults to `~/.config/...`).
4. Anonymous defaults (`http://localhost:8000`, no token).

So once the user has run `iris login` once, every subsequent command
just works without flags.

---

## 3. Common operations — what command to reach for

Use this table to pick the command. Append `--json` to anything in
the *Read* group when you need to chain output through `jq` or feed
it into another tool.

| Intent | Command |
|---|---|
| Search across the whole repository | `iris search "query"` |
| Search inside a specific set | `iris search "q" --set <set-id>` |
| List diagrams (paginated) | `iris diagrams list [--set <id>] [--limit N]` |
| Inspect one diagram | `iris diagrams get <diagram-id>` |
| Diagram revision history | `iris diagrams versions <diagram-id>` |
| List elements / get one | `iris elements list [--set <id>]` / `iris elements get <id>` |
| List packages / get one | `iris packages list [--set <id>]` / `iris packages get <id>` |
| List sets / get one | `iris sets list [--collection <id>]` / `iris sets get <id>` |
| List collections / get one | `iris collections list` / `iris collections get <id>` |
| Export an artefact | `iris export {diagram\|element\|package\|set\|collection} <id> --format {json\|markdown} [-o PATH]` |
| Ask iris's AI a question | `iris ask "question" --set <id> [--stream] [--mode discuss\|creation]` |
| Show conversation history | `iris conversations list --set <id>` |
| Show the authenticated user | `iris whoami` |

Notes:
- `--stream` on `iris ask` prints SSE chunks as they arrive — best
  for the user watching live; turn it off with `--no-stream` for
  scripting.
- `iris ask --set` can be passed multiple times to ground the
  question in several sets at once (multi-set Q&A).
- `iris export … -o -` writes to stdout instead of a file.
- Markdown export is deterministic — safe to commit to a wiki repo
  with `iris export set <id> --format markdown -o docs/platform.md`.

---

## 4. Worked examples

**Example 1: find what owns customer PII**

```sh
iris ask "Which services in the default set own customer PII?" \
  --set default --stream
```

Streams the answer as it's generated. Drop `--stream` to wait for
the complete answer.

**Example 2: pipe search hits into jq**

```sh
iris search payment --json | jq '.results[].name'
```

Lists the names of every search match. The `--json` flag is the
right reach whenever Claude needs to act on iris output
programmatically (vs. show it to the user).

**Example 3: snapshot a set into a wiki**

```sh
iris export set 7d4f8c9b-2e1a-4f3b-9a8c-1234567890ab \
  --format markdown -o docs/platform-architecture.md
```

Produces a deterministic Markdown bundle of every package, diagram,
and element in the set. Commit it to a wiki repo and re-run the
command on each iris-side change.

**Example 4: who am I?**

```sh
iris whoami
```

Returns the user the current PAT belongs to. Useful for verifying a
freshly-pasted token before running a longer pipeline.

---

## 5. Exit codes — error handling

Every command returns one of:

| Code | Meaning | What to do |
|---|---|---|
| `0` | Success | Continue. |
| `1` | Backend HTTP 4xx / 5xx (not auth) | Read the printed detail; surface to the user. Often "not found" or a malformed argument. |
| `2` | Network / connection error | Backend probably down or unreachable. Check the URL; if on Render's free tier, suspect cold start (60-s spin-up after idle) and retry once. |
| `3` | 401 / 403 — auth | Token missing, invalid, expired, or the user lacks permission. The CLI prints a hint to re-run `iris login`. |

When chaining commands, check `$?` after each step rather than
assuming success.

---

## 6. The Supabase 404 — the most common surprise

The single thing most likely to trip up a first-time iris-cli user
on a UAT / production deployment is hitting `iris login --url ...`
without `--token` and seeing:

```
Error: This backend runs in Supabase deployment mode — /api/auth/login
       is disabled. Mint a PAT externally (via the frontend or curl
       + a Supabase JWT) and re-run:

  iris login --url <URL> --token iris_pat_…
```

This is the error that means: jump to **§2 → Login (b)**. The
`/api/auth/login` username+password endpoint is intentionally absent
in Supabase mode because Supabase Auth handles credentials. Mint the
PAT via the curl recipe and re-run with `--token`.

---

## 7. When to fall back to raw HTTP

The CLI covers the read-only + AI surface area. If the user wants to
*write* to iris (create a diagram, modify an element, etc.), the
CLI doesn't expose those operations — they run through the iris HTTP
API directly with the same PAT in `Authorization: Bearer …`. Pull up
[`docs/api.md`](https://github.com/cgbarlow/iris/blob/main/docs/api.md)
and the OpenAPI schema at `<backend>/api/docs` for the full surface.
