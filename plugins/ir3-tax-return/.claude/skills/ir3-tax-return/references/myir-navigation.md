# myIR navigation reference — IR3 filing

Last verified against the user's description: **3 May 2026**. The myIR site is updated by IRD periodically; if the on-screen labels or layout don't match this guide, screenshot, describe what you see to the user, ask for guidance, and continue. Do not invent click targets.

This file is loaded only when the skill is actively driving the browser.

---

## Entry point

URL: **https://myir.ird.govt.nz/**

The page should show the myIR sign-in landing screen. The user has two sign-in routes:

- **RealMe** — most common. The user clicks the RealMe button and is redirected to the RealMe identity provider, where they enter their RealMe username, password, and any 2FA. RealMe is operated by the NZ Department of Internal Affairs; **never** type credentials on the RealMe page.
- **myIR username + password** (legacy / non-RealMe). Same rule — never type credentials.

After authentication the user lands on the myIR home dashboard.

### Pause behaviour for sign-in

```
Action: navigate to https://myir.ird.govt.nz/
Action: take a screenshot so the user can see you're at the right page
Say: "I'm at the myIR sign-in page. Please click RealMe (or myIR login) and complete sign-in including any 2FA. Tell me when you're back at the myIR home screen — say 'I'm in' and I'll continue."
WAIT for the user's confirmation. Do not proceed.
```

If the user signs in and you observe a different landing screen than expected, screenshot it and ask for direction.

---

## From the home dashboard to the IR3 wizard

The user's described path is:

1. From the home dashboard, look for a tile or section heading labelled **"Income tax"**. There may also be tiles for KiwiSaver, GST, Working for Families, etc. — make sure you click the Income tax one.
2. Inside Income tax, find and click the **"Returns and transactions"** link / tab.
3. The Returns and transactions screen lists all return periods. Returns due will be highlighted with link text along the lines of **"File return (date)"** — for the 2026 tax year this will be something like **"File return 7 Jul 2026"** for the period ended **31 Mar 2026**. Click that link.
4. The IR3 return wizard opens. It will be a multi-page form, paginated by section (personal details → income → deductions → tax credits → calculation → declaration).

### What to do if labels differ

If the dashboard uses different wording — e.g. "My income tax", "Returns due", "File now" — match by intent rather than exact string. Screenshot, describe the choices to the user, and ask "this looks like the same thing — proceed?"

---

## Inside the IR3 wizard

The wizard typically progresses through pages in roughly this order. The exact split between pages varies; treat this as a checklist of sections rather than a strict page count.

| Wizard section                          | Maps to IR3 questions   | Pre-population behaviour                                           |
|-----------------------------------------|-------------------------|--------------------------------------------------------------------|
| Personal details                        | Q1–Q5                   | Pre-filled from IRD's records; user confirms or edits.             |
| Bank account                            | Q8                      | Pre-filled if previously provided.                                 |
| Income adjustments / IR215 trigger      | Q9                      | User decides whether to tick.                                      |
| Residency status                        | Q10                     | User confirms.                                                     |
| Income with tax deducted (SOI)          | Q11                     | Pre-filled from employers' PAYE filings; user can edit.            |
| Schedular payments                      | Q12                     | Pre-filled from payer reports; user adds Box 12C expenses.         |
| NZ interest                             | Q13                     | Often pre-filled from RWT-payer filings; check coverage.           |
| NZ dividends                            | Q14                     | Often pre-filled from companies' RWT filings.                      |
| Māori authority distributions           | Q15                     | Pre-filled if reported.                                            |
| Estate / trust income                   | Q16                     | User enters; may need IR307 attachment for non-complying trusts.   |
| Overseas income                         | Q17                     | User enters; requires IR1261 attachment.                           |
| Partnership / LTC / Shareholder-emp     | Q18, Q19, Q20           | User enters from K1-equivalents / company records.                 |
| Residential property                    | Q22                     | User enters; ring-fencing and bright-line rules apply.             |
| Other rental                            | Q23                     | User enters.                                                       |
| Self-employed income                    | Q24                     | User enters from IR3B / IR3F / IR10 or own accounts.               |
| Property sales                          | Q25                     | User enters; RLWT credit pre-populated if applicable.              |
| Government subsidy                      | Q26                     | User enters Covid wage subsidy amounts not run through payroll.    |
| Other income                            | Q27                     | User enters; ESS shares not reported by employer go here.          |
| Other expenses                          | Q29                     | User enters.                                                       |
| Net losses brought forward              | Q31                     | Pre-filled from prior-year loss letter.                            |
| Tax credits — IETC                      | Q33                     | myIR may auto-calculate from income; cross-check with §3 worksheet.|
| Excess imputation credits b/f           | Q34                     | Pre-filled from prior-year letter.                                 |
| PIE adjustment                          | Q35                     | Pre-filled from PIE filings; verify PIR is correct.                |
| Tax calculation                         | Q36                     | Auto-calculated by myIR; cross-check with §5 worksheet.            |
| Early payment discount                  | Q37                     | User ticks if eligible (rare; flow chart in IR3G text).            |
| Refunds / transfers                     | Q38                     | User chooses direct credit or transfer.                            |
| Provisional tax                         | Q39                     | myIR offers Standard / Estimation / Ratio; pick per §7 worksheet.  |
| Foreign rights disclosure               | Q40                     | Trigger only if Q17 had FIF/CFC income.                            |
| Part-year                               | Q41                     | Tick only if applicable.                                           |
| Declaration                             | Q42                     | **Final submit — requires explicit user "yes submit".**            |

