# 💧 Danum Monitor

<div align="center">

<img src="web/icons/Icon-Danum.jpeg" alt="Danum Logo" width="140" style="border-radius: 50%; box-shadow: 0 4px 20px rgba(2, 132, 199, 0.4);" />

### Smart IoT Water Quality & Telemetry Monitoring System

[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web-blue.svg)](https://github.com/CleanLink001/Danum)
[![Flutter](https://img.shields.io/badge/Built%20With-Flutter-02569B?logo=flutter)](https://flutter.dev)
[![Release](https://img.shields.io/badge/Release-v1.0.1-emerald.svg)](https://github.com/CleanLink001/Danum/releases)
[![License](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

<br/>

<a href="https://github.com/CleanLink001/Danum/raw/main/app-release.apk">
  <img src="https://img.shields.io/badge/📥_Download_APK-Direct_Download_(v1.0.1)-0284C7?style=for-the-badge&logo=android&logoColor=white" alt="Download APK" />
</a>
&nbsp;&nbsp;
<a href="https://github.com/CleanLink001/Danum/releases">
  <img src="https://img.shields.io/badge/📦_GitHub_Releases-View_All-475569?style=for-the-badge&logo=github&logoColor=white" alt="Releases" />
</a>

</div>

---

## 📱 Download & Installation

You can download and install the Android app directly from this repository:

### Direct Download Links
* **Direct APK Download**: [app-release.apk (v1.0.1)](https://github.com/CleanLink001/Danum/raw/main/app-release.apk)
* **GitHub Releases**: [Latest Release](https://github.com/CleanLink001/Danum/releases/latest)
* **Repository**: [`https://github.com/CleanLink001/Danum.git`](https://github.com/CleanLink001/Danum.git)

### Android Installation Steps
1. Click **[Download APK (v1.0.1)](https://github.com/CleanLink001/Danum/raw/main/app-release.apk)** to save `app-release.apk` to your phone or tablet.
2. Once the download finishes, tap the notification or locate the file in your **Downloads** folder.
3. If Android prompts that installation from unknown sources is restricted:
   - Tap **Settings** in the prompt.
   - Toggle **Allow from this source** (for Chrome, Drive, or your file manager).
4. Tap **Install** and open **Danum Monitor**.

---

## ✨ Features

- **Real-Time Water Telemetry**: Live tracking of pH levels, Turbidity (NTU), Total Dissolved Solids (TDS in ppm), and Water Temperature (°C).
- **Solar & Battery Telemetry**: Monitor solar voltage, battery charge percentages, charging state, and power efficiency.
- **Dynamic 3-Droplet Loading Screen**: Fluid 3-water-droplet circular chase animation that smoothly transitions when navigating through tabs and loading data.
- **Intelligent Threshold Alerts**: Instant notifications and safety advisories when water parameters deviate from safe standards.
- **Audit & Analytics Reports**: Interactive charts, historical trends, and exportable water quality reports.
- **Trilingual Localization Interface**: 100% complete app-wide language switching between English, Filipino (Tagalog), and authentic Kapampangan (Pampango).

---

## 🚀 Development & Build

### Prerequisites
- [Flutter SDK](https://flutter.dev) (v3.11+ / Dart 3.11+)
- [Android Studio](https://developer.android.com/studio) or Android Command-line Tools

### Run Locally
```bash
# Clone the repository
git clone https://github.com/CleanLink001/Danum.git
cd Danum

# Install Flutter dependencies
flutter pub get

# Run on connected device or emulator
flutter run
```

### Build Release APK
```bash
flutter build apk --release
```
The compiled APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📄 License
This project is open source and available under the MIT License.
