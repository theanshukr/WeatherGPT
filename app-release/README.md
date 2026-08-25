# WeatherGPT Android Application Release (v1.0.0)

This directory contains the production release package for the **WeatherGPT** mobile application.

---

## 📦 Package Information

| Attribute | Details |
|---|---|
| **Application Name** | WeatherGPT |
| **Package ID** | `com.weathergpt.app` |
| **Version** | `1.0.0` (Build 1) |
| **Target Platform** | Android 7.0 (API Level 24) and higher |
| **Architecture** | `arm64-v8a`, `armeabi-v7a`, `x86_64` (Universal APK) |
| **File Name** | [`WeatherGPT-v1.0.0.apk`](file:///d:/WeatherGPT/app-release/WeatherGPT-v1.0.0.apk) |
| **File Size** | ~56.7 MB |

---

## 🔒 File Verification & Checksums

To verify that your downloaded package has not been tampered with or corrupted:

- **SHA-256 Hash**:
  ```text
  E9E36B1B997C80828B0BDC6BC1D16E16868CCA69BC805FADAA38BD09CE830AFD
  ```

- **SHA-1 Hash**:
  ```text
  934939A5E6E360B175EA886D6E3264BAD70D1447
  ```

### Verification Commands

- **PowerShell (Windows)**:
  ```powershell
  Get-FileHash -Algorithm SHA256 .\WeatherGPT-v1.0.0.apk
  ```
- **Terminal (Linux / macOS)**:
  ```bash
  sha256sum WeatherGPT-v1.0.0.apk
  ```

---

## 📱 Installation Guide

1. **Download the APK**: Download [`WeatherGPT-v1.0.0.apk`](file:///d:/WeatherGPT/app-release/WeatherGPT-v1.0.0.apk) onto your Android device.
2. **Enable Unknown Sources**:
   - Go to **Settings > Security / Privacy**.
   - Enable **Install Unknown Apps** for your Browser or File Manager.
3. **Install App**: Tap on `WeatherGPT-v1.0.0.apk` and confirm **Install**.
4. **Permissions Granted**:
   - 📍 **Location**: For hyperlocal GPS weather forecasting and radar alignment.
   - 🎙️ **Microphone**: For voice interaction with **LIX** (AI Assistant).
   - 🔔 **Notifications**: For severe weather alerts and precipitation notifications.

---

## 🌐 Backend Connectivity

By default, the app is pre-configured to connect to the live cloud backend:
```text
https://weathergpt-backend-3n4b.onrender.com/api/v1
```

If running the backend locally on your computer:
1. Ensure your mobile phone and PC are connected to the same Wi-Fi network.
2. In the app settings screen, update the **Custom Server IP** to your local server IP (e.g. `http://192.168.1.100:8000/api/v1`).
