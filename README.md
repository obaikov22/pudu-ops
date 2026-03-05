# PUDU-OPS

![Version](https://img.shields.io/badge/version-2.4.3-7C6AF7?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Android-4ECCA3?style=flat-square)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter)

**Internal shift management tool for Pudu CC1 cleaning robots.**
Built for night-shift operations at Bloomberg London. Handles robot selection, run tracking, template-based scheduling, AI-assisted planning, and shift history — all offline-first with local storage.

> ⚠️ **Disclaimer:** This is a personal operational tool, not an official Pudu Robotics product. It has no direct integration with the robots — all timings are entered manually. Use at your own responsibility.

---

## 📸 Screenshots

> _Screenshots coming soon._

---

## ✨ Features

### 🤖 Robot Management
- Add, edit, and delete robots with name, floor (North/South), and notes
- Enable/disable robots for the current shift with a toggle
- Robot selection automatically syncs with linked cleaning templates
- Cascade delete — removing a robot clears all its run records and templates

### 🧹 Run Tracking
- Start a timed run for any enabled robot from the Today screen
- Automatic transition from **Active → Awaiting Pickup** when time runs out
- Background foreground service keeps timers alive when the app is minimised
- Persistent notification shows all active robots and remaining time
- Local push notification fires when a robot finishes and needs collection
- Manual **Collected** confirmation closes the run

### 📋 Template Scheduling
- Create multi-step cleaning templates per robot (label, zones A–E, duration)
- Schedule templates by start time; start the whole template or individual steps
- Bidirectional sync: toggling a robot on/off also enables/disables its templates

### 📊 Shift History
- Full log of all completed runs, grouped by night shift (20:00–05:00)
- Navigate forward and backward through past shifts
- Per-run detail: robot, floor, step label, start/end time, duration

### 🤖 AI Shift Planner
- Generates an optimised shift plan using the **Claude Sonnet** model (Anthropic API)
- Incorporates robot roster, template steps, break times, wash schedule, and recent run history
- Output rendered as formatted Markdown inside the app
- Language preference (default: Russian); configurable work schedule times

### 💾 Backup & Restore
- Export all robots and templates as a JSON file (shared via system share sheet)
- Import from a JSON backup — upserts by ID, leaves unrelated records untouched

### 🔄 Auto-Update
- Checks the latest GitHub Release on startup
- In-app download and install prompt when a newer APK is available

### 🔒 Access Control
- **Firebase Device Licensing** — devices register automatically on first launch; blocked devices see a hard lock screen with no bypass
- **Remote Disable** — app can be locked remotely by adding `APP_STATUS: disabled` to the GitHub Release description (with an optional custom message via `DISABLED_MESSAGE:`)

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| UI framework | Flutter 3 (Dart), Material 3, dark theme |
| State management | Riverpod (`NotifierProvider`) |
| Local storage | Hive (offline-first, no backend required) |
| Background service | `flutter_foreground_task` v6 |
| Notifications | `flutter_local_notifications` |
| AI planner | Anthropic Claude API (`claude-sonnet-4-6`) |
| Device licensing | Firebase Firestore (`cloud_firestore`) |
| Auto-update | GitHub Releases API + `dio` |
| Backup | `share_plus` (export) + `file_picker` (import) |

---

## 🏗 Architecture

```
lib/
├── core/           # Domain logic (shift window, shift reset)
├── features/       # One file per screen
│   ├── today/      # Active run dashboard
│   ├── robots/     # Robot management + backup UI
│   ├── templates/  # Cleaning template editor
│   ├── history/    # Shift history browser
│   ├── planner/    # AI shift planner
│   ├── settings/   # API key, language, work schedule
│   └── disabled/   # Hard lock screen (remote/device disable)
├── models/         # Hive-persisted models + generated adapters (.g.dart)
├── providers/      # Riverpod controllers
└── services/       # Storage, repositories, notifications, background service
```

**Shift window:** 20:00 → 05:00 (next day). On launch, `ShiftResetService` compares the stored `lastShiftStart` with the current window and resets robot selection if the shift has changed.

**Run lifecycle:** `active` → `awaitingPickup` (auto, via in-app 5 s timer + background 30 s service tick) → `completed` (user taps "Collected").

---

## ⚙️ Setup & Installation

> This app is distributed as a signed APK to authorised devices only. Device access is controlled via Firebase Device Licensing.

### Prerequisites

- Flutter SDK ≥ 3.11
- Dart SDK ≥ 3.x
- Android device (tested on Pixel 9 Pro XL, Android 14+)
- Firebase project (`pudu-ops`) with Firestore enabled
- Anthropic API key (for the AI Planner feature)

### 1. Clone

```bash
git clone https://github.com/obaikov22/pudu-ops.git
cd pudu-ops
flutter pub get
```

### 2. Firebase setup (required — files not included)

`lib/firebase_options.dart` and `android/app/google-services.json` are **not committed to this repository** for security reasons. Generate them locally:

```bash
# Install the FlutterFire CLI if not already installed
dart pub global activate flutterfire_cli

# Generate config files for your Firebase project
flutterfire configure --project=pudu-ops
```

This will create:
- `lib/firebase_options.dart`
- `android/app/google-services.json`

These files are listed in `.gitignore` and must never be committed.

### 3. Regenerate Hive adapters (if models were modified)

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Run

```bash
flutter run                  # debug
flutter build apk            # release APK
```

### 5. App icon (if replacing)

Replace `icon.png` (1024×1024) in the project root, then:

```bash
dart run flutter_launcher_icons
```

---

## 📱 Usage

1. **Robots tab** — add your Pudu CC1 robots with name and floor assignment
2. **Templates tab** — create cleaning schedules with timed steps per robot
3. **Today tab** — toggle robots on for the shift; start runs or individual template steps; monitor countdowns; confirm collection when done
4. **History tab** — review completed runs from any past shift
5. **Planner tab** — enter your Anthropic API key in Settings, then generate an AI-optimised plan for the night

---

## 📦 Version History

| Version | Highlights |
|---|---|
| **2.4.3** | Removed 7-tap unlock bypass — DisabledScreen is now a true hard lock |
| **2.4.2** | Firebase device licensing; blocked-device lock screen |
| **2.4.1** | Remote disable bug fixes (robust regex, unlock flag) |
| **2.4.0** | Remote disable via GitHub Release body (`APP_STATUS`) |
| **2.3.5** | Reset templates on new shift start |
| **2.3.4** | WhatsApp report on step start |
| **2.3.3** | Robot ↔ template bidirectional sync |
| **2.3.0** | AI Shift Planner tab (Claude API) |
| **2.2.x** | Foreground service background timers |
| **2.1.x** | Auto-update via GitHub Releases |

---

## 🔐 License & Distribution

This is a **private internal tool**. The source code is published for reference only.

- APK distribution is controlled via **Firebase Device Licensing** — only registered, active devices can use the app
- The developer reserves the right to remotely disable access to any device at any time
- Redistribution or use outside its intended context is not permitted without explicit permission

---

*Built with Flutter · Powered by Anthropic Claude · © 2026 Oleg Baikov*
