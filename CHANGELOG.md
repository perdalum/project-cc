# Changelog

## Version 1.3.0 — First Release

### Settings

- Added a standard macOS Settings window
- Added configurable persistent storage file selection using the native macOS file picker
- Added the standard app-menu Settings entry with `Command-,`

### Persistence

- State changes with a required or optional comment now also append a Note entry mirroring the transition and comment text
- `ProjectStore` now follows the configured persistent storage file and reloads immediately when the storage path changes

### Project Property View

- Replaced the inline note input with a dedicated Add Note sheet
- Touch history now shows the full list of recorded touch timestamps instead of only the latest touch

### Documentation

- Added a repository `README.md` with product overview, screenshots, build instructions, and development notes
- Added publication-safe `mock-projects.json` demo data

### Infrastructure

- Added `AppSettings.swift` and `SettingsView.swift`
- Added store coverage for switching persistence files at runtime
- Regenerated the Xcode project to include the new Settings-related source files

## Version 1.3.0 — Legacy Import

### Utilities

- Added `scripts/convert_project_control_center.py` to convert legacy `ProjectControlCenter.json` data into the JSON array format used by Project Command And Control
- Converter maps legacy notes, touches, next dates, modified/created/review timestamps, and folder URLs into the current project schema
- Fields not available in the legacy file are left empty in the converted output

### Assets

- Added a proper macOS `Assets.xcassets/AppIcon.appiconset`
- App icon set can now be generated from a supplied `icon.png` source image and compiled into `AppIcon.icns`

### Infrastructure

- Regenerated the Xcode project so the asset catalog is included in app builds

## Version 1.2.0 — Visual Overview

### Overview View

- **Swift Charts overview**: replaced the placeholder with a graphical activity dashboard built as a per-project swim-lane heatmap
- **Time range picker**: added `1d | 1w | 1m | 3m | 6m | all`, defaulting to `1w`
- **Shared filtering**: Overview now uses the same name filter grammar and state filter model as the Project List View
- **Per-bucket totals**: added summary counts for total touches in each visible hour/day/week/month bucket
- **Context switching**: added a bottom summary strip counting true project-to-project switches within each bucket based on chronological touch order
- **Lane highlighting**: clicking a heatmap cell highlights that project lane for easier visual tracing
- **Empty states**: Overview now distinguishes between “no matching projects” and “no activity in range”

### Project List View

- **Shared filter implementation**: list filtering now uses the same shared helper layer as Overview so both screens stay in sync

### Infrastructure

- Added `OverviewSupport.swift` for shared state filters, text filtering, time ranges, and overview bucketing/aggregation
- Added `OverviewSupportTests.swift` covering filter grammar, bucket generation, totals, hourly/day/week behavior, and true switch counting
- Regenerated the Xcode project so the new overview support source and tests are included in app and test targets

## Version 1.1.0 — List Done

### Project List View

- **Column customisation**: drag columns to reorder; right-click header to show/hide; configuration persisted across launches
- **Folder column**: `folder` / `folder.fill` SF Symbol (blue when set). Click opens folder in Finder; if unset, opens a folder picker with New Folder support
- **Terminal column**: `terminal.fill` SF Symbol. Click opens folder in Terminal.app; disabled when no folder is set
- **URL column**: `safari` / `safari.fill` SF Symbol (accent colour when set). Click opens URL in default browser; if unset, prompts for a URL via inline popover
- **State filter** dropdown with individual states and virtual grouped states (displayed at top, emphasised):
  - *Init*: New, Idea
  - *Not Done*: Idea, New, Active, Delegated, Waiting
  - *Started*: Active, Delegated, Waiting
  - *Done*: Rejected, Done
- **Next column background colour** indicates urgency: light green = today, light orange = within 3 days, light red = overdue
- **Next date picker**: added Clear button to unset the date
- **Row selection**: click selects row(s); shift-click extends range; command-click toggles individual rows
- **Double-click on Name** opens the Project Property View window
- **Context menu** (right-click / Ctrl-click) on selected rows: Touch, Set Next, Clear Next, Set State, Delete
- **Multi-row state change**: context menu state actions apply to all selected rows; states requiring a comment show a single prompt applied to all

