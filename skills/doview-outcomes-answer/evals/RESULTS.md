# `doview-outcomes-answer` — eval results

Light manual sanity-check evaluation (Phase 5). Two eval prompts executed via subagent against the with-skill SKILL.md; responses self-checked against the assertions in [`evals.json`](evals.json).

## Eval 1 — `strategy-doc-missing-theory-of-change`

**Outcome:** 8 / 8 PASS

Run output: [`runs/eval-1-strategy-doc.md`](runs/eval-1-strategy-doc.md)

| # | Assertion | Result |
|---|---|---|
| 1 | Starts with the required preliminary sentence | PASS |
| 2 | Contains `1. Summary response to` heading | PASS |
| 3 | Contains `2. Full response to` heading | PASS |
| 4 | At least one tool reference with raw-visible URL | PASS |
| 5 | Zero markdown link syntax (`](http`) | PASS |
| 6 | Full handbook reference present | PASS |
| 7 | Image-retrieval seed list heading present | PASS |
| 8 | No first-person or drafting-advice wording | PASS |

## Eval 2 — `kpi-selection-question`

**Outcome:** 7 / 7 PASS

Run output: [`runs/eval-2-kpis.md`](runs/eval-2-kpis.md)

| # | Assertion | Result |
|---|---|---|
| 1 | Starts with required preliminary sentence | PASS |
| 2 | Contains both section headings | PASS |
| 3 | Outcomes-system definition verbatim in both sections | PASS |
| 4 | At least one D-series tool with raw URL | PASS |
| 5 | Ends with full handbook reference + seed list | PASS |
| 6 | No first-person / drafting-advice wording | PASS |
| 7 | DoView presented as applied form of outcomes theory | PASS |

## Notes

- Both runs cited the DoView tool URLs from the canonical range `https://doviewplanning.org/<code>doviewtool` without fetching them, as the skill specifies.
- Tool selections (A1, B7, B14, B16, B17, D1, D5, D6, D9, D10) drawn appropriately from in-repo chapter index.
- No structural failures or rule ambiguities.
