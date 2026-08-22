# Play Store listing

Ready to copy into the Play Console. Everything here is written to match what
the app actually does — cross-check against `docs/architecture.md` and the
source before changing any factual claim.

## App name (30 characters max)

```
Hoopmap: Basketball Courts
```

27 characters.

## Short description (80 characters max)

```
Find basketball courts near you, anywhere in the world, on a map or a list.
```

77 characters.

## Long description (4000 characters max)

```
Hoopmap helps you find a basketball court wherever you are — no matter the
city or country.

Open your phone, allow location access, and Hoopmap shows the courts around
you, sorted by distance, as a scrollable list or as pins on a map. Tap a
court to see its details: indoor or outdoor, number of hoops, exact
coordinates, and a photo when one is available. A "Directions" button opens
your phone's map app for step-by-step navigation.

WHERE THE DATA COMES FROM

Court locations come from OpenStreetMap, the open, community-maintained map
of the world, queried live for the area you're viewing — so coverage isn't
limited to a handful of major cities. Some courts also include a photo,
pulled from Wikimedia Commons together with its author and license, shown
only when that attribution is available.

ADD THE COURTS THAT ARE MISSING

If a court near you isn't listed yet, add it yourself: name it, set the hoop
count and whether it's indoor or outdoor, and place it on the map (or use
your current GPS position). It's saved instantly and becomes visible to
every Hoopmap user searching that area.

NO ACCOUNTS, NO CLUTTER

There's no sign-up screen and no password to remember — Hoopmap creates an
anonymous session automatically so you can start browsing and contributing
right away. The app has no ads and doesn't track your behavior.

Whether you're traveling, new in town, or just want to find a hoop for a
pickup game tonight, Hoopmap points you to the nearest one.
```

1,415 characters.

## Category and tags

- **Category**: Sports
- **Suggested search keywords** (Play Console has no separate public tags
  field; keep these for App Store Optimization / description tuning):
  basketball, basketball court, streetball, pickup basketball, court finder,
  OpenStreetMap, map, sports near me.

## Contact details

- **Email**: `rachoucorporation@gmail.com`
- **Website**: none published yet — leave blank or link the rachoucorp.app
  site once the privacy policy page is live there (see below).

## Content moderation (Google Play's user-generated content requirement)

Hoopmap carries user-generated content (submitted court names, hoop
counts, and locations), so it ships the three things Google Play requires
for that:

1. **Terms of Use**, distinct from the Privacy Policy, that a user must
   accept before their first court submission — see
   `design/play-store/terms-of-use.md` (source) and the in-app "Terms of
   Use" screen (reachable from the courts list app bar at any time, and
   shown as a mandatory acceptance gate the first time someone taps "Add
   a court"). They define prohibited content (illegal, hateful, sexual,
   harassing, spam, fabricated/nonexistent courts) and reserve Rachou
   Corp's right to remove content and restrict a contributor.
