# IR3 Tax Return (NZ, 2026)

**A Claude skill for filing a New Zealand individual IR3 income tax return for the year ended 31 March 2026, by driving the official Inland Revenue myIR portal in the browser.**

## Overview

`ir3-tax-return` walks the official IR3 wizard at https://myir.ird.govt.nz/, prompting the user only for fields IRD hasn't pre-populated, performing the official IR3G 2026 calculation worksheets (tax on taxable income, ACC earners' levy, IETC, PIE adjustment, student loan, provisional tax), and refusing to click final Submit without explicit fresh consent. It is grounded in IRD's official **IR3G (March 2026)** guide, bundled in `references/`.

## How it works

1. **Invoke** by mentioning anything tax-return-related in a NZ context — "do my IR3", "file my taxes with IRD", "help with my 2026 tax return". The skill triggers automatically.
2. **The skill navigates** to https://myir.ird.govt.nz/ and pauses for you to sign in via RealMe (or myIR credentials). It will **never** type your password or 2FA.
3. **It walks the wizard pages in order**, treating IRD's pre-populated SOI / interest / dividends / PIE data as the starting point. For each blank field that needs a value, it prompts you with a focused question.
4. **It runs the official IRD worksheets in chat** before typing any calculated value, so you can audit the arithmetic.
5. **At the declaration page** it reads back every key figure (residual income tax, refund or tax to pay, provisional tax for next year) and waits for an explicit "yes submit" before clicking. The IR3 declaration is a legal statement — only you can swear to it.
6. **After submission** it confirms the receipt page, notes upcoming due dates (tax to pay 7 Feb 2027; provisional instalments 28 Aug 2026 / 15 Jan 2027 / 7 May 2027 if RIT > $5,000), and offers to log you out.

## Compatibility

Requires a **browser-automation runtime** (e.g. **Claude for Chrome** or a Computer-Use environment) with tools to navigate URLs, click elements, type into form fields, take screenshots, and read on-screen text.

If loaded into a non-browser runtime (plain Claude Code in a terminal, Claude.ai without Computer-Use), the skill falls back to interview mode and produces a worksheet you transcribe into myIR yourself (see Section 12 of `SKILL.md`).

## What the skill will not do

- Type your RealMe password, myIR password, or 2FA code (always your job).
- Click the final Submit button without explicit fresh consent in the same turn.
- Invent a value to fill a missing field.
- Help you omit income or otherwise misstate the return.
- Handle complex situations where a tax agent should be engaged (foreign superannuation transfers via formula method, non-complying trust beneficiary distributions, complex bright-line / mixed-use property, bankruptcy returns, deceased-estate finalisation). It will flag these and recommend you consult a registered tax agent.

## Files

- `SKILL.md` — main skill instructions (frontmatter + workflow + boundaries)
- `references/IR3G-2026.txt` — full extracted text of the official IRD guide (2,553 lines)
- `references/IR3G-2026.pdf` — the original 63-page PDF
- `references/myir-navigation.md` — click-path through the myIR wizard
- `references/worksheets-2026.md` — 2026 rate tables and all official IRD calculation worksheets
- `references/form-questions.md` — Q1–Q42 cheat sheet
- `evals/evals.json` — 7 test prompts (happy-path, refusal, escalation, edge cases)

## Installation

Place the skill directory in your Claude skills folder:

```
~/.claude/skills/ir3-tax-return/
```

Or, if you're using a project-scoped skills directory, copy into:

```
<project>/.claude/skills/ir3-tax-return/
```

For Claude Desktop / Claude for Chrome, install via the skill management UI (or copy the directory into the skills location your runtime reads from — varies by client).

## Disclaimer

This skill is not a registered tax agent and does not provide professional tax advice. It follows the official IR3G (March 2026) guide as faithfully as possible, but you remain responsible for the accuracy of your return and for signing the Q42 declaration. For anything unusual, verify with IRD on **0800 775 247** or engage a registered tax agent.

## License

MIT
