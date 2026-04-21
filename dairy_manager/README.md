# dairy_manager

A new Flutter project.

## Backend URL Setup (Important)

The app reads backend base URL from compile-time variable `API_BASE_URL`.

Use this when running on a physical device or creating production builds:

```bash
flutter run --dart-define=API_BASE_URL=https://your-backend-domain
```

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-backend-domain
```

Notes:

- `0.0.0.0` is a server bind address, not a client URL. Do not use it in Flutter API calls.
- Android emulator local backend uses `http://10.0.2.2:5000` by default.
- iOS simulator and desktop local backend use `http://127.0.0.1:5000` by default.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
