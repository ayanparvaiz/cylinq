# CylinQ — gas cylinder tracking for LPG distributors

![CylinQ: owner dashboard on the web and the staff app on phones](cover.png)

**Every gas cylinder, tracked. Every sale, on the map.**

CylinQ gives a gas agency a QR label on every cylinder, a phone app its delivery
staff scan with, and a live dashboard that shows the owner what sold, where, and
where each cylinder is right now. It runs on Flutter (Android + web) and
Firebase, and it costs nothing to run: it was designed from the start to stay
inside Firebase's free Spark plan.

- **Live web app:** https://cylinq.web.app
- **Source:** https://github.com/ayanparvaiz/cylinq
- **Role:** solo, end to end: product design, UI, Flutter app, Firebase data
  model and security rules, testing, deployment
- **Timeline:** October 2026

> The screenshots show a demo business, "Shanti Gas Agency" in Kolkata, filled
> with 45 days of simulated deliveries. All names, numbers and locations are
> made up.

---

## The problem

A gas distributor owns thousands of steel cylinders that keep moving: from the
godown to a delivery van, to a home or a restaurant, and back empty. Paper
registers can't answer the owner's basic questions:

- Which areas buy the most, and is that changing?
- How many cylinders are at the godown, on vans, or with customers today?
- Which customers have been holding our cylinders for a month without
  reordering? Those cylinders are effectively lost stock.

The client had a small budget, so the solution also had to be **free to run**.

## The solution

| | |
|---|---|
| **QR labels** | The owner generates serials (`SGA-00001`, …) and prints them on A4 sticker sheets or a thermal label printer. Each QR is a link, so even a normal phone camera opens the cylinder's page. |
| **Scan every move** | Staff scan cylinders as they are filled, loaded, delivered, collected empty and returned. Every move is stored as an immutable event, so each cylinder has a full history. |
| **Deliveries with GPS** | One screen per visit: choose the customer, scan the full cylinders handed over and the empties taken back. The price fills in by itself, and the phone's location is saved with the sale. |
| **Owner dashboard** | Revenue, cylinders sold and deliveries for a period. Sales by area, a daily trend, a map of where deliveries happened, live stock by location, and an overdue list. |
| **Staff and access** | The owner creates logins for staff, sets roles, and can switch access off instantly. |
| **Works offline** | Scans and deliveries save on the phone and sync when signal returns, which matters in godowns and narrow lanes. |

---

## Screens

### Owner dashboard (web)

![Owner dashboard](screenshots/desktop/02-dashboard.png)

Headline numbers for the chosen period, cylinders sold per area, a daily trend,
and a delivery heatmap on OpenStreetMap. Further down: where every cylinder is
now, and the ones that have stayed with a customer for more than 30 days.

<details>
<summary>Full-length dashboard</summary>

![Full dashboard](screenshots/desktop/03-dashboard-full.png)

</details>

### Staff app (phone)

![A delivery round on the staff app](mobile-flow.png)

| Staff home | Scan to load | Customer picker | Delivery |
|---|---|---|---|
| ![](screenshots/mobile/02-staff-home.png) | ![](screenshots/mobile/03-scan-load.png) | ![](screenshots/mobile/04-customer-picker.png) | ![](screenshots/mobile/06-delivery-payment.png) |

| Owner on the phone | Charts | Delivery map | Stock and overdue |
|---|---|---|---|
| ![](screenshots/mobile/07-owner-dashboard.png) | ![](screenshots/mobile/08-owner-dashboard-charts.png) | ![](screenshots/mobile/09-owner-dashboard-map.png) | ![](screenshots/mobile/10-owner-cylinder-status.png) |

### QR labels

| Generate and reprint | Printable A4 sticker sheet |
|---|---|
| ![QR labels page](screenshots/desktop/06-qr-labels.png) | ![Label sheet preview](screenshots/desktop/07-label-sheet.png) |

### Scanning and delivery (web, with a camera)

| Scan in "Load" mode | Delivery to a customer |
|---|---|
| ![Scan](screenshots/desktop/08-scan-load.png) | ![Delivery](screenshots/desktop/09-delivery.png) |

### Cylinders and customers

| All cylinders, filtered by state | One cylinder's full history |
|---|---|
| ![Cylinders](screenshots/desktop/04-cylinders.png) | ![Cylinder history](screenshots/desktop/05-cylinder-history.png) |

| Customers | Customer detail |
|---|---|
| ![Customers](screenshots/desktop/10-customers.png) | ![Customer](screenshots/desktop/11-customer-detail.png) |

### Admin

| Staff and roles | Prices and delivery areas |
|---|---|
| ![Staff](screenshots/desktop/12-staff.png) | ![Settings](screenshots/desktop/13-settings.png) |

### Dark mode

| Dashboard | Cylinder history | Scanner |
|---|---|---|
| ![](screenshots/desktop/14-dashboard-dark.png) | ![](screenshots/desktop/15-cylinder-history-dark.png) | ![](screenshots/desktop/16-scan-dark.png) |

---

## How it works

