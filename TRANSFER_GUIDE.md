# Project Transfer Guide (Danum)

This guide explains how to move this Flutter project to a different device or environment.

## 1. Exporting the Project
To move the project, you only need the source files. You can safely exclude the bulky build artifacts:
1.  Compress (Zip) the `danum` folder.
2.  **EXCLUDE** the following directories to save space:
    - `build/`
    - `.dart_tool/`
    - `.pub-cache/` (if present)
    - `.idea/` or `.vscode/` (optional, these are IDE settings)

## 2. Importing & Running on a New Device
On the destination device:
1.  **Extract** the project folder.
2.  **Ensure Flutter is installed**:
    - Open a terminal and run `flutter doctor` to verify your setup.
3.  **Fetch Dependencies**:
    - Navigate to the project folder in the terminal.
    - Run: `flutter pub get`
4.  **Run the App**:
    - Connect a device or start an emulator.
    - Run: `flutter run`

## 3. Transitioning to Hardware
When you receive your Arduino/ESP32 hardware:
1.  We will add `firebase_core` and `firebase_database` to the project.
2.  The `LocalSimulationService` will be replaced with a `FirebaseService`.
3.  You will need to add your `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) to the respective folders.
