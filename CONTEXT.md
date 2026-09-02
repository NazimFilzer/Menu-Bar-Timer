# Skeval Timer — Domain Glossary

## Sprint
A single, contiguous block of work. Bounded by one Clock In and one Clock Out.
Has: `id`, `startTime`, `endTime?` (nil if open). Duration is computed (`endTime - startTime`).
A sprint always belongs to the calendar day of its `startTime`, even if it crosses midnight.

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

## Clock In
User action that starts a new Sprint, recording `startTime = now`.

## Clock Out
User action that ends the current Sprint, recording `endTime = now`, then copying
`startTime\tendTime` (tab-separated, HH:mm:ss) to the system clipboard.
