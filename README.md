# Chris's Skills Marketplace

A personal Claude Code marketplace bundling skills and plugins I rely on
day-to-day — driving Iris architecture knowledge, filing NZ taxes,
tracking timesheet hours, converting PDFs to ebooks, coaching my own
prompts, plus the [Campaign Mode](https://github.com/cgbarlow/campaign-mode)
quest framework and its [Six Animals](https://github.com/cgbarlow/simons-six-animals)
advisory council.

## What's in here

| Plugin | What it does |
|---|---|
| [`iris`](skills/iris) | Drives the [iris-cli](https://github.com/cgbarlow/iris) tool — search, browse, ask AI, export from an Iris architecture repository. Triggers on iris/diagram/element/package/set/collection language and on `iris …` commands. |
| [`ir3-tax-return`](skills/ir3-tax-return) | Files an NZ individual IR3 income tax return for the 2026 tax year by driving the IRD myIR portal. Pauses for RealMe sign-in; refuses final Submit without explicit fresh consent. |
| [`timesheet`](skills/timesheet) | Interactive timesheet entry — collects work description, date, start/end times via prompts, calculates hours, appends to `.campaign/timesheet.md`. Supports clock-in / clock-out shortcuts. |
| [`pdf-to-ebook`](skills/pdf-to-ebook) | Converts a PDF to ebook formats (epub, mobi, azw3) via Calibre. |
| [`agentic-coach`](skills/agentic-coach) | Interactive prompt-engineering coach — elevates vague prompts via Socratic dialogue, multiple transformation styles, and guided learning. |
| [`flow-coach`](skills/flow-coach) | Interactive [claude-flow](https://github.com/ruvnet/claude-flow) orchestration coach — swarm topology, agent deployment, memory configuration, SPARC workflows. |
| [`six-animals`](https://github.com/cgbarlow/simons-six-animals) | Six psychologically-grounded team-role agents (Bear, Cat, Owl, Puppy, Rabbit, Wolf) plus Simon as educator/supervisor. Prerequisite for the full Campaign Mode experience. |
| [`campaign-mode`](https://github.com/cgbarlow/campaign-mode) | Quest-based extension for AI-assisted work. Three NPC agents (Gandalf, Dragon, Guardian) provide mentorship, adversarial testing, and quality gates. |

The first six plugins ship from this repository — each one is a skill
directory under [`skills/`](skills) that the marketplace lists as a
separately-installable plugin. The last two are listed for convenience
and source from their own repos.

## Quick Start

### Claude Cowork and Claude Code Desktop

1. From either the **Cowork** or **Code** tab in Claude Desktop, select **+** → **Plugins** → **Add plugin**.
2. **Add marketplace** — Select the **By Anthropic** dropdown, then select **Add marketplace from GitHub** and enter:
   ```
   https://github.com/cgbarlow/skills
   ```
3. **Install plugins** — find and install whichever plugins you want from the marketplace. Each one is independent — install just `iris`, just `timesheet`, or all eight.

### Claude Code CLI

1. **Install Claude Code** ([full guide](https://code.claude.com/docs/en/quickstart)):
   ```bash
   curl -fsSL https://claude.ai/install.sh | bash
   ```
2. **Add the marketplace** — in a Claude Code session:
   ```
   /plugin marketplace add cgbarlow/skills
   ```
3. **Install the plugin you want** (one at a time, or repeat for multiple):
   ```
   /plugin install iris@cgbarlow-skills
   /plugin install ir3-tax-return@cgbarlow-skills
   /plugin install timesheet@cgbarlow-skills
   /plugin install pdf-to-ebook@cgbarlow-skills
   /plugin install agentic-coach@cgbarlow-skills
   /plugin install flow-coach@cgbarlow-skills
   /plugin install campaign-mode@cgbarlow-skills
   /plugin install six-animals@cgbarlow-skills
   ```
4. **Reload** so the new skills are picked up by your current session:
   ```
   /reload-plugins
   ```

That's it. After install, the skills trigger automatically — you don't
need to type their names. Say "use iris to search for payments" and the
`iris` skill triggers. Say "I need to file my IR3" and `ir3-tax-return`
triggers. List loaded skills any time with `/skills`.

## Repository layout

```
skills/
├── .claude-plugin/
│   └── marketplace.json     # the marketplace (lists 8 plugins)
└── skills/
    ├── iris/{SKILL.md, README.md, evals/}
    ├── ir3-tax-return/
    ├── timesheet/
    ├── pdf-to-ebook/
    ├── agentic-coach/
    └── flow-coach/
```

Each marketplace entry lists the skill via `"skills": ["./skills/<name>"]`,
mirroring [`anthropics/skills`](https://github.com/anthropics/skills/blob/main/.claude-plugin/marketplace.json).
Installing a plugin clones the whole repo but loads only the named
skill — fine on disk, and means each skill can be installed
individually without forcing the whole bundle.

## Contributing a new skill

1. Use [skill-creator](https://github.com/anthropics/skills) to scaffold
   the skill (it'll write a SKILL.md and evals).
2. Drop it in `skills/<your-skill>/`.
3. Add an entry to `.claude-plugin/marketplace.json` with
   `"source": "./"` and `"skills": ["./skills/<your-skill>"]`.
4. Mention it in this README's table.

## License

Each plugin carries its own license metadata in the marketplace listing.
The default is CC-BY-SA 4.0 unless otherwise noted in the individual
plugin directory.

---

🤖 Built with Claude Code.