### Data Model

- `ProjectState.requiresComment` now includes `.rejected` (previously only Delegated and Waiting)

### Persistence

- Every mutation (field edit, state change, note, folder, URL, next date, touch) now stamps **both** `modified` and `touched`, giving a complete interaction history

## Version 1.0.0 — Base Release

### Data Model

- **Project** entity with full set of properties: Name, Category, Project Type, State, Start, End, Modified, Created, Folder, URL, Goal, Notes, Touched, Latest Review, Next
- **ProjectState** enum: Idea, New, Active, Delegated, Waiting, Rejected, Done
  - State changes to Delegated, Waiting, and Rejected require a mandatory comment
  - States are `Comparable` in workflow order for correct table sorting
- **ProjectType** enum: Classical Project, Area of Responsibility
- **LogEntry**: auto-appended on every state change; records old state, new state, date, and comment
- **Note**: timestamped free-text entries, multiple per project
- **Touched**: append-only list of timestamps recording when a project was last interacted with

### Persistence

- JSON file at `~/Documents/ProjectCommandAndControl/projects.json`
- Written immediately on every mutation (no explicit save step)
- ISO 8601 date encoding
- Backward-compatible decoding: legacy JSON without `created` field decodes without error (falls back to `Date.distantPast`)

### Project List View

- Sortable table with all columns (click any column header to sort)
- **Column customisation**: drag columns to reorder; right-click header to show/hide; configuration persisted across launches
- **Filter bar**: text search on Name with Boolean grammar (`-word` = NOT, `word|word` = OR, space = AND)
- **State filter** dropdown with individual states and virtual grouped states:
  - *Init*: New, Idea
  - *Not Done*: Idea, New, Active, Delegated, Waiting
  - *Started*: Active, Delegated, Waiting
  - *Done*: Rejected, Done
- **Folder column**: `folder` / `folder.fill` SF Symbol (blue when set). Click opens folder in Finder; if unset, opens a folder picker
- **Terminal column**: `terminal.fill` SF Symbol. Click opens folder in Terminal.app; disabled when no folder is set
- **URL column**: `safari` / `safari.fill` SF Symbol (accent colour when set). Click opens URL in default browser; if unset, prompts for a URL via inline popover
- **Name column**: click opens the Project Property View window for that project
- **State column**: menu to change state inline; states requiring a comment show an alert prompt
- **Next column**: click opens an inline date-time picker popover with Set and Clear buttons. Background colour indicates urgency:
  - Light green — due today
  - Light orange — due within 3 days
  - Light red — overdue
- **Touched column**: click appends current timestamp
- **Note column**: displays latest note; click opens an inline text input popover to add a new note; shows `—` when empty
- **Adaptive date formatting** (Finder-style) on Next and Touched: format degrades gracefully as column is narrowed — `Today at 2:34 PM` → `Today, 2:34 PM` → `2:34 PM` → `Mar 29, 2026` → `3/29/2026` → `3/29`

### Project Property View

- Opens as an independent window per project (multiple projects can be open simultaneously)
- Re-opening an already-open project brings its window to front
- Auto-saves on every field change — no explicit Save/Cancel
- **Identity section**: Name, Category, Project Type, State
- **Dates section**: Start, End, Latest Review, Next (all with date-time pickers), plus read-only Modified and Created timestamps
- **Links section**: Folder (with Choose…/Change…/Remove via macOS folder picker with New Folder support), URL
- **Goal section**: multi-line goal text editable in a dedicated sheet
- **Notes section**: full timestamped note history (newest first) plus inline add
- **State Log section**: full history of state transitions with timestamps and comments
- **Touched section**: Touch Now button and last-touch timestamp

### Infrastructure

- Swift 6.0, SwiftUI, macOS 26 minimum deployment target
- `build.sh` builds to `/tmp` to avoid iCloud Drive xattr codesign conflicts; copies signed `.app` to `dist/` and launches it
- Xcode project generated from `project.yml` via `xcodegen`
- **23 unit tests** using Swift Testing (`import Testing`, `#expect`), covering model defaults, Codable round-trips, store CRUD, and all domain operations
