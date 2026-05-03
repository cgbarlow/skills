# IR3 form question reference (2026)

A line-by-line cheat sheet for the 42 numbered questions on the 2026 IR3 return. Use as a lookup when running the interview — read only the relevant section.

For the official wording and all edge cases, see `IR3G-2026.txt`. For calculation worksheets, see `worksheets-2026.md`.

---

## Q1–5 Personal information

Name, IRD number, address, DOB. Nothing to calculate. If the user uses a tax agent's postal address, leave the address panel blank.

## Q6 Business industry classification (BIC) code

Only required if self-employed or running a business. If preprinted BIC is wrong or missing, look it up at `businessdescription.co.nz`. Provide the code, not the description.

## Q7

(Reserved / not commonly asked of individuals — confirm against PDF if user asks.)

## Q8 Bank account number

Only the account number, no narration. Suffix can be 2 or 3 digits — pad to first 2 boxes if 2 digits.

## Q9 Adjustments to your income

Tick **9A** if the user has a student loan or claims Working for Families and needs to adjust income. They must then complete an **IR215 Adjust your income** form (downloadable from `ird.govt.nz/forms-guides`). Note: if 9A is ticked, **do not** run the student loan worksheet here — IRD will calculate after they file IR215.

## Q10 Non-residents and transitional residents

- **Non-resident:** away from NZ > 325 days in any 12-month period AND no permanent place of abode in NZ. May need IR3NR instead.
- **Transitional resident:** new NZ tax resident; doesn't have to declare foreign-source income except foreign employment / services income. If they elected NOT to be transitional, they declare worldwide income from the date residency began.

If the user was non-resident for part of the year, also complete **Q41**.

## Q11 Income with tax deducted

Source: **Summary of Income (SOI)**. Includes salary/wages, student allowance, main benefit, ACC earnings-related payments, NZ Super or veteran's pension, other taxable pensions, ESS shares (if employer reported), shareholder-employee salary with PAYE.

Boxes:
- **11A** Total PAYE / tax deducted (from SOI; less ACC earners' levy if amending — see ACC worksheet in `worksheets-2026.md`)
- **11B** Gross earnings — salary/wages
- **11C** Earnings not liable for ACC earners' levy
- **11D** ACC earners' levy
- **11E** Total tax deducted (= 11A − 11D in the worksheet)

If the SOI is correct, copy the SOI totals straight to the boxes. If the user is amending the SOI, run the ACC worksheet.

**Backdated lump sum** income from MSD/ACC/Veterans' Affairs: do NOT enter at Q11; attach the SOI showing the amount and IRD will adjust. The PAYE on backdated MSD lump sums is final tax.

## Q12 Schedular payments

Income that had withholding tax deducted but isn't salary (contractors, directors' fees, some entertainers, real estate agents).

Boxes:
- **12A** Total tax deducted (from SOI)
- **12B** Total gross schedular payments (from SOI; GST-exclusive if registered)
- **12C** Expenses related to schedular payments
- **12D** Net schedular payments = 12B − 12C

Note: ACC clients/caregivers who received PSR payments — see section 9 of `worksheets-2026.md` and the ACC PSR section of `IR3G-2026.txt`.

## Q13 New Zealand interest

From banks, IRD, building societies, credit unions, securities, partnerships/LTCs/trusts, private loans.

Boxes:
- **13A** RWT credits (resident withholding tax)
- **13B** Gross interest
- **13C** Tick if interest came via a partnership/LTC/estate/trust

If user broke a term deposit and paid back interest ("negative interest"), use the broken-term-deposit worksheet (see IR3G text). Joint accounts: only the user's share. Overseas interest goes to **Q17**, not Q13.

## Q14 New Zealand dividends

Boxes:
- **14A** Imputation credits
- **14B** RWT credits on dividends
- **14C** Tick if dividends came via partnership/LTC/estate/trust
- **14D** Gross dividends (= net + imputation credits + RWT credits)

