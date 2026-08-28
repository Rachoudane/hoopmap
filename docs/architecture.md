# Architecture

This document describes the organization of Hoopmap's code as it stands today, the reasoning behind its main abstractions, the test strategy, and the project's known limitations.

## Layers and dependency rule

The `courts` feature's code (`lib/features/courts/`) is organized into three layers, with a one-way dependency rule: `presentation` depends on `data` and `domain`, `data` depends on `domain`, and `domain` depends on nothing else in the project.

- **`domain/`**: business types (`Court`, `CourtWithDistance`, `GeoBounds`), pure functions (`distance.dart`), and the abstract `CourtRepository` interface (with the `CourtNotFoundException` exception). No file in this folder imports Flutter, `http`, or `cloud_firestore`.
- **`data/`**: concrete implementations of `CourtRepository` — `OverpassCourtRepository` (HTTP to the Overpass API), `FirestoreCourtRepository` (Firestore), `CompositeCourtRepository` (combines both) — along with their mappers (`overpass_mapper.dart`, `court_mapper.dart`) and Riverpod wiring (`court_repository_provider.dart`).
- **`presentation/`**: the Riverpod notifiers/providers that expose state to the UI (`NearbyCourtsNotifier`, `courtDetailProvider`, `AddCourtController`) and the pages (`pages/`).

`lib/core/` holds cross-cutting concerns used by several features: authentication (`core/auth/auth_providers.dart`), Firebase access (`core/firebase/firebase_providers.dart`), geolocation (`core/location/`, with the `LocationService` interface and its `GeolocatorLocationService` implementation), the router (`core/router/`), onboarding (`core/onboarding/`), and the design system (`core/theme/`).

## Navigation

The router (`core/router/app_router.dart`) has two notable features:

- **Onboarding gate**: its `redirect` function reads `onboardingCompletedProvider` (synchronous, backed by `shared_preferences`) and always redirects to `/onboarding` until it's been completed, whatever route was requested.
- **Tab navigation**: List and Map are the two branches of a `StatefulShellRoute.indexedStack` (each keeps its own navigation stack and scroll position when switching tabs), shown in `AppShell` with a `NavigationBar`. The court detail page and the add-court form are top-level routes, opened with `push` (never `go`) so there's always an underlying tab left in the stack.

Since a court detail page can also be opened directly by a cold deep link (with no existing navigation stack), `core/router/back_to_home_scope.dart` intercepts back navigation (button or system gesture) via `PopScope`: if there's something to pop, it pops normally; otherwise, it navigates explicitly to home.

## Error handling

No page ever shows a raw exception type. `features/courts/presentation/court_error_messages.dart` translates every business exception (Overpass failure, 429 rate limiting, denied/disabled location permission or service, location fix timed out, court not found) into an actionable English message, shown by `AppErrorView`/`AppEmptyView` (`core/presentation/widgets/`) with a Retry button that invalidates the relevant provider.

## Court photos and Wikimedia Commons attribution

`Court.imageUrl` (optional) is never populated from an arbitrary OSM `image=*` URL: `data/commons_urls.dart` only resolves references that point to Wikimedia Commons (a `wikimedia_commons` tag in `File:...` format, or an `image`/Firestore URL already hosted on Commons), and returns `null` otherwise. This is a legal constraint, not just a technical one — Commons is the only source `data/commons_attribution.dart` can query the Commons API (`imageinfo`/`extmetadata`) against to obtain an author. The `CourtPhoto` widget (`presentation/widgets/`) only shows the photo once that attribution resolves with a non-empty author; on failure, when there's no author, or while resolution is pending, it shows the brand's fallback visual instead — never the photo without attribution, never an empty area.

## Position selection when adding a court

`AddCourtPage` keeps a single source of truth for the position (the latitude/longitude text controllers), fed by three equivalent paths: the map (`LocationPickerMap`, a reticle fixed at its center, `onPositionChanged` from the underlying `FlutterMap`), the "My current location" button (`LocationService`), and manual entry (collapsed inside an `ExpansionTile` with `maintainState: true`, so its validators stay active even while collapsed). The submit button stays disabled until an initial position is known.

## The repository pattern and the composite repository

`CourtRepository` is the only abstraction the `presentation` layer sees: `watchCourtsInBounds(GeoBounds)`, `watchCourt(String id)`, and `addCourt(Court court)`. Three classes implement it:

- `OverpassCourtRepository` translates those calls into Overpass API requests and throws `UnsupportedError` on `addCourt` (the app doesn't write to OpenStreetMap).
- `FirestoreCourtRepository` reads and writes the Firestore `courts` collection.
- `CompositeCourtRepository` receives a `List<CourtRepository>` (Overpass then Firestore, wired in `court_repository_provider.dart`) and itself implements `CourtRepository`:
  - `watchCourtsInBounds` and `watchCourt` query all sources in parallel, merge the results (deduplicated by identifier), and tolerate one source failing as long as at least one responds;
  - `addCourt` delegates to the first source whose call doesn't throw `UnsupportedError` — in practice, Firestore.

Thanks to this composition, the `presentation` layer (and the tests) only ever handle a single type, `CourtRepository`, without ever knowing whether a given piece of data came from OpenStreetMap or Firestore.

## Why domain interfaces

`CourtRepository` (Firestore, Overpass) and `LocationService` (geolocation) are both defined as abstract interfaces in the domain/core, with a single concrete implementation backed by the real SDK (`cloud_firestore`/`http`, `geolocator`). This serves two purposes:

1. The `presentation` layer depends on a stable abstraction, not a third-party SDK — replacing or evolving a data source doesn't affect the notifiers or the pages.
2. Tests can substitute a fully controlled implementation (a fake `CourtRepository`, a fake `LocationService`) without ever touching a real SDK, which is what makes the test strategy below possible.

## Test strategy

No test in the project makes a real network call or a real Firebase call:

- **`OverpassCourtRepository`** is tested with a hand-written fake `http.Client` (a class that extends `http.BaseClient` and overrides `send()` to return a simulated response).
- **`CompositeCourtRepository`**, **`NearbyCourtsNotifier`**, **`courtDetailProvider`**, and **`AddCourtController`** are tested with hand-written fake `CourtRepository` implementations (and, for geolocation, a fake `LocationService`), written in each test file.
- **`FirestoreCourtRepository`** is tested with `FakeFirebaseFirestore`, from the `fake_cloud_firestore` package: an in-memory implementation of `cloud_firestore`, not a real instance.
- **`FirebaseAuth`** is never invoked for real in tests: `anonymousSessionProvider` is overridden at the `ProviderContainer` level, and `FirestoreCourtRepository` accepts an optional `currentUserId` parameter to inject the user identifier without going through `FirebaseAuth.instance`.
- **`SharedPreferences`** uses `SharedPreferences.setMockInitialValues(...)` (an in-memory implementation provided by the package) before `sharedPreferencesProvider.overrideWithValue(...)`, never the device's real storage.

## Known limitations

- **Dependency on Overpass**: the app relies entirely on the public `overpass-api.de` instance and its usage policy (30 s timeout, capped queried-area size). If that service is unavailable, slow, or rate-limits requests, searching OpenStreetMap courts fails, with no fallback to another instance.
- **No disk cache**: every search re-triggers an Overpass request and a Firestore request; no response is persisted locally between sessions.
- **Fixed search radius**: `NearbyCourtsNotifier` always queries a 5,000-meter radius around the user's position; this radius is neither configurable by the user nor adjusted for court density.
- **No moderation**: `AddCourtController` writes directly to Firestore as soon as the form is valid. Nothing filters, flags, or verifies a submission before it's visible to every user.
