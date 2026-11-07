# Week, Month, and Analytics insights

The Week page compares work from Monday through the current day with the same part of the previous week. Saturdays and Sundays count. The default comparison ends last week's matching day at the current local clock time. The toggle can include that whole day instead. Historical weeks compare all seven start days.

A sprint belongs to its start day, including across midnight. Active and paused sprints contribute the engine's current net work on that day. Recovery sprints remain excluded until resolved. If the comparison cuts through a completed sprint with paused time, the report spreads paused time evenly across the sprint and labels the result as an estimate. Exact pause timestamps are not stored.

Daily goal consistency appears below Monthly Activity in the Month tab and uses the selected month. It is no longer loaded in Analytics. Sprint patterns use the selected Analytics date range and appear below the productivity trend chart.

Goal grid rows are labelled Week 1, Week 2, and so on within each month. Each row also shows its Monday start date. Week 1 contains the first day of the month and starts on its Monday, displaying all recorded days in that week.

## Daily goal rate

Each week's consistency rate is measured against its finished scheduled working days (defaulting to Monday through Friday, e.g. `0/5`, `3/5`). Today and later days join the denominator only once they are over. Saturday and Sunday are treated as extra time: work on weekends never inflates the required days denominator and is never penalized as a missed goal. Reaching the daily goal on a weekend or day off counts as an extra met goal day in the numerator. Unscheduled days with partial work display the net hours worked as extra time.

Today stays in progress and past days use the current daily goal and working schedule. The card states these details in its footnotes.

## Sprint patterns

Only completed sprints in the selected period contribute. All durations exclude pauses. The card shows median, mean, longest sprint, and counts in six duration groups. Bucket boundaries use exact seconds. It also shows the share of sprints with pauses, mean paused time, and mean pause count across all completed sprints. Empty data shows a prompt to record a completed sprint.

A long sprint does not prove uninterrupted work. No activity monitoring, additional timer, or persistence change is used.

## Design source and checks

Selected layout D combines Week option B, daily goal option C, and sprint patterns option A. The original prototype is archived on branch `prototype/insights-selected` at `c10c7a350740`.

`Tests/WorkInsightsTests.swift` covers weekend work, scheduled weekends, days off, partial and future ranges, current-day exclusion, net sprint durations, bucket boundaries, empty data, legacy pauses, overnight attribution, current net work, prior-week clock cuts, DST, and year boundaries. Test logs use in-memory storage and isolated settings.
