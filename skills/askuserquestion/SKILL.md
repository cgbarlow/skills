---
name: askuserquestion
description: Emulates Claude Code's AskUserQuestion tool in OpenCode (and any agent without it) — asks the user 1–4 structured multiple-choice questions, each with a short header, 2–4 labelled options with descriptions, optional multi-select, a recommended default, and an always-available free-text "Other" answer, then stops and waits for the reply before continuing. Use whenever you are blocked on a decision that is genuinely the user's to make and cannot be resolved from the request, the code, or a sensible default — choosing between approaches, libraries, scopes, naming, or trade-offs; clarifying an ambiguous requirement; or when another skill or instruction says "use AskUserQuestion" and no such tool exists.
license: CC-BY-SA-4.0
compatibility: opencode, claude-code
metadata:
  emulates: AskUserQuestion
  version: "1.0.0"
---

# askuserquestion

A portable replacement for Claude Code's `AskUserQuestion` tool. OpenCode (and many
other agents) have no built-in structured-question tool, so this skill defines the
same contract — same fields, same limits, same behaviour — and tells you how to
render it as a chat message, stop, and parse the user's reply.

When another skill or instruction says "use `AskUserQuestion`", follow this skill.

## 1. Decide whether to ask at all

Ask **only** when you are blocked on a decision that is genuinely the user's:

- It cannot be resolved from the request, the codebase, docs, or a conventional default.
- The answer changes what you do next.

Do **not** ask when there is an obvious conventional choice (pick it and mention it),
when you could verify the fact yourself (read the file, run the command), or to ask
"is my plan OK?" / "should I proceed?". Batch everything you need into **one** ask
rather than drip-feeding questions across turns.

## 2. Prefer a native tool if one exists

Check your available tools first:

| Environment | Use |
|---|---|
| Claude Code | the real `AskUserQuestion` tool |
| OpenCode with a `question` tool | that tool, mapping the fields in §3 onto its parameters |
| Anything else (no structured-question tool) | the text emulation in §4 |

Only fall through to the text emulation when no native tool is available.

## 3. The contract (mirrors AskUserQuestion)

```json
{
  "questions": [                        // 1–4 questions
    {
      "question": "Which database should the service use?",  // full sentence, ends with "?"
      "header": "Database",             // chip label, ≤ 12 characters
      "multiSelect": false,             // true = user may pick several options
      "options": [                      // 2–4 options, mutually exclusive unless multiSelect
        { "label": "PostgreSQL (Recommended)",   // 1–5 words
          "description": "Already used by the billing service; team knows it." },
        { "label": "SQLite",
          "description": "Zero-ops, single file; fine for < 1 writer." }
      ]
    }
  ]
}
```

Rules:

- **1–4 questions** per ask; **2–4 options** per question.
- **Never add an "Other" option yourself** — "Other" (free text) is always implicitly
  available and is added by the renderer (§4).
- If you recommend an option, make it the **first** option and append
  **` (Recommended)`** to its label.
- `header` is a short tag (≤ 12 chars), e.g. `Auth method`, `Library`, `Scope`.
- Each `description` states the consequence or trade-off, not a restatement of the label.
- Options must be distinct; for single-select they must be mutually exclusive.

## 4. Text emulation (no native tool)

### 4a. Render

Write the questions as one message in exactly this shape, then **end your turn**:

```markdown
**I need your input before I continue.**

**1. [Database]** Which database should the service use?
   - **a) PostgreSQL (Recommended)** — Already used by the billing service; team knows it.
   - **b) SQLite** — Zero-ops, single file; fine for < 1 writer.
   - **c) Other** — type your own answer.

**2. [Features]** Which features should ship in v1? *(select all that apply)*
   - **a) Auth** — Email + password login.
   - **b) Search** — Full-text search over items.
   - **c) Export** — CSV download.
   - **d) Other** — type your own answer.

Reply like `1a 2ab`, or answer in your own words. Say "defaults" to accept the recommended options.
```

Rendering rules:

- Number questions `1.`–`4.`; letter options `a)`–`e)`; the **last** letter is always
  **Other** — type your own answer.
- Show the header in square brackets before the question.
- Mark multi-select questions with *(select all that apply)*.
- Put nothing after the reply instructions: no work, no tool calls, no "meanwhile I'll…".

### 4b. Stop

**This is the part that makes it a tool call rather than a rhetorical question.** After
rendering, **stop and wait**. Do not guess the answer, do not start the work under an
assumed answer, and do not ask again in the same turn. The user's next message is the
tool result.

### 4c. Parse the reply

Map the user's next message back to answers, one per question:

| Reply | Meaning |
|---|---|
| `1a 2bc`, `1:a, 2:b,c`, `1-a 2-b c` | question 1 → option a; question 2 → options b and c |
| `a` / `b` (only one question asked) | that option |
| `PostgreSQL`, `the first one`, `go with sqlite` | match to the option by label or position |
| `defaults`, `recommended`, `your call` | the `(Recommended)` option for every question that has one |
| any other text for a question | **Other**, with that text as the free-form answer |
| `1c: use DynamoDB` | Other → "use DynamoDB" |

Then:

1. Echo the resolved answers in one compact line, e.g.
   `Got it — Database: PostgreSQL · Features: Auth, Search.`
2. Continue the task using them. Treat free-text "Other" answers as authoritative even
   if they don't match any option.
3. Re-ask **only** the questions that are unanswered, contradictory (two picks on a
   single-select question), or genuinely ambiguous — never the whole set again.
   If the user skips a question with a recommended option, use the recommendation and
   say so.

### 4d. Non-interactive runs

If no human can reply (e.g. `opencode run "…"` in a script or CI, or the instructions say
to proceed without asking), do **not** render and stop. Pick the recommended option for
each question (or the most conventional choice if none is marked), state the assumption
in one line, and continue.

## 5. Worked example

User: "Add caching to the product API."

Cache backend and invalidation policy aren't in the repo and aren't conventional, so ask:

```markdown
**I need your input before I continue.**

**1. [Backend]** Where should cached product responses live?
   - **a) Redis (Recommended)** — Already in docker-compose; shared across instances.
   - **b) In-process LRU** — No new infra; each instance caches separately.
   - **c) Other** — type your own answer.

**2. [Invalidate]** How should stale entries be cleared?
   - **a) TTL of 5 min (Recommended)** — Simple; data may be up to 5 min stale.
   - **b) On write** — Always fresh; needs hooks in every product mutation.
   - **c) Both** — TTL as a safety net plus write-through eviction.
   - **d) Other** — type your own answer.

Reply like `1a 2c`, or answer in your own words. Say "defaults" to accept the recommended options.
```

User replies: `1a, 2 on write but only for price changes`

You: `Got it — Backend: Redis · Invalidate: Other → evict on write, price changes only.`
…then implement.