Listed PIE dividends: include only if the PIE used a non-prescribed PIR or the user chooses to include. Bonus shares and non-cash dividends count as income at Q14.

## Q15 Māori authority distributions

Boxes:
- **15A** Māori authority credits
- **15B** Gross taxable distributions

Don't include the non-taxable portion.

## Q16 Estate or trust income

Boxes:
- **16A** Tax paid by trustees
- **16B** Share of estate/complying trust income
- **16C** Taxable distributions from non-complying trusts (attach **IR307**)

If the trust paid out interest, dividends, Māori distributions or overseas income, route those amounts to Q13/14/15/17 instead and tick the relevant "via trust" box.

Foreign or non-complying trust beneficiary: complete **IR307**.

## Q17 Overseas income

Boxes:
- **17A** Total overseas tax credits (in NZD)
- **17B** Total overseas income gross (in NZD)
- **17C** Tick if total includes a foreign super withdrawal/transfer

Required attachment: **IR1261 Overseas income summary** (one section per jurisdiction per income type).

Convert to NZD using IRD rate tables (`ird.govt.nz/managing-my-tax`) or trading-bank rate on day received. Attach proof of overseas tax paid.

Watch out for: foreign superannuation withdrawals (schedule method default; formula method optional for defined-contribution); FIF income (FDR or CV method usually); $50,000 FIF threshold; CFC rules; double-tax-agreement rate caps.

## Q18 Partnership income

Boxes:
- **18A** Partnership tax credits
- **18B** Active partnership income (excl. amounts already at Q13/14/15/17/22/23/25/27)

Sleeping/capital partner income → Q27 instead.

## Q19 Look-through company (LTC) income

Boxes:
- **19A** LTC tax credits
- **19B** LTC active income (with same exclusion logic as Q18)

## Q20 Shareholder-employee salary

Salary received without PAYE deducted. With-PAYE salary belongs in Q11.

## Q21

(Reserved — confirm if the user asks; the tax credit subtotal Box 21A is referenced in the Q36 worksheet at line 12.)

## Q22 Income and expenses from residential property

Boxes 22A–22I (rental income, expenses, ring-fenced losses, bright-line profit).

This question has its own complications (ring-fencing under s EL 20; bright-line test). If the user has rental property, read the "Question 22" section of `IR3G-2026.txt` carefully and consider recommending a tax agent if there are losses to ring-fence or a bright-line sale.

Net profit from a bright-line property sale → **Box 22B** (unless mixed-use asset → Box 25B). Bright-line **losses** are not claimable.

## Q23 Other rental activities (non-residential)

Commercial rentals, etc.

## Q24 Self-employed income

Box 24 — net business income (or loss).

Source: **IR3B Business income** (or **IR3F Farming income**, or **IR10 Financial statement summary**). The IR10 is an IRD-provided summary that speeds processing. Records still must be kept.

Childcare providers may use the standard-cost determination (DET 09/02) if not GST-registered.

## Q25 Income from taxable sales or disposals of property

Box 25A — RLWT credit (residential land withholding tax for offshore RLWT persons).
Box 25B — Profit/loss from land sale or other property disposal not at Q22.

Bright-line residential profits → Q22 (unless mixed-use asset).

## Q26 Government subsidy

Total Covid-19 wage subsidy / extension / resurgence / March-2026 wage subsidy received as an individual (where tax was NOT deducted at source). Resurgence Support Payment (RSP) is **not** taxable — exclude it.

## Q27 Other income

Catch-all: non-FIF share sales, financial-arrangement income, cash jobs / tips / under-the-table / illegal-enterprise income, sleeping-partner share, ESS shares not reported by employer.

## Q28

