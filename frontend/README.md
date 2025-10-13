# Income–Expense Flutter Starter (Firebase + Drift, Offline-First)

This is a production-ready starter scaffold for a mobile app that tracks income and expenses with **Flutter** (Android/iOS), using:

- **Riverpod** for state management
- **go_router** for navigation
- **Drift (SQLite)** for fast local storage (offline-first)
- **Firebase (Auth)** for sync & cloud features

## Quick Start

1. **Create a Flutter project**
```bash
flutter create income_expense_supabase
cd income_expense_supabase
```

2. **Replace files** with the contents of this starter:
- Copy the `lib/`, `pubspec.yaml`, and `analysis_options.yaml` into your project root (overwrite existing).

3. **Install packages**
```bash
flutter pub get
```

4. **Create a Firebase project**
- Go to https://console.firebase.google.com/
- Create a new project (choose a nearby region).
- Enable **Email/Password** authentication in Authentication → Sign-in methods.
- Create a web or mobile app in your Firebase project and copy the generated Firebase configuration (API key, App ID, etc.).

5. **Set your Firebase configuration**
Edit `lib/app/secrets.dart` and paste your `FirebaseOptions`:
```dart
FirebaseOptions? get firebaseOptions => const FirebaseOptions(
  apiKey: "<YOUR_FIREBASE_API_KEY>",
  appId: "<YOUR_FIREBASE_APP_ID>",
  messagingSenderId: "<YOUR_FIREBASE_MESSAGING_SENDER_ID>",
  projectId: "<YOUR_FIREBASE_PROJECT_ID>",
  storageBucket: "<YOUR_FIREBASE_STORAGE_BUCKET>", // optional
);
```

6. **Run the app**
```bash
flutter run -d android    # or -d ios, -d chrome
```

## Features in this starter
- Email/password auth (Firebase)
- Add/list income & expense transactions
- Local DB (Drift) for instant UX even when offline
- Basic repository pattern to later add bidirectional sync
- Clean app structure prepared for charts, export, attachments

## Roadmap (next steps)
- Implement sync (push/pull) between Drift and Firebase (e.g. Firestore)
- Add categories CRUD & filters
- Add charts (weekly/monthly) with fl_chart
- Add CSV export and receipt photo uploads (Firebase Storage)
- Multi-currency and localization (intl)

Happy building! 🚀
