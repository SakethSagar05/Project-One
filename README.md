# Habit Mastery League

A small, local-only Flutter app for keeping weekly habits without streak guilt.
Each habit has a weekly target (1–7 days). The app shows how many distinct days
you actually practiced this week. A missed day is just information.

Team **Saketh And Sai**: Saketh Sagar Kokkireni (data layer, Garden Guide, tests)
and Sai Athota (UI screens, navigation, documentation).

## Run it

```bash
flutter pub get
flutter run            # on an emulator or device
flutter analyze
flutter test
flutter build apk --release   # APK at build/app/outputs/flutter-apk/app-release.apk
```

No accounts, no network, no cloud services. All data stays on the device.

## Screens (five roles)

| Role | Screen | What it does |
| --- | --- | --- |
| Catalog / dashboard | `GardenScreen` | This week's summary, category filter, a tile per habit, "+ New habit" |
| Editor | `HabitEditorScreen` | Create/edit: title, category, weekly-target slider, start date, note. Validates before saving |
| Detail / activity | `HabitDetailScreen` | This week's count and rate; Start week → Check in today → Finish week / Reset view; Garden Guide card |
| History / insights | `HistoryScreen` | Week selector, that week's rate, all-time count, full weeks on target; add/edit/delete check-ins (swipe or buttons) |
| Settings | `SettingsScreen` | Default-target slider, reduce-motion switch, how weeks work, "Add fictional sample habit" |

## Data

**SQLite (sqflite)** – two related tables, created in `lib/data/app_database.dart`:

- `Habit(id PK, title NOT NULL, category, weeklyTarget CHECK 1..7, startedLocalDate YYYY-MM-DD, motivation)`
- `CheckIn(id PK, habitId FK → Habit ON DELETE CASCADE, localDate YYYY-MM-DD, note, UNIQUE(habitId, localDate))`

`PRAGMA foreign_keys = ON` is set in `onConfigure`, so the cascade works.

**SharedPreferences** – `defaultTarget`, `reduceMotion`, and each habit's weekly cycle
status (`cycle.<habitId>` = `inProgress@2026-10-26`). A status from an earlier week
reads as "Not started", so every week starts fresh.

### Policies

- **One check-in per habit per day.** Checked in code (friendly message) and by the
  UNIQUE constraint (backstop).
- **Dates and weeks.** Plain local dates, no time-zone conversion. Weeks run Monday–Sunday.
  Days are added with `DateTime(y, m, d + n)` so daylight saving can't shift them.
- **Start-date edits.** Blocked if a check-in would end up before the new start date.
- **Parent delete.** Deleting a habit cascades to its check-ins, after a dialog that
  says how many will go.
- **Derived values.** Weekly rate, plant stage and the garden summary are calculated
  from rows each time and never stored.
- **Weekly rate.** Distinct check-in dates this week ÷ weekly target. The plant and
  percent use the capped rate; extra days stay visible ("5 of 4 days · 100% (+1 extra)").
  The garden summary caps each habit at its own target.

## Code map

```
lib/
  main.dart                 opens SQLite + SharedPreferences, starts the app
  app.dart                  MaterialApp, theme, reduce-motion wiring
  app_scope.dart            AppServices (repository, settings, clock) for every screen
  models/                   Habit, CheckIn
  data/app_database.dart    schema
  data/habit_repository.dart  CRUD for both tables, validation, parameterized queries
  data/settings_store.dart  SharedPreferences settings + weekly cycle status
  logic/local_date.dart     date keys, Monday weeks, AppClock (fixed "today" for tests)
  logic/progress.dart       weekly rate, plant stage, garden summary, weeks on target
  logic/garden_guide.dart   the rule-based helper (see AI_FEATURE.md)
  logic/validators.dart     shared form + repository rules
  screens/                  the five screens
  widgets/                  HabitTile, PlantPicture, RateBar, EmptyStateCard (stateless);
                            GardenGuideCard; dialogs incl. CheckInDialog (stateful)
test/
  garden_guide_test.dart    H1–H5, week rules, partial start week, duplicate dates
  progress_test.dart        acceptance example (50% → 50% → 25%), caps, Monday weeks
  repository_test.dart      CRUD for both tables, T1/T2/T3/T7, cascade, restart (T5 storage)
  settings_store_test.dart  settings persistence, weekly cycle reset
  widget_test.dart          empty state, T1, create habit, T2, helper "Not enough history"
```

## Contract checklist

| Requirement | Where |
| --- | --- |
| 5 screen roles | `lib/screens/` |
| 2 related SQLite entities, full CRUD, confirm delete, parent/child policy | `habit_repository.dart`, dialogs in detail/history screens |
| Start → progress → finish/reset; survives restart | Detail screen + `SettingsStore` cycle status |
| One filter, one aggregate | Category chips; weekly rate + garden summary |
| StatelessWidget + StatefulWidget classes | `widgets/` (stateless), screens + `CheckInDialog` (stateful) |
| Forms, lists, navigation, gestures, dialogs, buttons | Editor form, ListViews, Navigator.push, swipe-to-delete with visible button alternative, AlertDialogs |
| Meaningful slider | Weekly target (editor) and default target (settings) |
| Lifecycle cleanup, clear errors | Controllers disposed; `mounted` checks after awaits; ValidationException / StorageException messages |
| Local smart helper + baseline + evaluation | `garden_guide.dart`, `AI_FEATURE.md`, `garden_guide_test.dart` |
| Offline | No network code or permissions used by the app |

## Demo tip

Settings → **Add fictional sample habit** creates "Sketching (sample)" with four past
weeks of fictional check-ins (last three weeks: 2, 3, 4) and a target of 5, so the
Garden Guide card suggests 3 right away (case H1).
