# Wear OS Emulator Guide for ScoreBot

This document walks you through testing **ScoreBot** on a Wear OS emulator using Android Studio and Flutter.

---

## Prerequisites

1. **Android Studio** (latest stable) with the **Android SDK** installed.
2. **Flutter SDK** (already set up in the project).
3. **Wear OS system image** for the desired API level (e.g., API 33 – Wear OS 4).
4. The **watch flavor** of the app (`watch`) must be defined in `android/app/build.gradle.kts` (already present).
5. Sufficient disk space on the emulator (at least 200 MiB free). The debug APK can be > 1 GB; we recommend using the **release** build to keep the size ~20 MiB.

---

## 1. Create a Wear OS AVD

1. Open **Android Studio** → **Tools** → **AVD Manager**.
2. Click **Create Virtual Device**.
3. In the **Category** list, select **Wear OS**.
4. Choose a device (e.g., **Wear OS Small Round**) and click **Next**.
5. On the **System Image** screen, select a **Wear OS** system image (preferably API 33, release‑candidate). Click **Download** if not already available, then **Next**.
6. Give the AVD a name, e.g., `Wear_OS_Small_Round`, and leave the default **Graphics** option (Automatic). Click **Finish**.

---

## 2. Launch the Emulator

```powershell
# From the project root folder
cd C:\Users\moham\.gemini\antigravity\scratch\score_bot

# Start the AVD (replace the name if you used a different one)
"%ANDROID_SDK_ROOT%\emulator\emulator.exe" -avd Wear_OS_Small_Round
```

The emulator will boot. It may take a minute on first launch.

---

## 3. Verify the Emulator is Recognised by Flutter

```powershell
flutter devices
```
You should see an entry similar to:
```
1️⃣  sdk gwear x86 64   • emulator-5554 • android-x64   • Android 17 (API 37) (emulator)
```
If the device does **not** appear, run:
```powershell
adb devices
adb wait-for-device
```
and ensure the emulator is listed as `emulator-5554`.

---

## 4. Build a Lightweight Release APK

The debug APK contains un‑stripped native libraries and can be > 1 GB, which exceeds the emulator's storage. Build the **release** APK for the watch flavor:

```powershell
# From the project root
flutter build apk --flavor watch --target-platform android-x64 --release
```
The output will be located at:
```
build/app/outputs/flutter-apk/app-watch-release.apk
```
Typical size: **≈ 20 MiB**.

---

## 5. Install the APK on the Emulator

```powershell
adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-watch-release.apk
```
You should see `Success`. If you encounter *insufficient space* errors, free space with:
```powershell
adb -s emulator-5554 shell "rm -rf /data/local/tmp/*"
adb -s emulator-5554 uninstall com.scorebot.score_bot   # optional, removes any previous version
```
Then retry the install command.

---

## 6. Launch the App

```powershell
adb -s emulator-5554 shell am start -n com.scorebot.score_bot/.MainActivity
```
The app’s UI should appear on the Wear OS emulator.

### Handling Runtime Permissions

ScoreBot requests the microphone for voice commands. When the permission dialog appears on the emulator, click **Allow**. To automate this step you can use:
```powershell
# Approximate coordinates – adjust if needed
adb -s emulator-5554 shell input tap 540 960   # taps the "Allow" button
```

---

## 7. Run the App Directly with Flutter (optional)

If you prefer Flutter to handle the install & launch, use the release flag:
```powershell
flutter run --flavor watch -d emulator-5554 --release
```
*Do NOT use the plain `flutter run` command for the watch flavor, as it builds the large debug APK which fails to install.*

---

## 8. Common Troubleshooting

| Symptom | Fix |
|---------|-----|
| **Emulator never boots** | Increase RAM/VM heap in AVD settings, or use a smaller device profile. |
| **`flutter devices` shows no watch** | Ensure the emulator is running, then run `adb devices`. Restart ADB with `adb kill-server && adb start-server`. |
| **`adb install` fails with `INSTALL_FAILED_INSUFFICIENT_STORAGE`** | Clean temporary files (`rm -rf /data/local/tmp/*`) and uninstall any previous build (`adb uninstall <package>`). |
| **App launches but UI stays blank** | Check logcat: `adb -s emulator-5554 logcat | Select-String "ScoreBot"`. Look for crashes or missing resources. |
| **Microphone permission dialog never appears** | Manually grant permission: `adb -s emulator-5554 shell pm grant com.scorebot.score_bot android.permission.RECORD_AUDIO`. |

---

## 9. Quick Recap of Commands

```powershell
# 1️⃣ Start emulator (run once per session)
%ANDROID_SDK_ROOT%\emulator\emulator.exe -avd Wear_OS_Small_Round

# 2️⃣ Verify device
flutter devices

# 3️⃣ Build lightweight release APK
flutter build apk --flavor watch --target-platform android-x64 --release

# 4️⃣ Install APK
adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-watch-release.apk

# 5️⃣ Launch app
adb -s emulator-5554 shell am start -n com.scorebot.score_bot/.MainActivity
```

You can now interact with ScoreBot on the Wear OS emulator and test voice‑driven commands.

---

*Document maintained in the project repository under `docs/WEAR_OS_EMULATOR_GUIDE.md`.*
