# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**pudu_ops** is an internal Flutter app (display name: **PUDU-OPS**) for managing Pudu CC1 cleaning robots during night shifts (20:00–05:00). It handles robot selection, run tracking, template-based scheduling, and shift history.

## Common Commands

```bash
# Run the app
flutter run

# Build APK (Android)
flutter build apk

# Regenerate Hive model adapters (after modifying models/)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for codegen
dart run build_runner watch --delete-conflicting-outputs

# Regenerate app icon (after replacing icon.png in project root)
dart run flutter_launcher_icons

# Lint
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/path/to/file_test.dart
```

> After any change to `lib/models/*.dart` that involves `@HiveType` / `@HiveField` annotations, you must regenerate the `.g.dart` files with `build_runner`.

## Architecture

### Layer structure

```
lib/
├── core/           # Domain logic independent of Flutter widgets
├── features/       # One folder per screen; each screen is a single file
├── models/         # Hive-persisted data models + generated adapters (.g.dart)
├── providers/      # Riverpod NotifierProviders (state + business logic)
└── services/       # Low-level I/O: Hive storage, repositories, notifications
```

### State management

All state is managed with Riverpod `NotifierProvider<Controller, State>` classes located in `lib/providers/`. Controllers depend on `StorageService` (obtained via `storageServiceProvider`) and coordinate reads/writes through the repository layer in `lib/services/`.

Screens are `ConsumerWidget` / `ConsumerStatefulWidget` and read state exclusively through providers — they do not call repositories or services directly.

### Data persistence

All data is local-only via Hive. `StorageService` (`lib/services/storage_service.dart`) owns four boxes:

| Box | Type | Key |
|---|---|---|
| `robotsBox` | `Box<Robot>` | `robot.id` |
| `runsBox` | `Box<RunRecord>` | `run.id` |
| `templatesBox` | `Box<Template>` | `template.id` |
| `metaBox` | `Box<String>` | arbitrary string keys |

`StorageService` is initialized once in `main()` before `runApp`. Adapters for every Hive model must be registered there when new models are added.

### Hive type IDs (do not reuse)

| ID | Model |
|---|---|
| 0 | `Robot` |
| 1 | `RunRecord` |
| 2 | `RunStatus` (enum) |
| 3 | `Template` |
| 4 | `TemplateTask` |

### Shift logic

A "night shift" window runs from **20:00 → 05:00** (next day). `ShiftInfo calculateShiftWindow(DateTime now)` in `lib/core/shift_logic.dart` determines the current window. On app launch, `ShiftResetService.resetIfNewShift()` compares the stored `lastShiftStart` (in `metaBox`) with the current window and, if changed, resets `selectedForToday = false` on all robots.

### Run lifecycle

`RunRecord` has three statuses: `active → awaitingPickup → completed`.

`RunsController` starts a periodic timer (every 5 s) in its `build()` that auto-transitions `active` runs to `awaitingPickup` when `remainingAt(now) <= Duration.zero`, then triggers a local notification.

### Templates

A `Template` contains a list of `TemplateTask` steps (label, cores `[B–E]`, duration). The user can start the entire template or individual steps from the Today screen. `startMinutes` stores the scheduled start as minutes from midnight (0–1439).

### Backup

`BackupService` (`lib/services/backup_service.dart`) handles export and import of robots and templates as a JSON file.

- **Export**: serialises both boxes to JSON, writes to a temp file, shares via `share_plus` share sheet.
- **Import**: opens a file picker (`file_picker`), parses JSON, upserts robots and templates by ID (existing records with matching IDs are overwritten; others are untouched). After import, both `robotsControllerProvider` and `templatesControllerProvider` must be refreshed.
- Both `Robot` and `Template`/`TemplateTask` models have `toJson()` / `fromJson()` methods for this purpose.
- The backup UI card lives in `robots_screen.dart` (Export / Import buttons).

## Key conventions

- **No routing library** — navigation is a simple `BottomNavigationBar` in `RootScaffold` (`main.dart`). Do not add a router unless explicitly requested.
- **Single-file screens** — each feature screen lives in one file under `lib/features/<feature>/`. Shared UI components do not exist yet; keep new widgets local to the screen file unless clearly reusable.
- **IDs are UUIDs** — generated with the `uuid` package; never use integer indices as persisted IDs.
- **Floor values** are plain strings: `"North"` / `"South"`.
- **Dark theme only** — the app has no light mode. Custom theme colors are defined inline in `main.dart`: primary `#7C6AF7`, secondary/mint `#4ECCA3`, accent `#F0A04B`, background `#0D0F14`.
- **App icon** — source file is `icon.png` (1024×1024) in the project root. Config in `pubspec.yaml` under `flutter_launcher_icons`: adaptive icon with background `#0D0F14`. Regenerate with `dart run flutter_launcher_icons` after replacing the file.
- **Switch toggles** — use `activeThumbColor: Colors.white` + `activeTrackColor: color` (not the deprecated `activeColor`) so the thumb is visible against the coloured track.
