---
name: timesheet
description: "Interactive timesheet entry — collects work description, start/end times via prompts, calculates hours, appends to .campaign/timesheet.md"
user_invocable: true
---

# /timesheet

Update the project timesheet at `.campaign/timesheet.md`.

## Instructions

1. Read the current timesheet from `.campaign/timesheet.md`
2. Display all existing timesheet entries to the user as a formatted markdown table, including a total hours row at the bottom. If the timesheet has no entries yet, say "No entries yet."
3. Use `AskUserQuestion` to collect the following for each entry:
   - **Description**: What work was done
   - **Start time**: When work started (e.g. "9:00 AM", "14:30")
   - **End time**: When work ended (e.g. "11:30 AM", "17:00")
4. Calculate the hours as the difference between end time and start time, rounded to 2 decimal places
5. Append the new row to the markdown table in `.campaign/timesheet.md`
6. Display the updated timesheet to the user

## Timesheet Template

If `.campaign/timesheet.md` does not exist, create it with this content:

```markdown
# Timesheet

## Instructions

When asked to update the timesheet, use the `AskUserQuestion` function to populate the table below. Ask for: description of work, start time, end time. Calculate hours automatically from the times provided.

---

| Description | Start Time | End Time | Hours |
|-------------|------------|----------|-------|
```
