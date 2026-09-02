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

## Asking for the location

The system permission dialog is the most consequential thing the app ever asks for, and it can only be asked well once: a user shown what Hoopmap is for says yes for a reason, while one who meets the dialog on a screen they haven't read says no to be rid of it — and Android remembers that second answer far better than the app can recover from it.

So nothing touches the device's location until the user asks. `locationOptInProvider` (`core/location/location_opt_in.dart`, persisted in `shared_preferences`) records that request, and `userPositionProvider` throws `LocationNotRequestedException` until it is true. One gate, in front of the whole sequence — not even a silent permission check runs before it — so whichever feature ends up needing a position first cannot bring the dialog forward with it.

Inside the app, every request goes through `requestLocationOptIn` (`core/location/location_opt_in_flow.dart`), which pushes `LocationRationalePage` first: what the position is used for, that it is read only while the app is open, that it never leaves the phone, and that Android is about to ask. Android's own dialog can say none of that, and it can only be answered well once — so the explanation comes on a screen the user can leave ("Not now") without spending that answer. Allowing pops `true`, the flow opts in, and the system dialog follows as the consequence of a button. A user who already opted in is not explained to again.

Every entry point funnels through that one function — the offer on a list with no position (`CourtErrorView` renders that state as an `AppEmptyView`: an offer, not a failure), the map's status banner, the map's recenter button, and the add-court form's "My current location" — so no button can reach the system dialog without the screen that explains it. Opening the add-court form doesn't ask either: without an opt-in its picker just starts on the fallback centre.

Onboarding is the exception, and deliberately: its last slide *is* the explanation, immediately followed by "See courts near me", so pushing the rationale screen on top of it would say the same thing twice. That slide also offers "Browse without location", and Skip grants nothing — declining a text button is a decision either side can undo later, unlike declining the system dialog.

One wrinkle worth knowing: the opt-in is written after `WidgetsBinding.instance.endOfFrame` rather than immediately on the pop. The screen underneath is being rebuilt as the explanation pops, and it resumes the very providers the write invalidates; writing mid-frame lands a state change inside a build.

## Error handling

No page ever shows a raw exception type. `features/courts/presentation/court_error_messages.dart` translates every business exception (Overpass failure, 429 rate limiting, denied/disabled location permission or service, location fix timed out, court not found) into an actionable English message, shown by `AppErrorView`/`AppEmptyView` (`core/presentation/widgets/`) with a Retry button that invalidates the relevant provider.

Two of those failures cannot be fixed by retrying, because the setting that blocks them lives outside the app: a permanently denied location permission (`LocationPermissionPermanentlyDeniedException`, distinct from `LocationPermissionDeniedException` precisely so the UI can tell them apart) and switched-off location services. For those, `courtErrorRecovery` returns the system screen that can unblock them, and `CourtErrorView` (list) or the map's status banner offers the corresponding button — "Open settings" / "Turn on location" — which goes through `LocationService.openAppSettings()`/`openLocationSettings()` rather than touching `geolocator` from the presentation layer. A refused-but-promptable permission deliberately maps to no recovery: the system will ask again, so Retry is the shorter road.

`LocationResumeRefresher` (`core/location/`, wrapped around the tab shell) closes that loop. On every return to the foreground it re-reads the permission and the location services switch — silently, never prompting — and invalidates `userPositionProvider` when the answer no longer matches the state on screen: a position that has become possible is fetched, and one the app is no longer allowed to show is dropped. A successful fix is otherwise left alone, so switching apps doesn't cost a GPS read.

`CourtsMapPage` is the exception, deliberately: it builds its `FlutterMap` unconditionally and overlays the loading, error and empty states as a compact card (`_MapStatusBanner`) instead. A page-filling placeholder would take the map away precisely when the user has lost the courts, so the map stays visible and pannable through all three states — a denied permission or a failed Overpass call costs the user the markers, never the map.

## Court photos and Wikimedia Commons attribution

`Court.imageUrl` (optional) is never populated from an arbitrary OSM `image=*` URL: `data/commons_urls.dart` only resolves references that point to Wikimedia Commons (a `wikimedia_commons` tag in `File:...` format, or an `image`/Firestore URL already hosted on Commons), and returns `null` otherwise. This is a legal constraint, not just a technical one — Commons is the only source `data/commons_attribution.dart` can query the Commons API (`imageinfo`/`extmetadata`) against to obtain an author. The `CourtPhoto` widget (`presentation/widgets/`) only shows the photo once that attribution resolves with a non-empty author; on failure, when there's no author, or while resolution is pending, it shows the brand's fallback visual instead — never the photo without attribution, never an empty area.

## Position selection when adding a court