### Per-page operating procedure

For each wizard page:

1. **Read the page.** Take a screenshot or extract the visible text. Identify all editable fields and pre-populated values.
2. **Describe to the user** what's on the page in 1–2 sentences. Don't dump raw screen text.
3. **For pre-populated fields:** ask "myIR has $X here from [source]; confirm or amend?"
4. **For blank fields the user has income/expenses for:** prompt with a focused question and the source ("How much interest from accounts not on the list above?").
5. **For blank fields the user has nothing for:** enter 0 / leave blank as the form requires (some require an explicit 0; others accept blank — observe the form's validation).
6. **For calculated fields** (IETC, PIE adjustment, tax-on-taxable-income, student loan, provisional tax): run the relevant worksheet from `worksheets-2026.md` in chat first, show the working, then type the result.
7. **Before clicking "Next" / "Continue":** read the typed values back to the user and ask "ready to advance?"
8. Click "Next".

If a page has many fields and most are blank, batch the "anything for X, Y, Z?" qualifier into one question. If the user says "no for all", fill zeros and move on.

---

## The declaration page (Q42)

This is the only page where the rules are absolute.

1. **Do not click submit.**
2. Read the entire summary on screen and reproduce the key figures in chat:
   - Total income (Box 30)
   - Taxable income (Box 32)
   - Total tax credits
   - Tax on taxable income (Box 36)
   - Residual income tax (Box 36A)
   - Refund or tax to pay (Box 36B); if tax to pay, the due date
   - 2027 provisional tax (Box 39B) and three instalment amounts, if applicable
   - Student loan end-of-year repayment, if applicable
3. Read the declaration text on screen out loud (paraphrased): the user is declaring the return is true and correct, that they are the taxpayer, and that they understand penalties apply for false statements.
4. Ask: *"Are these figures correct, do you accept the declaration, and do you want me to click submit? Please reply with an unambiguous 'yes submit' if so."*
5. Only on receipt of an explicit, fresh "yes submit" (or close paraphrase that is unmistakably consent — *not* "ok", *not* "go ahead", *not* "sure" — needs to be a clear submission instruction tied to this filing) do you click submit.
6. After clicking, wait for the receipt page. Read the acknowledgement / reference number to the user.

If the user wants to edit something after reviewing, navigate back via the wizard's "Previous" / "Edit" links — do not refresh or close the wizard, which can lose progress.

---

## Common interactive elements

- **"Save and exit"** / **"Save draft"** — myIR saves a partial return. The user can come back later. Use this if the user wants to pause beyond a few minutes (e.g. needs to fetch a document).
- **"Add another"** — present where the user can list multiple items (multiple PIE investments, multiple overseas income sources, multiple rental properties). Always ask "any more to add?" before clicking Next on a page that allows multiples.
- **"Attach document"** — for IR1261, IR3B, IR10, IR215, IR307, IR526, etc. The user must have these files ready. Pause and prompt; describe what each form captures (use `form-questions.md`). Do not fabricate.
- **Validation errors** (red text after Next): read the error to the user, identify the field, fix together, retry.
- **Session timeout warning** — usually a banner at, say, 25 min idle. If you see it, click "extend" if available, otherwise tell the user to re-authenticate.

---

## Sign-out

When the user is done:

1. Find the user-menu / avatar control in the top-right of myIR.
2. Click "Sign out" or "Log out".
3. Confirm the sign-out confirmation page is shown.

Do not navigate away to another tab while still authenticated.

---

## When this guide is wrong

Inland Revenue updates the myIR UI from time to time. If you observe a layout, label, or flow that doesn't match this guide:

1. **Don't guess.** Screenshot. Describe to the user what you see.
2. Ask the user to point at the equivalent control ("there's no 'Returns and transactions' tab — what looks closest?").
3. Continue once the user has confirmed the equivalent path.
4. Tell the user: "FYI the myIR navigation reference in this skill is out of date; worth a refresh next time." (You can offer to capture the new path into a note for them.)
