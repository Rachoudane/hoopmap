# Moderating reported content

Hoopmap lets any user report a court from its detail page ("Report this
court" — hidden for OpenStreetMap-sourced courts, shown for every
user-submitted one). Each report is written to the `reports` Firestore
collection by `FirestoreCourtReportRepository`
(`lib/features/reports/data/firestore_court_report_repository.dart`).

`firestore.rules` denies clients all read access to `reports` and all
update/delete access, so nothing in the app itself can list, act on, or
close a report — moderation happens exclusively through
`tool/moderate.mjs`, run by hand with a Firebase service account that has
Admin SDK access (which bypasses `firestore.rules` entirely).

**Commitment: pending reports are reviewed within 24–48 hours of being
filed.**

## One-time setup

1. Generate a service account key for the `hoopmap-mb-2026` Firebase
   project: [Firebase Console → Project settings → Service accounts →
   Generate new private key](https://console.firebase.google.com/project/hoopmap-mb-2026/settings/serviceaccounts/adminsdk).
   This downloads a JSON key file.
2. Save it as `tool/service-account.json` (already gitignored — see
   `.gitignore` — never commit it), or anywhere else and point
   `HOOPMAP_SERVICE_ACCOUNT` / `--service-account <path>` at it.
3. Install the script's Node dependencies once:

   ```powershell
   cd tool
   npm install
   ```

## Commands

Run from the repo root:

```powershell
# List every pending (unresolved) report.
node tool/moderate.mjs list

# Show one report in full, plus the court it's about (name, hoop count,
# indoor/outdoor, location, who submitted it, when).
node tool/moderate.mjs review <reportId>

# Delete the reported court and mark the report resolved.
node tool/moderate.mjs delete-court <reportId> [--reason "..."]

# Mark a report resolved WITHOUT touching the court (report judged
# invalid, a duplicate, or already handled).
node tool/moderate.mjs dismiss <reportId> [--reason "..."]
```

`--reason` is optional free text stored on the report as `resolutionNote`,
for the moderator's own record of why a report was dismissed or acted on.

## Suggested workflow

1. `node tool/moderate.mjs list` — see what's pending.
2. For each report, `node tool/moderate.mjs review <reportId>` — read the
   reporter's reason/comment and the actual court data side by side.
3. Decide:
   - The court is genuinely inaccurate, fake, spam, or otherwise violates
     the [Terms of Use](../design/play-store/terms-of-use.md) →
     `delete-court`.
   - The report doesn't hold up (court is fine, reason is unfounded) →
     `dismiss`.
4. Repeat until `list` shows nothing pending.

There is currently no way to warn or ban a specific contributor in-app
(the app has no accounts beyond an anonymous Firebase Auth uid) — repeated
bad-faith submissions from the same `createdBy` uid are handled by
deleting each offending court as it's reported; if a uid becomes a
persistent problem, blocking it outright is a manual Firestore rules
change (denying writes where `request.auth.uid == '<uid>'`), not something
this script automates yet.

## What moderation does not cover

- Court data sourced from OpenStreetMap is edited upstream, on
  [openstreetmap.org](https://www.openstreetmap.org), not through this
  tool — Hoopmap only ever reads it.
- This script only touches `reports` and `courts`; it has no notion of
  notifying the reporter or the original submitter of the outcome (the
  app has no way to reach either of them — see the Privacy Policy's
  "anonymous identifier" section).