`AddCourtPage` keeps a single source of truth for the position (the latitude/longitude text controllers), fed by three equivalent paths: the map (`LocationPickerMap`, a reticle fixed at its center, `onPositionChanged` from the underlying `FlutterMap`), the "My current location" button (`LocationService`), and manual entry (collapsed inside an `ExpansionTile` with `maintainState: true`, so its validators stay active even while collapsed). The submit button stays disabled until an initial position is known.

## What the map searches

The list always searches a 5 km radius around the user (`nearbyCourtsProvider`). The map starts on that same search, then hands it over to the viewport: `visibleMapBoundsProvider` holds the box the map is showing, and `courtsInBoundsProvider` — a `StreamProvider` family keyed by `GeoBounds` — searches whichever box it is given, so panning to another neighbourhood shows that neighbourhood's courts instead of an empty map.

Three details make that behave:

- **Only gestures count.** `onPositionChanged` ignores camera moves the page makes itself (centring on the first fix, recentring), which would otherwise search twice for the same place; and the map is laid out, reporting a viewport, before the position fix lands, so honouring that first viewport would spend an Overpass query on wherever the map happened to open. `visibleMapBoundsProvider` staying null until the first pan is what expresses that.
- **The camera has to settle.** A pan emits a camera update per frame; the viewport only becomes a search after `_boundsSettleDelay` (600 ms) without movement.
- **`GeoBounds` has value equality**, which is what makes it usable as a family key: a viewport that lands back on a box already searched is answered without a second identical query.

Distances are measured from the user's position when it's known and from the middle of the viewport otherwise (a court on the map still has to say how far it is from something). The position is read, not watched, so a fix landing mid-search doesn't re-run the query just to relabel distances.

### Clustering

Courts closer together than a marker is wide would pile into an unreadable heap, so `domain/court_cluster.dart` groups them: the world is cut into square cells of a fixed size *in screen pixels* (Web Mercator, the tiles' own projection), and each cell's courts become one marker at the middle of the ones it holds. Two consequences make this cheap: zooming in splits clusters on its own (the same courts simply fall into different cells, no state kept between zoom levels), and the grid is anchored to the world rather than to the viewport, so panning can't reshuffle which courts are grouped.

`CourtMarkersLayer` lives inside `FlutterMap`'s children so it rebuilds with the camera it reads (`MapCamera.of`), which is what keeps the grouping in step with the zoom without the page tracking gestures itself. Past zoom 17 the grouping is dropped entirely — at street level, two courts on the same block are exactly the detail the user came to see. Tapping a cluster zooms in on it rather than opening one of the courts it happens to hold.

## The repository pattern and the composite repository

`CourtRepository` is the only abstraction the `presentation` layer sees: `watchCourtsInBounds(GeoBounds)`, `watchCourt(String id)`, and `addCourt(Court court)`. Three classes implement it:

- `OverpassCourtRepository` translates those calls into Overpass API requests and throws `UnsupportedError` on `addCourt` (the app doesn't write to OpenStreetMap). Overpass is a volunteer service with no uptime guarantee, so it queries three community instances in turn (`defaultOverpassEndpoints`), waiting 400 ms before the second attempt and twice as long before each further one, and remembers which instance answered so the next search doesn't start over at one known to be down. Only failures another instance could answer differently are carried over — a rate limit, a timeout, a connectivity failure, a 5xx, an unreadable body; a query the server rejected outright (4xx other than 429) stops there, since every instance runs the same query. The caller sees whatever the last attempt failed with, so a run that ends rate-limited still reads as rate-limited — with one exception: when *no* instance could be reached at all, the failure is a `NetworkUnavailableException` rather than an Overpass one. Three independent instances don't go dark at once nearly as often as a phone loses its connection, so that pattern is read as "the device is offline", which is a different message, a different icon, and a different thing for the user to do. A timeout is not part of it: an instance that answers slowly was still reached, and a device with no connection fails long before the 30 s cap.
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

- **Dependency on Overpass**: the app relies entirely on the public Overpass instances and their usage policy (30 s timeout, capped queried-area size). It falls back across three community mirrors (see below), but if all of them are unavailable or rate-limiting, searching OpenStreetMap courts fails.
- **No disk cache**: every search re-triggers an Overpass request and a Firestore request; no response is persisted locally between sessions.
- **Fixed search radius on the list**: `NearbyCourtsNotifier` always queries a 5,000-meter radius around the user's position; this radius is neither configurable by the user nor adjusted for court density. The map escapes it by searching its own viewport, but only from the first pan onwards, and only for the map.
- **No moderation**: `AddCourtController` writes directly to Firestore as soon as the form is valid. Nothing filters, flags, or verifies a submission before it's visible to every user.
