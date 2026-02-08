---
description: Repository Information Overview
alwaysApply: true
---

Impact Ledger

## Summary
 Impact Ledger is a decentralized platform built with Flutter and anchored on the Cardano blockchain. It aims to verify community environmental actions (like recycling or environmental cleanup) through a crowdsourced, reputation-based system. The app features multi-role support for Organizations and Users/Volunteers, integrating with Firebase for authentication and data storage, and Google Maps for location-based services.

## Structure
- **lib/**: The core Flutter application code.
  - **Organization/**: UI and logic for organization-specific features (dashboards, team management, volunteer coordination).
  - **User/**: UI and logic for user/volunteer features (reporting incidents, reading articles, help center).
  - **Shared/**: Reusable screens and inputs (login, incident posting).
  - **Services/**: Backend service integrations (Firebase Auth, Firestore, Incident uploads).
  - **Models/**: Data models (User, etc.).
  - **Reusables/**: Shared UI components (buttons, input fields).
- **android/**: Android-specific configuration and native code (AGP 8.7.3, Kotlin 2.1.0).
- **ios/**: iOS-specific configuration and native code.
- **assets/ / images/ / pngs/**: Application assets including icons, logos, and map markers.
- **test/**: Unit and widget tests for the Flutter application.
- **app/**: A separate Gradle-based Java/Kotlin placeholder project (boilerplate).

## Language & Runtime
**Language**: Dart (Flutter)  
**Version**: Flutter SDK ^3.6.1, Project Version 1.0.0+1  
**Build System**: Flutter (delegates to Gradle for Android and Xcode for iOS)  
**Package Manager**: pub

## Dependencies
**Main Dependencies**:
- **Firebase**: `firebase_auth`, `firebase_core`, `firebase_storage`, `cloud_firestore`, `firebase_app_check`
- **Maps & Geo**: `google_maps_flutter`, `geolocator`, `geojson_vi`, `flutter_polyline_points`
- **UI & State**: `provider`, `shimmer`, `fl_chart`, `cached_network_image`, `flutter_phoenix`
- **Utilities**: `shared_preferences`, `intl`, `uuid`, `permission_handler`, `image_picker`, `image_cropper`
- **Branding**: `flutter_native_splash`, `flutter_launcher_icons`

**Development Dependencies**:
- `flutter_test` (Flutter SDK)
- `lints: ^5.0.0`

## Build & Installation
```bash
# Install dependencies
flutter pub get

# Run the application (requires a connected device or emulator)
flutter run

# Build Android APK
flutter build apk

# Build iOS App (requires macOS and Xcode)
flutter build ios
```

## Testing
**Framework**: Flutter Test (based on `test` package)
**Test Location**: `test/`
**Naming Convention**: `*_test.dart`
**Configuration**: `analysis_options.yaml`

**Run Command**:
```bash
flutter test
```

## Main Files & Resources
- **Entry Point**: `lib/main.dart`
- **App Wrapper**: `lib/Wrappers/main_wrapper.dart` (handles role-based routing)
- **Configuration**:
  - `pubspec.yaml`: Flutter dependencies and asset configuration.
  - `firebase.json`: Firebase project configuration.
  - `android/app/google-services.json`: Firebase Android configuration.
  - `analysis_options.yaml`: Dart linting rules.
