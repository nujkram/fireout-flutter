# 🔊 How to Re-Enable Custom Sounds

## 🔧 Code Changes Required

In `lib/services/notification_service.dart`, change these 5 lines:

### 1. Fire Alert Sound (Line ~371)
```dart
// Change from:
'sound': null, // Use system default for now

// To:
'sound': kIsWeb ? null : const RawResourceAndroidNotificationSound('fire_alert'),
```

### 2. Medical Alert Sound (Line ~385)
```dart
// Change from:
'sound': null, // Use system default for now

// To:
'sound': kIsWeb ? null : const RawResourceAndroidNotificationSound('medical_alert'),
```

### 3. Accident Alert Sound (Line ~399)
```dart
// Change from:
'sound': null, // Use system default for now

// To:
'sound': kIsWeb ? null : const RawResourceAndroidNotificationSound('accident_alert'),
```

### 4. General Alert Sound (Line ~412)
```dart
// Change from:
'sound': null, // Use system default for now

// To:
'sound': kIsWeb ? null : const RawResourceAndroidNotificationSound('general_alert'),
```

### 5. Test Notification Sound (Line ~514)
```dart
// Change from:
sound: null, // Use system default for now

// To:
sound: kIsWeb ? null : const RawResourceAndroidNotificationSound('test_notification'),
```

## 📋 Complete Process

1. **Download real MP3 files** from Pixabay/Freesound
2. **Place files in Android raw directory** (without .mp3 extension)
3. **Make the 5 code changes above**
4. **Build and test**

```bash
flutter clean
flutter pub get
flutter build apk --debug
flutter install
```

## 🎯 **File Requirements**

Your MP3 files must be named exactly:
- `fire_alert.mp3` → becomes `fire_alert` in raw directory
- `medical_alert.mp3` → becomes `medical_alert` in raw directory  
- `accident_alert.mp3` → becomes `accident_alert` in raw directory
- `general_alert.mp3` → becomes `general_alert` in raw directory
- `test_notification.mp3` → becomes `test_notification` in raw directory

## ⚠️ **Important**

**Don't make the code changes until you have real MP3 files in place**, or you'll get the same "resource not found" error again!