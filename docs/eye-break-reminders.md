# Eye-break reminders

In the dashboard's **Settings → Eye-break reminders**, enable **Remind me to look away** and choose **20, 30, or 45 minutes**. The default is off with a 20-minute interval selected. Preferences persist across launches.

The notification asks you to look at something at least **20 feet (about 6 metres) away for 20 seconds**. Twenty minutes matches common 20-20-20 guidance; 30 and 45 minutes are personal scheduling choices, not established equivalent medical recommendations. See [research and original studies](eye-break-recommendations.md).

## Timing and delivery

- Uses the existing active-sprint tick, with no extra background timer or idle polling.
- Runs only while a sprint is actively ticking. Paused, sleeping, sleep-resolution-held, recovery, and clocked-out states do not send reminders.
- Starting or resuming a sprint, resolving sleep, or changing reminder settings starts a fresh interval. Past work and sleep counted as work do not produce catch-up reminders.
- Midnight and tag edits do not restart an otherwise continuous interval.
- A delayed tick sends at most one reminder and starts a fresh interval from that tick.
- A reminder does not automatically pause work or start a break countdown.
- macOS notification permission is required. The card displays a blocked-permission message when opened if authorization is denied, and links to notification settings. Focus and notification presentation settings can silence banners or sounds.
- Notifications are submitted immediately when due, not scheduled as future repeating requests, so they cannot continue firing after the app exits.

## Verification

`Tests/EyeBreakReminderTests.swift` covers defaults and persistence, supported intervals, due boundaries, duplicate/delayed ticks, configuration changes, backward elapsed time, and view-model integration across pause/resume, sleep counted as work, clock-out and new sprints. Run `./scripts/run-tests.sh`.

Manual delivery check: build and launch the app, enable notifications in macOS, select the 20-minute setting, clock in and leave the sprint active. Confirm one banner with the distance/duration instruction at the interval. Pause or sleep before another interval and confirm that resuming starts a fresh interval. Repeat with 30/45 minutes and verify that disabling the toggle prevents subsequent reminders. This real-time OS-delivery check is not simulated by the unit tests.
