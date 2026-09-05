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

## Sprint Engine
The stateful domain engine governing the lifecycle of a Sprint (`idle`, `active`, `paused`, `recovery`),
handling clock ticks, pause intervals, recovery invariants, and milestone notification triggers.

## Day Log Store
The persistence module managing day-grouped sprint logs behind a storage seam
(`DiskDayLogAdapter` for production, `InMemoryDayLogAdapter` for testing).

## Status Presenter
The menu bar visual presenter responsible for rendering state pills (idle, active, paused)
and synchronizing with engine ticks.

