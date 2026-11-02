# AGENTS.md

Guidance for AI coding agents (Claude Code, Copilot, Cursor, etc.) and new contributors working on this repo.

## What we're building

**Friend 360** is a social health-stats tracker. Think *Life360, but for fitness*: instead of sharing your location with friends, you share your health stats and compete.

- Pull data from wearables and phone health platforms (Apple Watch via HealthKit, Fitbit, Android via Health Connect).
- Share stats with friends: **steps, sleep, workout minutes, active calories, screen time**, and other health metrics.
- Add friends and compete with them. A **leaderboard** ranks who has been most active this week.
- Compare habits side by side: who slept the most, who kept their workout streak and who cut their screen time.
- Use game mechanics to keep people coming back: XP, streaks, badges and weekly leagues.

Target users are friend groups and classmates who want light, fun accountability. It should not feel like a clinical health app.

## Tech stack

- **Flutter** (Dart SDK `^3.13.5`), Material 3. Targets: iOS and Android first. Web and desktop folders exist but are not priorities.
- No backend yet. Planned: Firebase (Auth + Firestore) for accounts, friends and synced stats.
- Planned health data: the [`health`](https://pub.dev/packages/health) package (HealthKit + Health Connect) and the Fitbit Web API (OAuth) as an optional extra source.

## Project layout

```
lib/
  main.dart         # App entry (Friend360App) + animated HomeScreen ("ENTER THE ARENA")
  hub_screen.dart   # HubScreen: My Stats / Friends' Stats / Leaderboard tiles,
                    # plus ComingSoonPage placeholder for unbuilt screens
test/
  widget_test.dart  # Widget tests for home → hub navigation
```

As the app grows, move toward this structure (don't do it all at once, only when touching the code):

```
lib/
  main.dart
  theme/            # colors, text styles, chunky button widgets (design system)
  models/           # User, DailyStats, Friendship, LeaderboardEntry
  data/             # repositories: mock data first, then health + Firebase sources
  screens/          # one file/folder per screen
  widgets/          # shared reusable widgets
```

## Design direction: playful, Duolingo-inspired

The app should feel like a game, not a spreadsheet. Take inspiration from Duolingo's *style*: bright, flat, friendly, rewarding. Do **not** copy its brand: no owl, no Duolingo logo, no copied illustrations or wording. Use our own mascot and assets.

Principles:

- **Bright, flat colors** on a clean white/light background. Use one strong primary green and bold accent colors. Avoid heavy gradients and neon glows. *(The current home/hub screens use pink/purple gradients and will be rethemed, see the issues.)*
- **Chunky "3D" buttons and cards**: rounded corners (16–20px), a solid darker bottom border (~4px) that looks like depth, and a press animation where the button moves down and the border shrinks.
- **Rounded, heavy typography**: a rounded sans such as **Nunito** (Google Fonts) in weights 700–900. Headings should be big and bold.
- **Celebrate progress**: confetti or a bounce when a goal is hit, streak flames 🔥, XP counters that tick up, badges.
- **Friendly copy**: short and encouraging, with a little cheek ("You're 2,000 steps behind Alex 👀"). Never shame users about sleep or health.
- **Mascot**: an original character (TBD) that reacts to your progress.

Starting palette (put these in `lib/theme/`, never hard-code them in widgets):

| Token        | Hex       | Use                                  |
|--------------|-----------|--------------------------------------|
| `primary`    | `#58CC02` | main buttons, progress, success      |
| `primaryDark`| `#46A302` | 3D bottom edge of primary buttons    |
| `blue`       | `#1CB0F6` | info, sleep                          |
| `orange`     | `#FF9600` | streaks, workouts                    |
| `red`        | `#FF4B4B` | errors, losing a rank                |
| `purple`     | `#CE82FF` | screen time                          |
| `gold`       | `#FFC800` | 1st place, XP, badges                |
| `ink`        | `#3C3C3C` | main text                            |
| `muted`      | `#AFAFAF` | secondary text                       |
| `surface`    | `#FFFFFF` | background                           |
| `border`     | `#E5E5E5` | card borders                         |

Each stat should keep the same color everywhere (sleep is always blue, screen time always purple, and so on).

## Core features (see GitHub issues for details)

1. **My Stats**: today's and this week's steps, sleep, workouts, calories and screen time, plus goals and streaks.
2. **Friends' Stats**: a list of friends with their latest stats, and a side-by-side compare view.
3. **Leaderboard**: weekly ranking with selectable metric (steps, sleep, workouts, overall XP). The top 3 get a podium.
4. **Friends**: add by friend code, username or invite link. Accept and decline requests.
5. **Health data sync**: HealthKit, Health Connect and Fitbit.
6. **Gamification**: XP, streaks, badges and weekly leagues.
7. **Privacy**: each user chooses which stats friends can see.

## Git rules for AI agents (mandatory)

- **AI agents must never push to `main`.** No direct commits to `main`, no force-pushes, no merges into `main`.
- Do all work on a separate branch, e.g. `feat/<issue#>-short-name`, `fix/<issue#>-short-name`, `chore/<short-name>`. Agents may commit and push to these branches.
- Open a **pull request** into `main` for every change. Reference the issue it addresses (`Closes #N`).
- Only a **human** may approve and merge a pull request. Agents must not approve or merge their own PRs, or anyone else's.
- Don't sweep up unrelated uncommitted changes. Stage only the files your change touches.

## Working conventions

- Before committing, run:
  ```bash
  flutter pub get
  flutter analyze
  flutter test
  ```
  All three must pass.
- Add or update widget tests in `test/` when you add or change a screen. Existing tests check that the home → hub navigation works, so keep them green.
- **Use mock data first.** Build screens against a fake repository (`data/mock_*.dart`) so UI work doesn't wait on the backend or health integrations. Put the data source behind an interface so it can be swapped later.
- Keep widgets small. Private widgets (`_Foo`) are fine inside a screen file. Move them to `widgets/` once two screens share them.
- Use `withValues(alpha: …)` rather than the deprecated `withOpacity`.
- Dispose of every `AnimationController`.
- Health data is sensitive. Never log raw health values. Ask for the smallest set of permissions you need. Treat screen time and sleep as private by default.
- Don't commit secrets (Firebase keys beyond the public config, Fitbit client secrets, etc.).

## Platform gotchas

- **iOS HealthKit** needs the HealthKit capability plus `NSHealthShareUsageDescription` in `ios/Runner/Info.plist`. It only works on a real device or a simulator that has Health data.
- **Android Health Connect** needs the permissions declared in `AndroidManifest.xml` and the Health Connect app installed (built in on Android 14+).
- **Screen time** is restricted on iOS: the Screen Time / DeviceActivity APIs need a special entitlement and don't expose raw numbers easily. On Android, use `UsageStatsManager` (the user has to grant usage access). Plan for manual entry as a fallback.
- **Fitbit** data comes from its Web API through OAuth, not from the device directly.