(ESS-related or similar — confirm against PDF when needed; ESS taxable value goes here if employer didn't report it via Q11.)

## Q29 Other expenses and deductions

Eligible deductions (NOT business expenses — those go inside Q24):
- Tax-return preparation fees
- Commission on interest/dividends (NOT bank fees — private)
- Additional partnership-income expenses (e.g. interest on capital borrowed to buy partnership share)
- Interest on borrowing to buy income-producing investments
- Income-protection (loss-of-earnings) insurance premiums (only if the benefit is taxable)
- Late-payment interest paid to IRD (if not already in business accounts)

Cannot deduct against: salary/wages, election-day work, casual agricultural work, commissions where also paid salary by same employer (with limited carve-outs).

GST-registered: deduct GST-exclusive amounts only.

## Q30 Income after expenses

Calculated: total income − Q29 expenses. Used as net income for IETC eligibility.

## Q31 Net losses brought forward

- **31A** Total losses brought forward (from prior IRD letter)
- **31B** Amount claimed this year

## Q32 Taxable income

Calculated: Box 30 − Box 31B.

## Q33 Independent earner tax credit (IETC)

See the IETC worksheet in `worksheets-2026.md`. Key gates:
- Box 32 (income) between $24,000 and $70,000
- NZ tax resident for the months claimed
- No Working for Families (or overseas equivalent) for those months
- No main benefit / NZ Super / veteran's pension for those months
- Even one disqualifying day in a month disqualifies the whole month

Box 33 = total IETC credit. Box 33C = number of eligible months. Box 33B = date ranges of overseas-income exclusion (if any).

## Q34 Excess imputation credits brought forward

From last year's IRD confirmation letter. Enter at Box 34 and Box 8 of the Q36 worksheet.

## Q35 Portfolio Investment Entity (PIE) calculation

See PIE worksheet in `worksheets-2026.md`.
- **35A** Total PIE deductions (tax already paid)
- **35B** Total PIE income/loss
- **35C** Outcome of correct-PIR calculation (negative = refund of over-paid PIE tax)

If 35C is positive (under-paid PIE tax), it flows into the tax-on-taxable-income worksheet at Box 8.

## Q36 Tax calculation

The big one. Run the full worksheet from `worksheets-2026.md` section 5.
- **Box 36** Tax on taxable income
- **Box 36A** Residual income tax
- **Box 36B** Refund or tax to pay
- **Box 36C** PIE adjustment (if any)

## Q37 Early payment discount

Only applicable to brand-new self-employed people / partnerships who:
- Are new in business (haven't had a provisional-tax obligation in the prior 4 years)
- Derive income mainly from the business
- Made voluntary income tax payments before balance date
- Elect by 31 March of the following year

Walk the flow chart on page 49 of the IR3G text. If unsure, refuse to tick — pointless if they don't qualify.

## Q38 Refunds and/or transfers

Refund options:
- Direct credit to NZ bank account (fastest)
- Transfer to user's own student loan
- Transfer to cover someone else's tax (associated person — see definition in IR3G)
- Transfer to next year's provisional tax

Refunds over $1.00 are direct-credited automatically if Q8 has the bank account.

## Q39 Provisional tax

Required if Box 36A (RIT) > $5,000.

Three options at Box 39A:
- **S** Standard: RIT × 1.05 (default)
- **E** Estimation: estimate 2027 income, work out tax, deduct estimated credits
- **R** Ratio: GST-registered, qualifying, pre-elected

Box 39B = annual amount. Three equal instalments — see worksheet 7 in `worksheets-2026.md`.

## Q40 Foreign rights disclosure

Tick if Q17 included CFC or FIF income. Some jurisdictions/methods exempt — see IR3G page 53 and the April Tax Information Bulletin.

## Q41 Is your return for a part-year?

Yes if: arrived in / left NZ during the year; final return for someone deceased; bankrupt; changed balance date.

Tick the situation and provide start/end dates. IRD calculates the apportioned tax.

## Q42 Notice of assessment and declaration

The user **must** read and sign the declaration. The skill must NOT sign on their behalf, ever. Show the declaration text and tell them to sign in myIR or on the paper return.
