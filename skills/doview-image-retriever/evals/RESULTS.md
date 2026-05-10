# `doview-image-retriever` — eval results

Light manual sanity-check evaluation (Phase 5). One eval prompt executed via subagent against the with-skill SKILL.md; response self-checked against the assertions in [`evals.json`](evals.json).

## Eval 1 — `mermaid-available-A01-B16`

**Outcome:** 6 / 6 PASS

Run output: [`runs/eval-1-mermaid-A01-B16.md`](runs/eval-1-mermaid-A01-B16.md)

| # | Assertion | Result |
|---|---|---|
| 1 | Begins with IMAGE DISPLAY LIMITATION WARNING | PASS |
| 2 | Contains `Relevant images from the DoView Planning…` heading + raw-visible book URL | PASS |
| 3 | At least one verbatim ```` ```mermaid ```` block from the cited chapter `tool.md` | PASS |
| 4 | Every tool URL is raw-visible plain text | PASS |
| 5 | No markdown link syntax for URLs (`](http`) | PASS |
| 6 | Ends with full handbook reference + raw-visible book URL | PASS |

## Notes

- Both cited chapters (A01, B16) had Mermaid blocks under `## Diagram` — Mermaid-first path applied to both. B16 has two sub-blocks (A: siloed; B: not-siloed); both reproduced verbatim with their surrounding prose headings.
- No image-file URLs are separately published on the permitted tool pages. The agent correctly stated this in plain text rather than fabricating a URL — compliant with the MANDATORY IMAGE DISPLAY RULE's "if available" caveat.
- The Mermaid-first overlay (added to the upstream prompt per ADR-009 / SPEC-010-B) integrated cleanly with the upstream rules. No conflicts.

## Outstanding evals (deferred to a follow-up run if needed)

The PNG-fallback eval (eval id 2: `png-fallback-C04`), the subchapter-G02A eval (eval id 3), and the IMAGE PRIORITISATION RULE eval (eval id 4) were not executed in this Phase. The single executed eval exercises the primary Mermaid-first path with two distinct chapters. The remaining assertions in `evals.json` can be re-run in a follow-up if regressions are suspected.
