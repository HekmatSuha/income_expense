# Income–Expense Flutter Starter (Supabase + Drift, Offline-First)

This is a production-ready starter scaffold for a mobile app that tracks income and expenses with **Flutter** (Android/iOS), using:

- **Riverpod** for state management
- **go_router** for navigation
- **Drift (SQLite)** for fast local storage (offline-first)
- **Supabase (PostgreSQL + Auth + Storage)** for sync & cloud features

## Quick Start

1. **Create a Flutter project**
```bash
flutter create income_expense_supabase
cd income_expense_supabase
```

2. **Replace files** with the contents of this starter:
- Copy the `lib/`, `pubspec.yaml`, and `analysis_options.yaml` into your project root (overwrite existing).
- Copy the `supabase/sql/` folder to keep your SQL migrations.

3. **Install packages**
```bash
flutter pub get
```

4. **Create a Supabase project**
- Go to https://app.supabase.com/
- Create a new project (choose a nearby region, e.g. eu-central-1 / Frankfurt).
- In the SQL editor, run the SQL from `supabase/sql/schema.sql` then `supabase/sql/policies.sql`.
- Get your project **URL** and **anon key** from Project Settings → API.

5. **Set your Supabase keys**
Edit `lib/app/secrets.dart` and paste:
```dart
const supabaseUrl = "<YOUR_SUPABASE_URL>";
const supabaseAnonKey = "<YOUR_SUPABASE_ANON_KEY>";
```

6. **Run the app**
```bash
flutter run -d android    # or -d ios, -d chrome
```

## Features in this starter
- Email/password auth (Supabase)
- Add/list income & expense transactions
- Local DB (Drift) for instant UX even when offline
- Basic repository pattern to later add bidirectional sync
- Clean app structure prepared for charts, export, attachments

## Roadmap (next steps)
- Implement sync (push/pull) between Drift and Supabase
- Add categories CRUD & filters
- Add charts (weekly/monthly) with fl_chart
- Add CSV export and receipt photo uploads (Supabase Storage)
- Multi-currency and localization (intl)

Happy building! 🚀
