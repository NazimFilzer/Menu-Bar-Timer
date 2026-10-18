# Skeval Timer

**Current Version:** `v1.2`

A lightweight macOS menu bar sprint timer for tracking work intervals, daily goals, and effective work duration.

## Copy All

Select a day and click **Copy All**, then paste into the sheet's Login cell. It copies one tab-separated row with four columns: Login, Logout, an empty Lunch cell, and Break in minutes. Date and Hours Worked stay in the sheet.

Login is the earliest completed sprint's start. Logout is the latest actual end. Break includes recorded pauses and gaps between completed sprints, calculated as `logout - login - total net work` and rounded to the nearest whole minute, with 30 seconds rounding up. Stored work durations retain their precision. Running and unresolved recovery sprints are excluded until they have an end time. Existing saved logs work without conversion.

## Version Tracking
- **v1.2**: 7-day rolling history navigation via subtle header date dropdown, dynamic past-day target/sprint review, copy-all support for historical logs, and refined focusless dropdown UI.
- **v1.1**: Menu bar timer with sprint clipboard copy, copy-all day log export, live status bar pill, pause/resume tracking, daily goal progress, local persistence, crash recovery, and customizable themes.
- **v2 (In Development)**: Desktop dashboard, weekly/monthly analytics, hourly earnings tracking, tag classification, and sleep/wake gap resolution.
