---
name: ir3-tax-return
description: File a New Zealand individual IR3 income tax return for the 2026 tax year by driving the Inland Revenue myIR portal (https://myir.ird.govt.nz/) in the browser. Use whenever the user mentions an IR3, NZ tax return, IRD return, "doing my taxes" or "filing my taxes" in a NZ context, residual income tax, IETC, PIE tax adjustment, ACC earners' levy, schedular payments, or provisional tax — even if they do not say "IR3" by name. The skill pauses for the user to sign in via RealMe, navigates Income tax → Returns and transactions → File return, uses IRD's pre-populated data, prompts inline only for genuinely missing fields or judgement calls, and refuses to click final Submit without an explicit fresh "yes submit". Grounded in the official IR3G (March 2026) guide bundled in references/.
compatibility: Requires a browser-automation runtime that can navigate URLs, click elements, type into form fields, take screenshots, and read on-screen text — for example Claude for Chrome or a Computer-Use environment. In a non-browser runtime, fall back to Section 12 ("Fallback — no browser") and produce a worksheet the user transcribes manually.
---

# IR3 Individual Income Tax Return (NZ, 2026) — myIR auto-filing

This skill files a New Zealand individual **IR3 income tax return** for the year ended **31 March 2026** by driving Inland Revenue's official **myIR portal** at https://myir.ird.govt.nz/. It is grounded in the official **IR3G (March 2026)** guide whose full text is bundled at `references/IR3G-2026.txt`.

The skill operates the browser session. The user supplies authentication, supplies any data IRD hasn't pre-populated, and gives explicit consent before anything is submitted.

---

## 1. Boundaries — read this first

These limits exist because filing a tax return is a legal declaration and the data is sensitive. Do not relax them without an explicit user instruction in the same turn.

- **Never type a password, RealMe credential, MFA code, or 2FA token.** Always pause and let the user enter these themselves. Say so out loud: "I'll wait — please complete RealMe sign-in. Tell me when you're back at the myIR home screen."
- **Never click the final "Submit" / "File return" / declaration-acceptance button without an explicit fresh "yes submit" from the user in the same turn.** Pre-existing consent is not sufficient. The IR3 declaration (Question 42) is a legal statement that the return is true and correct; only the user can swear to that.
- **Never invent a value to fill a blank field.** If a number is missing and IRD hasn't pre-populated it, ask the user. If they don't know, pause and wait — don't guess.
- **Never invent rates or thresholds.** Always read them from `references/worksheets-2026.md`. The 2026 figures differ from prior years.
- **Treat every value on screen as confidential.** Don't paraphrase the user's IRD number, bank account number, or income figures into chat unless necessary to confirm one specific action. Don't write any of this data to a file outside the active myIR session.
- **Don't skip past anything you don't understand.** Screenshot, describe what you see, and ask the user to clarify.
- **If something looks wrong** (figures don't reconcile, a screen doesn't match what's expected, a value the user gave conflicts with what IRD has pre-populated), stop and surface the discrepancy. Don't paper over it.
- **Refuse / escalate** for: foreign superannuation transfers using the formula method or any non-standard FIF method; non-complying trust beneficiary distributions; complex bright-line / mixed-use / land-development situations; bankruptcy returns; deceased-estate finalisation. Recommend the user engage a registered tax agent. Offer to prepare a structured summary instead.

Open the session with a one-line disclaimer the user sees: *"I'll drive myIR for you, but you sign in with RealMe and you give the final 'submit'. I'm not a registered tax agent — I follow the official IR3G 2026 guide, but for anything unusual I'll flag it and suggest you confirm with IRD or an agent."*

---

## 2. What the user needs in front of them

Before navigating to myIR, ask the user to gather (mentally OK if they don't have hard copies — anything in myIR is fine to fetch on the fly):

1. **RealMe login** for myIR (or their myIR username + password if not RealMe).
2. **Summary of Income (SOI)** — IRD usually pre-populates this; user only needs it if they want to cross-check.
3. **RWT certificates / interest statements** from each bank, building society, credit union (often pre-populated; check).
4. **Dividend statements** with imputation credits.
5. **Māori authority distribution statements** (if any).
6. **Investor statements from any PIE / KiwiSaver fund** (to verify PIR is correct).
7. **Business records** — IR10/IR3B/IR3F or own accounts (if self-employed).
8. **Rental property income & expenses** (if any).
9. **Overseas income docs + foreign tax certificates** (if any).
10. **Last year's "loss carried forward" or "excess imputation credits c/f" letter** (if applicable; IRD usually pre-populates these).
11. **Bank account number** for any refund.

Tell the user they don't need to have these all to hand at the start — the skill will pause and prompt when each is needed.

---

## 3. End-to-end browser flow

The exact click path through myIR is in **`references/myir-navigation.md`**. Read it before navigating. The flow at the top level:

1. **Navigate** to `https://myir.ird.govt.nz/`.
2. **Pause for sign-in** (RealMe or myIR credentials, plus 2FA). Wait for the user to confirm they're at the myIR home screen.
3. **Navigate to Income tax → Returns and transactions.** Look for an **Income tax** tile / heading.
4. **Find the 2026 return.** It will be highlighted with a link labelled **"File return (date)"** (e.g. "File return 7 Jul 2026"). Click it to open the IR3 wizard.
5. **Walk the wizard pages in order.** myIR pre-populates personal details, employment income, interest, dividends, Māori authority distributions, PIE income, and known prior-year carry-forwards. For each page:
    - Take a screenshot (or read the page) and describe to the user what's on screen and what's pre-populated.
    - For each editable field, decide: is it pre-filled correctly, blank-but-not-needed (no income of that type), or blank-and-required (need a value)?
    - For blank-and-required fields, prompt the user with the specific question and a hint about where to find the figure ("This is your gross interest from any other accounts not listed above. If you only bank with the institutions above, enter 0.").
    - Use the calculation worksheets in `references/worksheets-2026.md` for any field that needs an arithmetic step (ACC earners' levy, IETC, PIE adjustment, tax on taxable income, student loan repayment, provisional tax). Show the working in the chat so the user can audit.
    - Do **not** click "Next" until the user has confirmed every entry on the page they didn't pre-supply.
6. **Reach the summary / declaration page.** **Do not click submit.** Display every key figure side-by-side from the screen — total income, tax credits, residual income tax (Box 36A), refund or tax to pay (Box 36B), provisional tax for 2027 if any. Ask the user to verify each. Only after they say "yes, submit" verbatim (or equivalent unambiguous consent in the same turn) do you click the final submit button.
7. **Confirm the receipt page** is displayed. Note any reference number / acknowledgement. Tell the user where to find the lodged return in myIR (Returns and transactions → completed) and what the next due dates are (tax to pay 7 Feb 2027; provisional instalments 28 Aug 2026, 15 Jan 2027, 7 May 2027).
8. **Close out:** ask if the user wants to log out of myIR. If yes, click sign-out.

---

## 4. Section-by-section playbook

For each IR3 question, the canonical box numbers, valid values, expected pre-population behaviour, and gotchas are in **`references/form-questions.md`** (one section per question, Q1 through Q42). Read the relevant section just-in-time as the wizard reaches it. Do **not** load the whole file unless you genuinely need it.

The full text of the official IRD guide is in **`references/IR3G-2026.txt`** (extracted from the IR3G PDF). Read targeted sections of it for unusual situations: foreign superannuation, bright-line property, ACC personal-service rehabilitation payments, attribution of personal services income, BETA/CFC/FIF disclosures, etc.

---

## 5. Calculations the skill performs (locally, before typing into myIR)

Always do these in chat first so the user can audit, then type the result into myIR.

| Calculation | When | Worksheet |
|---|---|---|
| Tax on taxable income | After income & expenses are confirmed | §1 of `worksheets-2026.md` |
| ACC earners' levy | Only if amending the SOI | §2 |
| IETC | If income $24k–$70k and the user might qualify | §3 |
| PIE adjustment | If the user's PIR was wrong (under- or over-paid) | §4 |
| Q36 tax calculation | Always, end of return | §5 |
| Excess imputation credits c/f | If imputation credits exceed tax payable | §5a |
| Student loan end-of-year repayment | If user has a student loan and adjusted net income ≥ $500 | §6 |
| 2027 provisional tax | If RIT > $5,000 | §7 |

Show working in plain text so the user can verify before you type. Round per IRD convention (whole dollars in form fields; cents OK in working).

---

## 6. When to pause and prompt the user

These are the moments where you must not proceed silently:

- **Sign-in / 2FA:** wait for explicit "I'm in".
- **Any blank required field:** ask in plain English with context ("How much interest did you receive in total from any banks not already listed? If none, the answer is 0.").
- **A pre-populated value the user might want to amend** (e.g. SOI shows a wrong employer): pause and ask "Does this look right?" before continuing.
- **A judgement call:** PIR selection, whether to estimate or use the standard option for provisional tax, whether to claim IETC for a particular month, whether expenses are "private" vs "income-producing", whether to ring-fence rental losses, etc.
- **Anything you'd flag as an escalation** (see §1 — foreign super, complex bright-line, etc.).
- **Before clicking "next" on a page where you've just calculated something** — confirm the typed values match your shown working.
- **Before the final submit.** Always.

When you pause, say what you're waiting for and what the user should type back. Don't say "let me know when you're ready" without specifying *what* you need.

---

## 7. When the user actually doesn't need to file

If the user's situation looks like only-PAYE-salary plus PIE/KiwiSaver and nothing else (no self-employment, no rentals, no overseas income, etc.), don't push them through the wizard. Tell them they almost certainly get an automatic income tax assessment from IRD and don't need an IR3 at all. Suggest they check `ird.govt.nz/end-of-tax-year` and look in myIR for an existing auto-assessment.

If their only adjustment is a wrong PIR on KiwiSaver, point them at the simpler **myIR PIE square-up** instead of a full IR3.

See "Who needs to file an IR3?" in the IR3G text (around line 122 of `IR3G-2026.txt`) for the full list of triggers.

---

## 8. Handling pre-population mismatches

If the on-screen pre-populated value differs from what the user expects (e.g. SOI shows $48,200 but the user says they earned $52,000):

1. **Don't overwrite silently.** Surface the difference: "myIR shows $48,200 from Acme Ltd; you said $52,000. Should we (a) keep IRD's figure and trust their data, (b) amend it on the return now, or (c) pause so you can check with your employer?"
2. **If they choose to amend:** myIR allows editing the SOI directly inside the wizard. Make the correction, re-run the ACC earners' levy worksheet (§2 of `worksheets-2026.md`), and update Box 11A/11B/11C/11D/11E.
3. **If they're unsure:** stop. The penalty for understating income (or for overstating refund-bearing entries) is real. Recommend they confirm before proceeding.

---

## 9. Privacy and data handling rules

- The user's IRD number, bank account, and income figures are visible to you on screen during this session. They must remain in the session.
- Do not write any of these to disk outside myIR itself. Specifically, do **not** put these values in `references/`, `evals/`, memory files, planning docs, scratch notes, or any local file.
- Do not paste them into chat unnecessarily. When confirming a single specific value (e.g. "you'd like the refund to your Westpac account ending 3421?"), use the last 4 digits, not the full number.
- Do not share screenshots of IRD-screen content with anyone outside the session.
- When the user logs out, treat the session as over — don't reference the figures in subsequent turns.

---

## 10. Failure modes and recovery

| Failure | Recovery |
|---|---|
| myIR session times out mid-flow | Tell the user; pause for re-sign-in; navigate back to the in-progress return (myIR saves progress). |
| A required IRD form attachment is needed (IR1261, IR3B, IR10, IR215, IR307, IR526, IR308, IR3K, IR3F) | Pause; tell the user which form, what it captures, and where to attach it inside the IR3 wizard. Do not fabricate the attachment content. |
| Page layout doesn't match `myir-navigation.md` | The site has updated since this skill was written. Screenshot, describe what you see, and ask the user to point at the equivalent control. Update mental model and continue; mention to the user that the bundled nav reference may need an update. |
| Calculation produces an unexpected result (e.g. negative tax, refund larger than total income) | Stop. Re-show the inputs and re-derive the result with the user. Look for a typo or a misclassified income type. |
| User asks the skill to file someone else's return | Decline. The IR3 declaration must be signed by the taxpayer. |
| User asks the skill to leave income off the return | Decline. The skill exists to help meet tax obligations correctly, not to evade them. Politely explain and recommend a tax agent if they genuinely think a category doesn't apply. |

---

## 11. Closing the session

After successful submission:

1. Read the receipt page; note the acknowledgement / reference number.
2. Tell the user the upcoming dates: tax to pay due **7 Feb 2027** (or 7 Apr 2027 if they have an agent with EOT); provisional tax instalments at **28 Aug 2026 / 15 Jan 2027 / 7 May 2027** (only if Box 36A > $5,000).
3. Tell them how to view the lodged return: **Income tax → Returns and transactions → completed returns**.
4. Tell them to set up a payment method now via **ird.govt.nz/pay** (direct debit, debit/credit card, or internet banking) so they don't miss the 7 Feb 2027 deadline.
5. Offer to help them set up a `/schedule` reminder for the tax-to-pay date and provisional tax instalments.
6. Ask if they want to log out.

---

## 12. Fallback — no browser available

If the runtime has no browser-automation tools (e.g. plain Claude Code in a terminal, or Claude.ai with no Computer-Use), gracefully degrade:

1. Tell the user up-front: *"I can't drive your browser from here, so I'll switch to interview mode and produce a completed IR3 worksheet you can transcribe into myIR. If you can run me in Claude for Chrome instead, I can fill the form for you directly."*
2. Conduct the same section-by-section interview the browser flow would have, in form order.
3. Use the same calculation worksheets in `references/worksheets-2026.md`.
4. Output a single worksheet at the end with every Box value and the arithmetic visible, plus the next-steps checklist (how to enter into myIR, what to attach, payment due dates).

---

## 13. Reference files

- `references/IR3G-2026.txt` — Full extracted text of the official IRD guide (2,553 lines). Read targeted sections only.
- `references/IR3G-2026.pdf` — Original PDF (for the user to consult directly).
- `references/myir-navigation.md` — Click-path through myIR for the IR3 wizard, plus what to do when the layout has shifted.
- `references/worksheets-2026.md` — All official 2026 calculation worksheets and rate tables. **Read this before doing any tax calculation.**
- `references/form-questions.md` — Question-by-question (Q1–Q42) cheat sheet: box numbers, expected pre-population, common mistakes.
- `evals/evals.json` — Test prompts.
