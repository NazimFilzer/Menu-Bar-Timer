# Daily timeline

The Today dashboard starts with Timeline selected and saves the last Timeline or
List choice across app launches. The List switch opens the existing sprint
history, with its search, filters, manual entry, and editing. Add sprint beside
Hours opens the same manual entry form with the selected day as its default date.

The timeline shows completed sprints and the current sprint on a vertical clock
scale. A block uses its actual start and end times. Its work total excludes paused
time. Completed pause positions are not available, so the timeline shows only
the paused total. It does not place estimated pauses on the clock.

## Visible hours

The initial range is 06:00 to midnight. Visible hours changes the range for the
selected day. Save default saves the range in app preferences. Reset hours
restores that saved range. Changing the selected day clears the temporary range.
The visible range expands to whole hours to include every sprint on that day.
Expansion does not change the saved default.

The axis uses elapsed time. A daylight-saving transition can produce a 23-hour
or 25-hour day. Hour labels use short 12-hour text, such as 11AM and 12PM. Hover over an hour
to see its time zone and distinguish repeated hours.

## Sprints and gaps

Sprints use names such as Sprint 1, Sprint 2, and Sprint 3, in start-time order
within their start day. A tag appears beside this name. A continuation retains
the same number on the next day. These names are display labels, not stored tags.

The compact timeline uses 64 points per hour in a 400-point scroll area.
Equal time keeps equal space for sprints and gaps.

Untracked gaps use a faint band without a border across the timeline width. Long gaps show
their duration at the center of the visible part, with a time range when space
permits. The label stays visible as the timeline scrolls.

Sprints that overlap appear in separate columns. Blocks also use separate columns
when their minimum height or external active label would overlap on screen.
Columns share the existing timeline width. A group returns to full width once
its blocks and labels have enough space. Each block keeps its exact start position,
and layout does not change recorded times, work totals, or untracked gaps.
A sprint across midnight appears
on both calendar days. Continuation labels state its start day, which still owns
all work in daily totals, earnings, and reports. The timeline does not add new
work or move recorded work between day logs.

Untracked time means no sprint was recorded. It does not establish user inactivity.
Only elapsed gaps get this label. Future time has no work status.

Blocks leave a small visual gap between sprints. Completed blocks keep a minimum height of 18 points so the name and time
range remain visible. Their start positions stay on the clock scale. Very short
completed blocks can extend beyond their exact end position. Sprint labels include the clock time range.
Wide blocks also show net work duration. The active sprint has a green edge
and an Active badge with a dot. A newly started sprint shows its label below
the marker until the block has enough height for the label. Completed state and zero paused time stay in details to keep the
timeline clear. Hover over a block for its status and exact time range.

Select a sprint to open details. Completed sprints use the existing Edit form.
Current sprints expose tag, Pause, and Resume controls. Sleep decision spans stay
unresolved until Count as Work or Count as Paused. Recovery sprints show unresolved
work with Resume and Set End Time actions.

## Updates and focus

Today opens near the current time. Past days open near the first sprint. Now
returns to the current time. Live updates retain the current scroll position.
The view reads the existing engine tick and pause tick. It adds no background
timer and does not monitor keyboard or mouse activity. Idle and recovery views
refresh when viewed or acted on, rather than polling the clock.

## Design source

The agreed design and the original three variants are archived on the
`prototype/daily-timeline` branch under `Preview/daily-timeline-prototype/`.
The implementation spec is `.scratch/daily-timeline/spec.md`.

## Validation

`Tests/DailyTimelineTests.swift` covers actual and net time, gaps, automatic range
expansion, day clipping, continuation attribution, overlap columns, DST boundaries,
settings persistence, and view model state. Tests use disposable settings and
in-memory logs. The existing runtime health check also hosts the Today dashboard.
Screen layout tests cover short adjacent sprints, dense groups, column reuse,
current sprint states, and external active labels.
Run `./scripts/run-preview.sh --timeline` to open a native preview of the reported
short-sprint pairs. The preview uses in-memory logs and separate preferences.