2. **An in-app reporting flow**: every user-submitted court (never an
   OpenStreetMap-sourced one) has a visible "Report this court" action —
   a reason (inaccurate, offensive, spam, doesn't exist, other) plus an
   optional comment, written to a dedicated `reports` Firestore
   collection that the app itself can never read back (see
   `firestore.rules`), so reports can't be seen or tampered with by any
   user, including the reporter.
3. **Effective moderation**: `tool/moderate.mjs`, an Admin-SDK script run
   by the Rachou Corp team, lists pending reports, shows the reported
   court alongside the report, and lets a moderator remove the court and
   close the report. Documented in `docs/moderation.md`, with a
   24–48 hour response commitment on every pending report.

## Content rating

Fill in Google Play's IARC content-rating questionnaire in the Play Console
directly (this isn't a self-declared field) — expected outcome based on the
app's actual content:

- No violence, sexual content, profanity, gambling, or user-to-user chat.
- User-generated content is limited to a court's name, hoop count, and
  indoor/outdoor flag — free-text is a name field capped at 60 characters,
  not an open chat or comment surface.
- No content that specifically targets or is directed at children.
- Expected rating: Everyone / PEGI 3, but only the questionnaire result is
  authoritative.

## Target audience and content

- **Target age group**: general audience (not designed for or directed at
  children specifically).
- **Ads**: the app shows no advertising of any kind (no ad SDK is included
  in the build — see `pubspec.yaml`).
- **In-app purchases**: none. The app is free with no purchasable content.

## Data safety section (Play Console)

Fill in the Play Console's Data safety form using the mapping below — it
reflects what the code actually does (see `docs/architecture.md` and
`lib/core/auth/`, `lib/core/location/`,
`lib/features/courts/data/firestore_court_repository.dart`), not a generic
template.

**Does your app collect or share any of the required user data types?** Yes.

| Data type | Collected? | Shared? | Purpose | Notes |
|---|---|---|---|---|
| Approximate location | Yes | No | App functionality | Used to center the initial court search and, if precise location is unavailable, as a fallback. |
| Precise location | Yes | No | App functionality | Used to find and sort nearby courts, and to prefill the add-court map with your current position. Requested via Android's runtime location permission; declining it disables location-dependent screens but doesn't crash the app. |
| App activity — other user-generated content | Yes | No | App functionality | Courts you submit (name, hoop count, indoor/outdoor, coordinates) are stored in Firestore and become visible to every user — that visibility is the feature, not a side effect. If you use "Report this court," the reason, optional comment, and your anonymous ID are stored in a separate, non-public `reports` collection that no user (including the reporter) can read back — see `firestore.rules` and `docs/moderation.md`. |
| Device or other identifiers | Yes | No | App functionality, account management | An anonymous Firebase Authentication ID is created automatically on first launch (no email, phone number, or name is ever collected) and is attached to courts you submit (and to any report you file), so the backend can attribute a submission or report to a session without identifying you personally. |

**Data NOT collected**: name, email address, phone number, physical
address, photos or videos you take, contacts, financial or health info,
browsing history outside the app, or any advertising/analytics identifier —
the app has no analytics or crash-reporting SDK.

**Is all of the user data collected by your app encrypted in transit?**
Yes — all network calls (Firebase, the Overpass API, Wikimedia Commons) use
HTTPS.

**Do you provide a way for users to request that their data is deleted?**
Partially: the app has no account or edit/delete UI for submitted courts
(matching `firestore.rules`, which forbids updates and deletes entirely —
see `docs/architecture.md`'s "Known limitations"). A user who wants a court
they submitted removed must contact `rachoucorporation@gmail.com`, or use
the in-app "Report this court" action, with enough detail (court name and
approximate location) to identify it; removal is a manual, backend-side
operation (see `docs/moderation.md`), not self-service in-app.

## Location permission declaration (Play Console → App content → Permissions)

Justification to paste into the Advanced access / sensitive permissions
declaration for `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`:

```
Hoopmap is a court-finder app: its core function is showing the user
basketball courts near their current position, sorted by distance, on a
list and a map (comparable to a point-of-interest-finder or maps app).
Location is read on-demand when the nearby-courts screens are opened and
when the user opts to use their current position while adding a court; it
is never collected in the background, never transmitted to Hoopmap's own
servers as raw coordinates outside of the search/add-court requests it is
needed for, and is not sold or shared with advertisers. The app functions
without granting location — the affected screens show a clear explanation
and a way to retry — but nearby-court search cannot work without knowing
where "nearby" means.
```

## Store assets

- **Icon**: `design/play-store/icon-512.png` (512×512, resized from the
  final `assets/icon/icon.png`). The icon itself is final; do not
  regenerate or restyle it for the store listing.
- **Feature graphic**: `design/play-store/feature-graphic.png` (1024×500).
- **Screenshots**: `design/play-store/screenshots/*.png` (1080×1920, 8
  images) — raw, undressed captures are kept in
  `design/play-store/screenshots/raw/` for reference or re-dressing.
- **Privacy policy**: content is in `design/play-store/privacy-policy.md`;
  publish it as an actual page in the rachoucorp.app site repo and link
  that URL in the Play Console (Google requires a reachable HTTPS URL, not
  a Markdown file in this repo). It changed with this release (new
  "Reports you file" section, contact email filled in) — the published
  page needs to be regenerated from the current content.
- **Terms of use**: content is in `design/play-store/terms-of-use.md`, a
  new document as of this release. It also needs a published HTTPS page
  on rachoucorp.app (it doesn't exist there yet — this is a new page, not
  a regeneration) and, in the Play Console, belongs in the app's website
  field or wherever the store listing exposes a Terms of Use link; the
  in-app copy at `TermsOfUsePage` is the same content and doesn't depend
  on this page being live, but Play's UGC policy expects a public URL too.