```mermaid
flowchart LR
  subgraph Phone["Staff app (Android)"]
    S[Scan QR] --> B[One batched write]
  end
  subgraph Web["Owner dashboard (web)"]
    D[Dashboard]
  end
  B -- "event + cylinder + sale + daily total" --> R{Security rules}
  R -->|accepted| F[(Cloud Firestore)]
  F -- "~30 daily docs a month" --> D
  F -. "offline cache" .-> Phone
```

```
orgs/{orgId}                      the business: name, label prefix, next serial
orgs/{orgId}/members/{uid}        admin or staff, active or not
orgs/{orgId}/cylinders/{serial}   where it is, full or empty, who holds it
orgs/{orgId}/events/{id}          every move, immutable
orgs/{orgId}/sales/{id}           every delivery visit, immutable
orgs/{orgId}/daily/{yyyy-MM-dd}   totals per day, per area, per ~1 km cell
orgs/{orgId}/customers/{id}       area, GPS, cylinders currently held
```

## Engineering highlights

**Zero running cost, by design.** Cloud Functions, Cloud Storage and Google Maps
all need a billing account, so none of them are used. Server-side logic lives in
Firestore security rules, maps come from OpenStreetMap through `flutter_map`, and
location comes from the device GPS.

**Security rules do the server's job.** Without a backend, the rules make every
write prove itself:

- A cylinder can change state only together with a new event, written in the
  same batch by the signed-in user. The rules check this with `getAfter()` and
  `at == request.time`, so an old event cannot be replayed.
- The daily sales totals can grow only by exactly one new sale.
- A user can create one business and become its admin. They cannot join someone
  else's business.

**Rules are tested, including the app's real writes.** There are 24 emulator
tests. One of them replays a full day of the app's exact write payloads, from
sign-up through delivery to an admin correction, so a renamed field fails in CI
instead of in a delivery boy's hand.

**A month of analytics in ~30 reads.** Each delivery batch also increments that
day's summary doc: totals, totals per area, and a count per ~1 km geohash cell
for the heatmap. The dashboard never scans the sales collection.

**Staff logins without an admin backend.** Creating another user normally needs
the Admin SDK on a server. Instead, the app starts a throwaway second Firebase
app, creates the user there, and leaves the owner's own session untouched.

**QR codes that work outside the app.** Labels encode
`https://cylinq.web.app/c/{business}/{serial}`. The web app uses path URLs, and
the sign-in redirect remembers where the user was going, so scanning a label with
any phone camera ends on that cylinder.

## Challenges

| Problem | What I did |
|---|---|
| Firestore rules may read at most 20 documents per batch, and each cylinder move reads its event | Large scans are split into batches of 15. A rules test proves that a 16-cylinder delivery passes. |
| Right after "Create business", the app read the new membership before the server had it, and the rules refused | The account listener ignores snapshots with pending local writes, so the session waits for the server's confirmation. Found by end-to-end testing on the live site. |
| A delivery could be saved twice by a double tap | The screen leaves as soon as the save starts, including when it was opened from a link. |
| On phones, the map captured vertical swipes and the dashboard could not scroll | On narrow screens the map is a static overview that ignores touch. |
| A label held in front of the camera re-triggered "already added" every few seconds | Scanning uses a sliding de-duplication window: a label is reported again only after it has been out of view. |

## Testing and verification

- **24 security-rules tests** on the Firestore emulator, run in GitHub Actions on
  every push.
- **20 Dart unit and widget tests:** geohash, QR payload parsing, move
  validation, label PDF generation, stats folding, chart layout.
- **End to end on the live site** with headless Chrome: sign-up, labels, fill,
  load and a GPS-tagged delivery. A fake camera feed of a printed label was used,
  so the real QR scanner read it.

## Tech stack

| Area | Tools |
|---|---|
| App | Flutter 3.44 (Android + web), Dart 3.12, Material 3 |
| State and routing | Riverpod 3, go_router 17 |
| Backend | Firebase Auth (email/password), Cloud Firestore, Firebase Hosting |
| Maps and location | flutter_map + OpenStreetMap, geolocator, geohash cells |
| Scanning and labels | mobile_scanner, qr_flutter, pdf + printing |
| Charts | fl_chart |
| Quality | Firestore emulator + `@firebase/rules-unit-testing`, flutter_test, GitHub Actions |

## By the numbers

| | |
|---|---|
| Dart source | ~6,000 lines in 64 files |
| Security rules | 267 lines, 24 tests |
| Commits | 100+ small, single-purpose commits |
| Running cost | ₹0 a month on the Firebase Spark plan |
| Demo data | 200 cylinders, 90 customers, 388 deliveries, ~3,600 events |

## Design

- Brand: flame orange `#E8590C` on deep navy `#14213D`. Light and dark themes.
- Type: Plus Jakarta Sans.
- Cylinder states use the same colours everywhere: green full, grey empty, blue
  on a vehicle, orange with a customer, red lost.
- Phone layouts are built for one-handed use outdoors: large touch targets, one
  big primary action, and a typed-serial fallback for torn labels.
