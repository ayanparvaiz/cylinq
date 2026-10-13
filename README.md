# CylinQ

Track every gas cylinder with a QR label, and see where your sales happen.

- **Staff app (Android):** scan cylinders as they are filled, loaded, delivered
  and returned. Each delivery is saved with the phone's GPS position.
- **Admin dashboard (web):** sales by area, a delivery heatmap, where each
  cylinder is right now, and which cylinders have stayed with a customer too long.
- **QR labels:** generate serials and print them as A4 sticker sheets or thermal
  labels, or download the PDF.

Runs entirely on the Firebase **Spark (free) plan**: Auth, Firestore and Hosting
only. No Cloud Functions, no Cloud Storage, no Google Maps key. See
[docs/PLAN.md](docs/PLAN.md) for the design.

## Stack

Flutter (Android + web) · Riverpod · go_router · Cloud Firestore · Firebase Auth ·
flutter_map (OpenStreetMap) · pdf / printing · mobile_scanner

## Run

```sh
flutter pub get
flutter run -d chrome     # admin dashboard
flutter run -d android    # staff app
```
