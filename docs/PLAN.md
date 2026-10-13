# CylinQ — build plan

CylinQ tracks every gas cylinder of a distributor with a QR label and turns each
delivery into location-tagged sales data.

## Hard constraint: zero running cost

The Firebase project stays on the **Spark (no-cost) plan**. No billing account,
no card. That rules out some products, so the design works around them:

| Need | Used | Not used (needs billing) |
|---|---|---|
| Sign-in | Firebase Auth, Email/Password | Phone OTP |
| Data | Cloud Firestore (free daily quota) | — |
| Server logic | Security rules + client batched writes | Cloud Functions |
| Images | Compressed JPEG (≤ 60 KB) as base64 in Firestore, only if needed | Cloud Storage |
| Maps | `flutter_map` + OpenStreetMap tiles | Google Maps Platform |
| Location | Device GPS (`geolocator`) | Geocoding API |
| Admin web | Firebase Hosting (`cylinq.web.app`) | — |

## Data model

All app data lives under `orgs/{orgId}` so several businesses (or another app in
the same Firebase project) never collide.

```
accounts/{uid}                    orgId, role            ← where a user lands after login
orgs/{orgId}                      name, ownerUid, labelPrefix, nextSerial
orgs/{orgId}/members/{uid}        name, email, role (admin | staff), active
orgs/{orgId}/types/{typeId}       name, weightKg, price
orgs/{orgId}/areas/{areaId}       name, pincode
orgs/{orgId}/customers/{id}       name, phone, address, areaId, geo, holding
orgs/{orgId}/cylinders/{serial}   typeId, status, holder, lastGeo, lastEventId
orgs/{orgId}/events/{id}          one cylinder movement (audit trail, immutable)
orgs/{orgId}/sales/{id}           one delivery visit: given[], taken[], amount, geo
orgs/{orgId}/daily/{yyyy-MM-dd}   totals, per-area totals, geohash heat cells
```

Without Cloud Functions the app writes the event, the cylinder update and the
daily totals in **one batch**. Security rules use `getAfter()` to check that
every cylinder change and every daily-total change is backed by a new event or
sale written in that same batch by the signed-in user.

## Cylinder lifecycle

```
            fill               load               deliver
 empty@godown ──► full@godown ──► in vehicle ──────► with customer
      ▲                               │                    │
      └──────── return ◄──────────────┘◄─── collect empty ─┘
```

Statuses: `empty`, `full`, `vehicle`, `customer`, `lost`, `retired`.

## Phases

0. Scaffold, theme, Firebase config
1. Auth, business setup, roles, staff management
2. Cylinder types, QR label generation, PDF print / download
3. Scanner and movements (fill, load, deliver + collect, return)
4. Customers and areas, GPS on delivery
5. Dashboard: area-wise sales, heatmap, cylinder status, overdue cylinders
6. Rules tests (emulator), web deploy, Android release

## UI

- Material 3, flame orange `#E8590C` on deep navy `#14213D`, light and dark.
- Font: Plus Jakarta Sans.
- Staff (phone): bottom navigation, one big **Scan** action.
- Admin (web): sidebar with Dashboard, Cylinders, Labels, Customers, Areas, Staff.
- Status colours: full green, empty grey, vehicle blue, customer orange, lost red.
