# Wishtick — Flutter app

Gifting, made together. See [`../plan.md`](../plan.md) for the architecture and
[`../sprints.md`](../sprints.md) for the sprint breakdown with Figma node IDs.

## Running

### Without a backend (fake API)

Walks the whole app — sign-in, onboarding, the shell — with no server running.
**Any phone number is accepted and any 6-digit code works.**

```bash
flutter run --dart-define=WISHTICK_FAKE_BACKEND=true
```

A red **FAKE API** ribbon sits in the top-right the entire time, so a
screenshot can never be mistaken for the real thing. Sign-in and onboarding
completion persist across restarts, so both the "new user" and "returning
user" paths are testable; sign out (or clear app data) to reset.

The switch is opt-in *and* `kDebugMode`-gated — a release or profile build
folds it to `false` and tree-shakes the fakes, even if the define is passed.
See [`lib/core/dev/dev_mode.dart`](lib/core/dev/dev_mode.dart).

### Against the real backend

```bash
flutter pub get
flutter run --dart-define=WISHTICK_API_BASE_URL=http://10.0.2.2:3000
```

`10.0.2.2` is **the Android emulator's** route to the host machine — it does
not resolve on a physical device. On a real phone pass your computer's LAN IP
(`ipconfig` → IPv4 address), with the phone on the same Wi-Fi and the backend
bound to `0.0.0.0` (it already is):

```bash
flutter run --dart-define=WISHTICK_API_BASE_URL=http://192.168.1.10:3000
```

On the iOS simulator use `http://localhost:3000`.

VS Code users: all three are preset in
[`.vscode/launch.json`](../.vscode/launch.json).

The backend serves everything under `/api/v1` (global prefix + URI versioning),
with `/health` and `/ready` outside the prefix. `ApiConfig` composes this.

## Verify

```bash
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

CI runs all three plus a debug APK build — see
[`../.github/workflows/flutter-ci.yml`](../.github/workflows/flutter-ci.yml).

## Design system — the rules

The UI must match the Figma file (`8OShdlUS8kUWEE6j5DQ8GP`) as designed. Before
building a screen, open its frame by the node ID listed in `sprints.md`.

Three layers, and widgets only ever touch the third:

| Layer | File | Rule |
|---|---|---|
| Raw palette | `lib/core/theme/app_palette.dart` | **The only file allowed to contain a colour literal.** Swatch names mirror the Figma "Color System" page. Rebranding = editing this file. |
| Semantic tokens | `lib/core/theme/app_colors.dart` | `WishtickColors` — every token declares its light **and** dark value side by side, so the themes cannot drift. |
| Usage | everywhere else | `context.colors.primary`, never `Color(0xFF…)`, never `Colors.red`, never `AppPalette` directly. |

Same idea for spacing/radius (`app_dimens.dart`) and type (`app_typography.dart`).

`test/core/theme/design_system_guard_test.dart` enforces layers 1 and 3
mechanically — it scans `lib/` and fails the build on a stray colour literal or
a widget importing the palette. Fix the offending line rather than adding an
exemption.

### Light and dark

Both themes ship from day one; every screen is checked in both before it is
"done". `ThemeMode` (system/light/dark) is persisted and exposed at Profile →
Appearance. `SharedPreferences` is resolved before `runApp` so the saved theme
applies on the first frame.

Adding a token forces you to answer "what is this in dark mode?" at the same
moment, and the theme tests assert every foreground/background pair clears
**WCAG AA (4.5:1)** in both themes.

### Fonts

Montserrat (UI) and Cormorant Garamond (display/wordmark) are bundled as variable
fonts under `assets/fonts/` rather than fetched at runtime — no flash of
fallback type on first launch, works offline, deterministic in tests. Weights
move the `wght` axis via `FontVariation`; `FontWeight` alone does not.

## Layout

```
lib/
  core/
    theme/     # palette → tokens → ThemeData; the design system
    network/   # dio client, auth interceptor w/ refresh rotation, error mapping
    router/    # go_router config, 5-tab shell
    widgets/   # shared UI
  features/
    <feature>/
      data/ domain/ presentation/
```

## Known environment issue

`android/gradle.properties` sets `kotlin.incremental=false`. The Kotlin
incremental compiler double-registers its cache storage on this toolchain and
fails every plugin module with *"Could not close incremental caches … is already
registered"*. Revisit when Kotlin/AGP move.
