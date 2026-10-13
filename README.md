# CylinQ

Track every gas cylinder with a QR label, and see where your sales happen.

**Live:** https://cylinq.web.app

![CylinQ](portfolio/cover.png)

Screens, design notes and engineering write-up: [portfolio/README.md](portfolio/README.md).

## What it does

- **QR labels.** Generate serials (`SGA-00001`, …) and print them on A4 sticker
  sheets (24 per page) or a thermal label printer, or download the PDF. Each code
  is a link, so any phone camera opens that cylinder on the web dashboard.
- **Scan every move.** Staff scan cylinders as they are filled, loaded onto a
  vehicle, handed to a customer, collected empty and returned to the godown.
  Every move is an immutable event, so each cylinder has a full history.
- **Deliveries with location.** One screen per customer visit: full cylinders
  given, empties taken back, amount and payment mode. The phone's GPS is saved
  with the sale.
- **Owner dashboard.** Revenue, cylinders sold and deliveries for a period,
  sales by area, a daily trend, a map of where deliveries happened, where every
  cylinder is now, and which cylinders have stayed with a customer for 30+ days.
- **Staff and roles.** The owner creates logins for delivery staff and can switch
  anyone's access off. Staff see their vehicle and their day.
- **Works offline.** Scans and deliveries are cached on the phone and sync when
  signal returns.

![A delivery round on the staff app](portfolio/mobile-flow.png)

| Dashboard | Label sheet | Cylinder history |
|---|---|---|
| ![Dashboard](portfolio/screenshots/desktop/02-dashboard.png) | ![Labels](portfolio/screenshots/desktop/07-label-sheet.png) | ![History](portfolio/screenshots/desktop/05-cylinder-history.png) |

## Zero running cost

Everything runs on the Firebase **Spark (no-cost) plan**: no billing account, no
card.

| Need | Used | Avoided because it needs billing |
|---|---|---|
| Sign-in | Firebase Auth, email/password | Phone OTP |
| Data | Cloud Firestore (free daily quota) | — |
| Server logic | Security rules + batched writes | Cloud Functions |
| Maps | `flutter_map` + OpenStreetMap tiles | Google Maps Platform |
| Location | Device GPS | Geocoding API |
| Admin web | Firebase Hosting | — |

Without Cloud Functions, the security rules are the only server-side check. A
cylinder can change state only together with a new event written in the same
batch by the signed-in user, and the daily totals can grow only by exactly one
new sale. See [firestore.rules](firestore.rules) and its
[tests](tests/rules).

The dashboard reads one small summary doc per day instead of every sale, so a
30-day view costs about 30 document reads. A business with ~5,000 cylinders and
~500 deliveries a day stays well inside the free quota (50,000 reads and 20,000
writes per day).

## Data model

```
accounts/{uid}                    which business a user belongs to
orgs/{orgId}                      the business: name, label prefix, next serial
orgs/{orgId}/members/{uid}        admin or staff, active or not
orgs/{orgId}/types/{id}           cylinder sizes and refill price
orgs/{orgId}/areas/{id}           delivery areas
orgs/{orgId}/customers/{id}       name, phone, area, GPS, cylinders held
orgs/{orgId}/cylinders/{serial}   where it is, full or empty, who holds it
orgs/{orgId}/events/{id}          every move, immutable
orgs/{orgId}/sales/{id}           every delivery visit, immutable
orgs/{orgId}/daily/{yyyy-MM-dd}   totals per day, per area, per ~1 km cell
```

The full design is in [docs/PLAN.md](docs/PLAN.md).

## Stack

Flutter 3.44 (Android + web) · Riverpod 3 · go_router · Cloud Firestore ·
Firebase Auth · flutter_map · fl_chart · pdf / printing · mobile_scanner ·
geolocator

## Develop

```sh
flutter pub get
flutter run -d chrome          # owner dashboard
flutter run -d <android-id>    # staff app
flutter test                   # unit and widget tests
```

Security rules tests need Java 21 and the Firebase CLI:

```sh
cd tests/rules && npm ci && npm run emulate
```

## Deploy

```sh
firebase deploy --only firestore            # rules and indexes
flutter build web --release && firebase deploy --only hosting
flutter build apk --release                 # Android
```

## Set up a new business

1. Open the web app and create an account, then the business. The name, label
   prefix and phone number are printed on every label.
2. In **Settings**, set the refill price for each cylinder type and add your
   delivery areas.
3. In **QR labels**, create labels and stick one on each cylinder.
4. In **Staff**, create a login for each delivery person and share it with them.
