---
name: timesheet
description: "Interactive timesheet entry — collects work description, date, start/end times via prompts, calculates hours, appends to .campaign/timesheet.md"
user_invocable: true
---

# /timesheet

Update the project timesheet at `.campaign/timesheet.md`.

## Instructions

1. Read the current timesheet from `.campaign/timesheet.md`
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

Every time an entry is added, edited, or removed, recalculate the Weekly Summary table above the Entries table. Weeks are identified by their Monday start date (ISO week). The total hours line below the weekly summary must always equal the sum of all entry hours.

## Timesheet Template

If `.campaign/timesheet.md` does not exist, create it with this content:

```markdown
# Timesheet

## Instructions

When asked to update the timesheet, use the `AskUserQuestion` function to populate the table below. Ask for: date, description of work, start time, end time. Calculate hours automatically from the times provided.

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
