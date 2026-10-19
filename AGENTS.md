# Repository Guidelines

## Project Structure & Module Organization

`Skeval Timer/` contains the macOS app: SwiftUI views, timer and persistence code, analytics, and `Assets.xcassets`. UI prototypes live in `Skeval Timer/Prototypes/`. `Tests/` holds the custom Swift test suite; `HealthChecks/` contains the AppKit runtime check, and `Preview/` has the isolated sample-app entry point. Use `docs/` for feature notes and `docs/adr/` for architecture decisions.

## Build, Test, and Development Commands

The Xcode target requires macOS 26.2 or newer. Open `Skeval Timer.xcodeproj` in Xcode to browse or edit the app.

- `./scripts/run-tests.sh` compiles and runs the domain, persistence, analytics, and lifecycle checks.
- `./scripts/run-tests.sh --runtime-health` runs the AppKit health check with disposable data.
- `./scripts/run-preview.sh` builds and opens the sample preview app with isolated logs.
- `./scripts/run-app.sh` builds and opens the app; pass `--configuration Release` for a Release build.

## Coding Style & Naming Conventions

Use four spaces for Swift indentation. Name types in `UpperCamelCase` and properties, functions, and local values in `lowerCamelCase`; keep source filenames aligned with their main type or feature (for example, `FinishForecast.swift`). Keep calculations and state transitions in domain, analytics, or engine types, and keep views focused on presentation. No formatter or linter is configured.

## Testing Guidelines

Add tests to `Tests/` as plain Swift functions named `test...`, grouped in files by feature (for example, `FinishForecastTests.swift`). Assertions come from `Tests/TestRunner.swift`; tests are compiled together by `scripts/run-tests.sh`, rather than run through XCTest. Cover date boundaries, paused time, and persistence behavior when changing timer or reporting logic.

## Commits and Pull Requests

History uses concise imperative subjects, often with prefixes such as `feat:`, `fix:`, or `refactor:`. Keep commits focused and describe the behavior changed. Pull requests should summarize the user-visible effect and verification performed; include screenshots for UI changes and link a related issue when one exists.

## Architecture Notes

Before changing timer recovery, persistence, or dashboard/window boundaries, read the relevant records in `docs/adr/`. Add or update an ADR when a change establishes a durable architectural decision.
