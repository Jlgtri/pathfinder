# PathFinder

A Flutter application for calculating and visualizing shortest paths on a grid. PathFinder retrieves tasks from a configurable REST endpoint, computes routes using **A\***, replays the search step by step, submits the results, and displays each path on an interactive matrix.

The project was built around the [WEBSPARK Flutter test assignment](https://flutter.webspark.dev/).

## Features

- **Configurable API endpoint** — enter and validate an HTTP(S) URL, including query parameters; the URL is saved locally.
- **A\* pathfinding** — search a square grid containing walkable (`.`) and blocked (`X`) cells, with horizontal, vertical, and diagonal moves.
- **Slow-motion algorithm playback** — inspect the current task, expanded cell, candidate neighbor, search scores (`g`, `h`, `f`), operation count, and overall progress. Pause, resume, or change playback speed.
- **Result submission** — send computed paths to the server and display its verification results; retry a failed submission without recalculating the paths.
- **Path details** — view a color-coded grid, step count, coordinates, and route sequence with zoom/pan and copy-to-clipboard support.
- **Light and dark themes** — shared Mix design tokens and persisted theme preference.
- **Responsive UI** — mobile-first screens with constrained content width on larger displays.

## App flow

```text
Splash
  ↓
Configuration (API URL)
  ↓
Processing (GET tasks → A* trace → playback → POST results)
  ↓
Results (paths and server verification)
  ↓
Details (interactive grid and route coordinates)
```

Each main screen provides navigation within this flow. The processing screen also exposes playback controls.

## Tech stack

| Package / technology | Purpose |
| --- | --- |
| **Flutter / Dart** | Cross-platform application and UI |
| **hooks_riverpod, riverpod_annotation** | App state, asynchronous tasks, workflow coordination, and persisted settings providers |
| **flutter_hooks** | Reusable lifecycle and state hooks |
| **go_router** | Typed routes and navigation |
| **mix** | Theme tokens, reusable stylers, and consistent component styling |
| **material_ui** | UI components and theme integration |
| **dio, retrofit** | REST API client, request/response handling, and typed endpoints |
| **dart_mappable** | API DTO serialization and deserialization |
| **rhttp, dio_compatibility_layer, http** | HTTP transport integration; platform-specific client setup |
| **shared_preferences** | Persistence for the endpoint URL and theme |
| **talker, talker_dio_logger, talker_riverpod_logger** | Application, network, and provider diagnostics |
| **flutter_native_splash** | Native splash-screen lifecycle |
| **collection** | Collection helpers |

Generated code is used for Retrofit, DartMappable, Riverpod, and typed GoRouter routes. The corresponding generator and `build_runner` dependencies must be present in the project's `pubspec.yaml`.

## Project structure

```text
lib/
├── main.dart                      # Bootstrap, Dio, ProviderContainer, router
└── src/
    ├── api.dart                   # Retrofit API interface
    ├── api/
    │   └── pathfinding.dart       # Endpoints and request/response models
    ├── providers.dart             # Shared providers and API configuration
    ├── providers/
    │   ├── processing.dart        # Task loading, A* playback, results, submission
    │   └── preferences/
    │       ├── endpoint_url.dart  # Saved endpoint and URL validation
    │       └── theme.dart         # Saved light/dark theme
    ├── solvers.dart
    ├── solvers/
    │   └── a_star_trace.dart      # A* search with operation trace
    ├── routes.dart                # Typed routes and application wrapper
    ├── routes/
    │   ├── route_00_splash.dart
    │   ├── route_01_configuration.dart
    │   ├── route_02_processing.dart
    │   ├── route_03_results.dart
    │   └── route_04_details.dart
    ├── styles.dart                # Global colors, spacing, radii, typography
    ├── styles/
    │   └── misc.dart              # Shared non-text Mix stylers
    ├── widgets/
    │   └── route_header.dart      # Common navigation/theme header
    └── generated/                # Generated asset/font references
```

The `*.g.dart` and `*.mapper.dart` files are generated artifacts. Avoid editing them manually.

### State management

The processing workflow is split into focused providers:

- `pathTasksProvider` — retrieves grid tasks from the API.
- `aStarPlaybackProvider` — replays recorded search operations, including speed and pause/resume state.
- `pathResultsProvider` — stores completed shortest paths.
- `resultsSubmissionProvider` — submits results and stores server verification.
- `processingProvider` — coordinates the overall workflow and currently active task.
- `processingProgressProvider` — combines completed tasks with the current task's playback progress.

The solver is independent of Flutter widgets. It computes a trace first, then the UI replays that trace; **slow motion is a visualization of the computation**, not a delay inside the search algorithm.

## Getting started

### Requirements

- Flutter SDK and a compatible Dart SDK
- A configured Flutter project (`pubspec.yaml` and target-platform directories)
- A reachable API endpoint following the expected WEBSPARK task/result schema

Package versions and minimum Flutter/Dart SDK constraints should be taken from your project's `pubspec.yaml` (not included in the shared `lib/` archive).

### Installation

From the Flutter project root:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

To run on Chrome:

```bash
flutter run -d chrome
```

On the Configuration screen, enter the full API URL, for example:

```text
https://flutter.webspark.dev/flutter/api
```

Then start processing, inspect the A* search, submit the paths, and browse the results.

### Flutter Web and CORS

Browsers enforce CORS for requests to external APIs. If the remote server does not return an appropriate `Access-Control-Allow-Origin` header, use a development reverse proxy or configure CORS on a server you control. The project's API provider contains a **debug-only rewrite** for the example WEBSPARK endpoint to a local `/webspark/...` path; that path only works when a matching development proxy is configured.

Do not disable browser security to work around CORS in production.

## Testing

An optional test suite was prepared separately under `tests/`:

```text
tests/
├── unit/           # URL validation, A* trace, Riverpod workflow
├── convenient/     # Convenient Test visual workflow
├── patrol/         # Patrol integration / end-to-end flows
└── support/        # Fake HTTP backend and test app setup
```

With the test dependencies installed, run the unit tests using:

```bash
flutter test tests/unit
```

Patrol tests require a supported device/platform setup and should be launched through **Patrol CLI**, not the regular `flutter test` runner:

```bash
patrol doctor
patrol test -t tests/patrol/pathfinder_flow_test.dart
```

Convenient Test uses its manager/worker workflow; see `tests/README.md` if the optional test suite is installed. Both UI test suites use a mocked Dio backend rather than the live WEBSPARK service.

## Pathfinding details

- A grid cell is identified by `(x, y)`, with `(0, 0)` in the upper-left corner.
- `.` represents an available cell; `X` represents a blocked cell.
- The current solver models **adjacent moves in eight directions**, with uniform move cost and a Chebyshev-distance heuristic.
- The search records node expansions and neighbor inspections so the UI can display exact operation counts.
- The resulting ordered coordinates are formatted and submitted to the API.

> **Movement-rule assumption:** The implementation treats each adjacent move as one step and allows diagonal moves around blocked corners. If the assignment's intended rule is moving multiple cells per action, the solver and its tests need to be adjusted accordingly.

## Notes

This repository's README documents the implementation represented by the latest shared `lib/` sources. The full project manifest, platform configuration, and optional tests were not part of that archive; verify those pieces in your local project before building or running integration tests.
