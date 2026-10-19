# Skeval Timer — Domain Glossary

## Sprint
A single, contiguous block of work. Bounded by one Clock In and one Clock Out.
Has: `id`, `startTime`, `endTime?` (nil if open). Duration is computed (`endTime - startTime`).
A sprint always belongs to the calendar day of its `startTime`, even if it crosses midnight.
_Avoid_: Work Log, Session, Task

## Day Log
All sprints for one calendar day, keyed by the date of each sprint's `startTime` (`yyyy-MM-dd`).
Persisted in a JSON file in Application Support. Loaded on launch; filtered to today.

## Accumulated Total
The sum of durations of all **completed** sprints in today's Day Log.
Does **not** include the currently running sprint's elapsed time.

## Recovery Sprint
An open sprint (has `startTime`, no `endTime`) found in the persisted Day Log on app relaunch.
Indicates the app was quit or crashed while a sprint was in progress.
Resolved by: **Resume** (timer resumes from original startTime) or **Set End Time** (manual entry).

## Daily Goal
A configurable target for Accumulated Total per day. Default: 8 hours.
Progress = Accumulated Total ÷ Daily Goal.

## Weekly Goal
A configurable target for total accumulated work duration across a 7-day calendar week.
_Avoid_: Week Target

## Monthly Goal
A configurable target for total accumulated work duration across a calendar month.
_Avoid_: Month Target

## Hourly Rate
A configurable monetary rate applied per hour of completed work duration.
_Avoid_: Wage, Pay Rate

## Earnings
The monetary value calculated by multiplying completed work duration by the Hourly Rate.
_Avoid_: Income, Revenue

## Tag
A lightweight text label assigned to a Sprint to categorize work (e.g., #client, #dev).
_Avoid_: Category, Project, Kanban Task

## Sleep Interval
A contiguous period during an active Sprint when macOS was in a system sleep state, bounded by recorded sleep and wake timestamps.
_Avoid_: System Pause, Idle Gap

## Catch-up target

The daily goal multiplied by scheduled working days from the start of the current Monday-based week or calendar month through today. Default working days are Monday–Friday; individual days off remove that day's expected hours. The shortfall subtracts completed sprint durations and the active sprint's net elapsed time within the period. Work logged on non-working days still counts. Extra work is shown as hours ahead. Recovery time is excluded until resolved. This target is independent of configured weekly and monthly goal totals.

## Scheduled working days and days off
The configurable weekdays (default Monday–Friday) and specific calendar dates marked as off. Used by catch-up calculations and weekly pacing to compute expected working days and remaining pace without altering stored sprints.

## Finish-time forecast
An estimated completion time displayed on the Today dashboard indicating when the Daily Goal will be met. Calculated as `now + remaining net work + upcoming breaks`. Hidden during unresolved sleep or recovery.

## Upcoming breaks
A temporary planning allowance (0–240 minutes, in 5-minute increments, default 0) factored into the Finish-time forecast. Does not modify sprint durations, pause the timer, or auto-clock-out. Resets on day rollover or app relaunch.

## Eye-break reminder
A non-intrusive notification reminding the user to rest their eyes (look at an object at least 20 feet away for 20 seconds, following the 20-20-20 rule) after a configured interval of active sprint work (20, 30, or 45 minutes). Piggybacks on the active engine tick without extra background timers or idle polling.

## Clock In
User action that starts a new Sprint, recording `startTime = now`.

## Clock Out
User action that ends the current Sprint, recording `endTime = now`, then copying
`startTime\tendTime` (tab-separated, HH:mm:ss) to the system clipboard.

## Paused Duration
Total duration a sprint spent in a paused state, excluded from net work duration so
`(endTime - startTime - pausedDuration)` equals net work duration.

## Effective End Time
The virtual end time `(endTime - pausedDuration)` formatted for clipboard export so
external spreadsheets compute net work duration directly via simple subtraction.
Used by individual sprint copy and CSV export.

## Daily timesheet row

Copy All in the Today dashboard, menu bar popover, and popover context menu exports
one tab-separated row for the selected day: first Login, last actual Logout, an
empty Lunch cell, and Break in whole minutes. Only completed sprints contribute.
Break is `(last logout - first login) - total net work`, including pauses and gaps
between sprints, rounded to the nearest minute with 30 seconds rounding up.
Stored durations retain their precision. Date and Hours Worked belong to the sheet.

## Sprint Engine
The stateful domain engine governing the lifecycle of a Sprint (`idle`, `active`, `paused`, `recovery`),
handling clock ticks, pause intervals, recovery invariants, and milestone notification triggers.

## Day Log Store
The persistence module managing day-grouped sprint logs behind a storage seam
(`DiskDayLogAdapter` for production, `InMemoryDayLogAdapter` for testing).

## Status Presenter
The menu bar visual presenter responsible for rendering state pills (idle, active, paused)
and synchronizing with engine ticks.

## Version tracking

- v2.0 is the current version on the v2 branch. It combines main's live daily earnings, recent-day history, manual entry, pause hotkey, exact timer math, and day rollover with v2's tags, dashboard editing, sleep resolution, weekly and monthly analytics, and CSV reports.
- Main remains at v1.2. Work on v2 does not modify main.

## Daily totals and reports

Daily totals include completed sprints plus the active sprint when its start day is today. Historical daily totals and weekly, monthly, and analytics reports use completed sprints. Earnings use the configured currency and hourly rate. A sprint belongs to its start day even when it crosses midnight.

## Sleep decision hold

The timer stays held after wake until sleep is classified as work or paused. When resolved as work, both the sleep interval and the decision delay count as work. When resolved as paused, both count as paused duration.
