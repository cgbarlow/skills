---
name: timesheet
description: "Interactive timesheet entry — collects work description, date, start/end times via prompts, calculates hours, appends to .campaign/timesheet.md"
user_invocable: true
---

# /timesheet

Update the project timesheet at `.campaign/timesheet.md`.

## Locating the Timesheet

Before creating a new timesheet, search for an existing one using Glob (`**/.campaign/timesheet.md`). If found, use that path. Only create a new one if none exists — create it in the nearest directory that already has a `.campaign/` folder, or in the project root.

## Timezone

The timesheet file may contain a `Timezone:` line (e.g. `Timezone: Pacific/Auckland`). When getting the current time via Bash, always use this timezone: `TZ=<timezone> date '+%Y-%m-%d %I:%M %p'`. If no timezone line is found in the timesheet, ask the user for their timezone using `AskUserQuestion` and add it to the timesheet file (below the Instructions heading).

## Clock In / Clock Out

If the user's arguments contain **"clock in"**:
1. Locate the timesheet and read it
2. Get the current date and time using `date` via Bash **with the configured timezone**, round **down** to the nearest 15 minutes (e.g. 8:37 PM → 8:30 PM)
3. Append a new row with today's date (from the timezone-adjusted time), description `(Clocked in... description pending)`, the rounded start time, and leave End Time and Hours blank (`—`)
4. Do NOT recalculate the weekly summary (the entry is incomplete)
5. Confirm: "Clocked in at {time}."

If the user's arguments contain **"clock out"**:
1. Locate the timesheet and read it
2. Find the most recent entry that has `(Clocked in... description pending)` as its description
3. If no clocked-in entry is found, tell the user and stop
4. Get the current time using `date` via Bash **with the configured timezone**, round **down** to the nearest 15 minutes
5. Use `AskUserQuestion` to collect the **description** of work done
6. Update the entry: replace the description, fill in the end time, calculate hours from start to end time
7. Recalculate the weekly summary and total
8. Display the updated timesheet

## Instructions (Manual Entry)

If the user is NOT clocking in/out, follow this flow:

1. Locate the timesheet using the search strategy above and read it
2. Display all existing timesheet entries to the user as a formatted markdown table, including the weekly summary and running total. If the timesheet has no entries yet, say "No entries yet."
3. Use `AskUserQuestion` to collect the following for each entry:
   - **Date**: The date the work was done (e.g. "2026-02-27", "today", "yesterday"). Default to today if not specified.
   - **Description**: What work was done
   - **Start time**: When work started (e.g. "9:00 AM", "14:30")
   - **End time**: When work ended (e.g. "11:30 AM", "17:00")
4. Calculate the hours as the difference between end time and start time, rounded to 2 decimal places
5. Append the new row to the Entries table in `.campaign/timesheet.md`
6. Recalculate the **Weekly Summary** table — group all entries by ISO week (week starting Monday) and sum hours per week. Update the **Total** line with the sum of all hours.
7. Display the updated timesheet to the user

## Weekly Summary Maintenance

Every time an entry is added, edited, or removed, recalculate the Weekly Summary table above the Entries table. Weeks are identified by their **Monday** start date (ISO week, Mon–Sun). The total hours line below the weekly summary must always equal the sum of all entry hours.

**Calculating the week-starting Monday for a date:**
- Monday → the date itself
- Tuesday → date − 1 day
- Wednesday → date − 2 days
- Thursday → date − 3 days
- Friday → date − 4 days
- Saturday → date − 5 days
- Sunday → date − 6 days

For example, Sunday 2026-03-01 belongs to the week starting Monday 2026-02-23 (subtract 6 days). Monday 2026-03-02 starts a new week. Always use this calculation — do NOT treat the entry date itself as the week start.

## Timesheet Template

If `.campaign/timesheet.md` does not exist, create it with this content:

```markdown
# Timesheet

## How to update

Run `/timesheet` in Claude Code to add entries, or use clock in/out:
- `/timesheet clock in` — starts a new entry at the current time
- `/timesheet clock out` — ends the open entry and prompts for a description
- `/timesheet` — manually add an entry (date, description, start/end times)

Timezone: (ask user)

---

## Weekly Summary

| Week Starting | Hours |
|---------------|-------|

**Total: 0.00 hours**

---

## Entries

| Date       | Description | Start Time | End Time | Hours |
|------------|-------------|------------|----------|-------|
```
