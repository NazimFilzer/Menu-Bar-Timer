# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

The app is actually a native **macOS** app (SwiftUI + AppKit, macOS 26.2+). `ios` is recorded only because Impeccable has no macOS value, and it is the closest match for the Apple/SwiftUI design language the app renders. Apply Apple HIG and SwiftUI guidance in their macOS form: menu bar extra and popover, sidebar window, pointer and keyboard input, system controls. Ignore iPhone-only advice such as touch-target minimums, tab bars, safe areas, and Dynamic Type sizing.

## Users

One user: the developer, who uses it as a personal tool on their own Mac. No other users are planned. Design for this person's workflow; there is no audience to persuade and no onboarding for strangers.

They track their own working hours across a workday because three things depend on them:

- **Hourly billing**: they are paid by the hour, so the earnings figure must be trustworthy.
- **Employer timesheet**: every day they fill in a company sheet (Login, Logout, Lunch, Break). Copy All supplies that row.
- **Hitting daily hours**: they need to know whether they've reached their target hours for the day and week, and when they can stop.

## Product Purpose

Skeval Timer is a menu bar work timer with a desktop dashboard. It records sprints (clock in to clock out, with pauses), totals them per day, week, and month against goals, turns them into earnings at an hourly rate, and exports paste-ready timesheet rows.

Success means the user can glance at the menu bar and know their state, start, pause, or stop with no friction, answer "am I on track, and when can I finish?" at a glance, and paste the day's timesheet row without retyping or fixing anything.

## Positioning

- **Local and private**: no account and no cloud. All data stays on this Mac in the app's sandbox container.
- **Zero battery cost**: no idle polling and no background timers. It reacts only to the active 1-second sprint tick and macOS sleep/wake notifications (ADR 0003).
- **Paste-ready timesheet**: Copy All produces exactly the four tab-separated cells the user's sheet expects (Login, Logout, empty Lunch, Break in minutes), with no headers and no reformatting.

## Operating Context

- It lives in the menu bar as an accessory app with no Dock icon. The dashboard window adds Dock and Cmd+Tab presence only while it is open (ADR 0001).
- It runs all workday in the background, alongside whatever the user is working in. It gets quick glances and clicks, not long sessions.
- The dashboard is for review and correction: Today, Week, Month, Analytics, Settings, plus manual sprint entry, editing, tags, and CSV export.
- Output goes to an external spreadsheet through the clipboard: the daily timesheet row, individual sprint copy using effective end times, and CSV export.
- When the Mac sleeps mid-sprint, the timer holds on wake until the user decides whether the sleep counts as work or as paused time (ADR 0002).
- Global shortcuts: Cmd+Opt+Shift+C to clock in or out, Cmd+Opt+Shift+P to pause or resume. Cmd+1–5 switches dashboard pages.

## Capabilities and Constraints

- Domain terms are defined in `CONTEXT.md` (Sprint, Day Log, Recovery Sprint, Catch-up target, Finish-time forecast, Upcoming breaks, Eye-break reminder, and so on). UI copy must use that vocabulary.
- Sprints belong to the day they started, even when they cross midnight. Weekly, monthly, and report totals use completed sprints; daily totals also include the active sprint.
- Schedule-aware pacing (catch-up card, finish-time forecast, weekly pace) is a core capability, but the user did not name it as a differentiator.
- Eye-break reminders (20-20-20 rule) use macOS notifications, are off by default, and only fire while a sprint is actively ticking.
- Technical constraints: Apple frameworks only, with no third-party dependencies. Hidden SwiftUI content must not stay mounted. Values that change every tick go in `Live { … }` so only that piece re-renders (see AGENTS.md).
- Tags exist, but organising work across multiple clients or projects is not a primary job.

## Brand Commitments

- Name: **Skeval Timer**. Current version v2.3.
- It ships user-selectable themes (`AppTheme.swift`). The visual system is not recorded here; `DESIGN.md` owns it.

## Evidence on Hand

- Real usage history lives only in the user's sandbox container (`logs.json`). Never read, sample, or modify it for design work.
- Sample data comes from the isolated preview app (`./scripts/run-preview.sh`). A static layout exploration is in `Prototype/today-layout-prototype.html`.
- There are no testimonials, customers, pricing, or distribution claims. This is a personal tool; don't invent any.

## Product Principles

1. **Glanceable first.** The menu bar and popover answer "what state am I in, and how much have I done?" in one look. Detail lives in the dashboard.
2. **Numbers must be exact and trustworthy.** Earnings, totals, and timesheet rows feed real pay and a real employer sheet. Clear, correct figures beat visual flourish.
3. **Out of the way.** No nagging, no background cost, no attention-seeking motion. The app runs all day beside real work.
4. **Native Mac behaviour.** System controls, keyboard shortcuts, and macOS conventions come before custom chrome.
5. **The user decides ambiguous time.** Sleep, recovery, and breaks are never silently counted. The UI asks, and it states what each choice does.
