# Hoopmap Privacy Policy

**Effective date:** 2026-08-22

This policy describes what data Hoopmap ("the app") collects, why, and how
it's handled. It reflects the app's actual behavior as implemented — see
`docs/architecture.md` in the source repository for the technical detail
behind each point below.

## Who this app is from

Hoopmap is developed by Rachou Corp. For any question about this policy or
your data, contact `rachoucorporation@gmail.com`.

## What the app does

Hoopmap helps you find basketball courts near your location, using data
from OpenStreetMap and courts submitted by other Hoopmap users. You can
also submit a court yourself.

## Data we collect

### Location

The app requests your device's location permission (precise or
approximate) to:

- find and sort basketball courts near you in the list and map views;
- pre-fill your current position on the map when you add a new court.

Location is read on demand, only while those screens are open or that
action is in progress — never collected in the background, and never
tied to your identity. If you decline the permission, the app remains
usable but shows a message explaining that nearby-court search needs it.

### An anonymous identifier

On first launch, the app automatically creates an anonymous session
through Firebase Authentication. This generates a random identifier for
your device's app installation — no name, email address, phone number, or
other personal identifier is requested or collected, and there is no
sign-up or login screen.

If you submit a court, that anonymous identifier is stored alongside it
(as `createdBy`) so the system can attribute the submission to a session.
It cannot be used on its own to identify who you are.

### Courts you submit

If you use the "Add a court" form, the following is sent to our database
(Cloud Firestore) and becomes publicly visible to every Hoopmap user
searching that area, exactly like the OpenStreetMap-sourced courts:

- the court's name, hoop count, and indoor/outdoor status;
- the latitude/longitude you selected;
- your anonymous identifier (see above) and a server-generated timestamp.

Submitted courts cannot currently be edited or deleted through the app.
If you want a court you submitted removed, contact
`rachoucorporation@gmail.com` with enough detail (name and approximate
location) to identify it.

### Reports you file

Every user-submitted court (never one sourced from OpenStreetMap) has a
"Report this court" action. If you use it, the app sends your anonymous
identifier, a reason you choose (inaccurate, offensive, spam, doesn't
exist, other), an optional free-text comment, and a server timestamp to a
separate `reports` collection in the same database. This collection is
not readable by any user through the app — not even by the person who
filed the report or the person who submitted the court — so a report
can't be seen, browsed, or tampered with by anyone using the app itself.
Reports are reviewed by the Rachou Corp team using an internal tool (see
`docs/moderation.md` in the source repository), typically within 24–48
hours, and are used only to decide whether to remove the reported court;
they are not shared with anyone outside Rachou Corp. You cannot report
the same court more than once from the same anonymous identifier.

## Data we do NOT collect

Hoopmap does not collect or request: your name, email address, phone
number, photos or files from your device, contacts, financial or health
information, or browsing activity outside the app. The app contains no
advertising and no analytics or crash-reporting software development kit,
so no advertising identifier or usage-analytics data is collected either.

## Third-party services

Using the app involves network requests to these services, each governed
by its own terms:

- **Firebase (Google)** — hosts the anonymous authentication session and
  the Cloud Firestore database described above.
  ([Google Privacy Policy](https://policies.google.com/privacy))
- **OpenStreetMap / Overpass API** — receives the geographic area you're
  viewing (as coordinates) to return nearby courts and map tiles; queries
  identify the app via a User-Agent header, not you personally.
  ([OpenStreetMap Privacy Policy](https://wiki.osmfoundation.org/wiki/Privacy_Policy))
- **Wikimedia Commons** — queried by file name to fetch a court photo's
  author and license before the photo is shown, when a court has one.
  ([Wikimedia Foundation Privacy Policy](https://foundation.wikimedia.org/wiki/Policy:Privacy_policy))

None of these integrations involve selling your data or sharing it with
advertisers, because the app has no advertising relationship with anyone.

## Data retention

Location data is not stored — it's used live for the request it was read
for and discarded. Submitted courts and the anonymous identifier attached
to them are retained indefinitely, since removing a public court entry
without breaking the map for other users requires a deliberate action (see
"Courts you submit" above), not automatic expiry. Reports are retained
until reviewed and resolved (see "Reports you file" above); resolved
reports are kept as an internal moderation record rather than deleted.

## Children's privacy

Hoopmap is not directed at children and does not knowingly collect data
from children.

## Your rights

Depending on where you live, you may have rights over the data described
above (for example, under the EU/UK GDPR): to know what's held, to request
its correction or deletion, or to object to its processing. Since the app
has no account system, the only submitted-court data tied to your device is
the anonymous identifier and the court entry itself — contact
`rachoucorporation@gmail.com` to exercise these rights, and provide
enough detail about your submission (approximate court name/location and
approximate submission date) for us to locate it, since there's no login to
look it up by.

## Changes to this policy

If this policy changes, the updated version will be published at the same
URL with a new effective date above.
