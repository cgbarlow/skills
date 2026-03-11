# Timesheet

**A Claude skill for tracking time entries via interactive dialogue.**

## Overview

Timesheet is a simple Claude skill that manages a markdown-based timesheet stored at `.campaign/timesheet.md`. When invoked via `/timesheet`, it uses `AskUserQuestion` to collect dates, work descriptions, start times, and end times, then calculates hours, appends the entry, and maintains a weekly summary with a running total.

## How It Works

1. **Invoke** `/timesheet`
2. **Existing entries** are displayed with the weekly summary and running total
3. **Answer** the prompts for date, description, start time, and end time
4. **Hours are calculated** automatically
5. **Entry is appended** to the entries table
6. **Weekly summary** is recalculated (grouped by ISO week)
7. **Updated timesheet** is displayed

## Installation

Place the `SKILL.md` file in your Claude skills directory:
```
.claude/skills/timesheet/SKILL.md
```

Or copy the entire directory into your skills folder.

## License

MIT
