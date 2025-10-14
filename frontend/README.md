# Income–Expense Flutter Starter (Firebase + Drift, Offline-First)

This is a production-ready starter scaffold for a mobile app that tracks income and expenses with **Flutter** (Android/iOS), using:

- **Riverpod** for state management
- **go_router** for navigation
- **Drift (SQLite)** for fast local storage (offline-first)
- **Firebase (Auth)** for sync & cloud features

## Quick Start

1. **Create a Flutter project**
```bash
flutter create income_expense_firebase
cd income_expense_firebase
```

2. **Replace files** with the contents of this starter:
- Copy the `lib/`, `pubspec.yaml`, and `analysis_options.yaml` into your project root (overwrite existing).
- If you plan to add Firestore/Storage later, create a `/firebase/` folder (optional) to keep configuration notes.

3. **Install packages**
```bash
flutter pub get
```

4. **Create a Firebase project**
- Go to https://console.firebase.google.com/
- Create a new project and add the platforms you plan to target (Android, iOS, Web, etc.).
- Enable Email/Password authentication in **Build → Authentication → Sign-in method**.
- Create a web app (or use the FlutterFire CLI) and copy the configuration values (API key, app ID, etc.).

5. **Set your Firebase configuration**
Edit `lib/app/secrets.dart` and replace the placeholder values inside `firebaseOptions` with your Firebase project configuration.

6. **Run the app**
```bash
flutter run -d android    # or -d ios, -d chrome
```

### Web builds

The web build depends on [`sql.js`](https://sql.js.org) so that Drift can run
SQLite in the browser. The Flutter web `index.html` loads the library from the
jsDelivr CDN and automatically points Drift to the hosted `.wasm` asset. If you
need to serve the Flutter web build from an offline environment, mirror the
`sql.js` files yourself and update `web/drift-sqljs-loader.js` accordingly.

## Features in this starter
- Email/password auth (Firebase Auth)
- Add/list income & expense transactions
- Local DB (Drift) for instant UX even when offline
- Basic repository pattern to later add bidirectional sync
- Clean app structure prepared for charts, export, attachments

## Roadmap (next steps)
- Implement sync (push/pull) between Drift and Firestore
- Add categories CRUD & filters
- Add charts (weekly/monthly) with fl_chart
- Add CSV export and receipt photo uploads (Firebase Storage)
- Multi-currency and localization (intl)

Happy building! 🚀
