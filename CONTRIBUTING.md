# Contributing

For scaffolding a brand-new skill, see **[Contributing a new skill](./README.md#contributing-a-new-skill)** in the README. This doc covers the **change → version → release** workflow that applies to every change.

## Workflow

1. **Branch** off `main` (`feature/…`, `fix/…`, `chore/…`).
2. Make the change. If it touches a skill, update that skill's `CHANGELOG.md` and bump the skill's `version` in `.claude-plugin/marketplace.json`.
3. Bump the marketplace `metadata.version` (see [Versioning](#versioning)).
4. Open a PR into `main`; merge once green (squash is fine).
5. **Cut a GitHub Release** for the new marketplace version (see [Releases](#releases)).

## Versioning

Two independent SemVer numbers live in `.claude-plugin/marketplace.json`:

- **Per-skill** — each plugin entry's `"version"`. Bump it (with a matching `CHANGELOG.md` entry in `skills/<name>/`) whenever that skill changes. patch = fix, minor = feature, major = breaking.
- **Marketplace** — `metadata.version`. Bump it on **every** merge to `main` that changes any skill: patch for a skill patch/fix, minor when a skill gets a feature or a new skill is added.

Convert relative dates to absolute in changelogs. Keep the skill `CHANGELOG.md` as the source of truth for per-version detail; the marketplace version is just the release coordinate.

## Releases

**Every marketplace version bump gets a GitHub Release.** This is the repo convention (resumed at `v2.6.1`) — it gives each version a human-readable landmark and a stable tag, even though the Claude Code marketplace itself installs by cloning the repo and reading `marketplace.json` (it does **not** consume GitHub Releases).

After the version bump is merged to `main`:

```sh
# Tag = v<marketplace metadata.version>, targeting the merged main commit.
gh release create v<MARKETPLACE_VERSION> \
  --target main \
  --title "v<MARKETPLACE_VERSION> — <one-line headline>" \
  --notes "<summary of the skill changes; point to skills/<name>/CHANGELOG.md for detail>"
```

Conventions:
- **Tag name** is `v<marketplace metadata.version>` (e.g. `v2.6.1`) — the marketplace number, not a per-skill number.
- **Target `main`**, after the PR is merged, so the tag points at the merged commit.
- **Notes** summarize what changed (lead with the skill + its new version); link to the per-skill `CHANGELOG.md` rather than duplicating it in full.
- Let `gh` mark it **Latest** (default).

Verify:

```sh
gh release view v<MARKETPLACE_VERSION>
git rev-list -n1 v<MARKETPLACE_VERSION>   # should equal origin/main HEAD
```
