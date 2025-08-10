# 🔊 Emergency Alert Sounds - Download Guide

## Quick Solution: Download Emergency Sounds

### 1. **Free Sources (Recommended)**

#### **Uppbeat.io** (Best Option)
- Go to: https://uppbeat.io/sfx/category/emergency
- Create free account
- Download these sounds:
  - **"Emergency siren alert (Single)"** → `fire_alert.mp3`
  - **"Police car emergency beeping"** → `accident_alert.mp3` 
  - **"Amber alert - emergency notification"** → `medical_alert.mp3`
  - **"Smoke detector beeping"** → `general_alert.mp3`
  - Any short notification sound → `test_notification.mp3`

#### **Mixkit.co** (Alternative)
- Go to: https://mixkit.co/free-sound-effects/alarm/
- No account needed
- Download alarm sounds for each type

#### **Pixabay.com**
- Go to: https://pixabay.com/sound-effects/search/emergency/
- Create free account
- Search for: "fire alarm", "ambulance", "emergency siren"

### 2. **Sound Requirements**
- **Format**: MP3
- **Duration**: 3-5 seconds max
- **File Size**: Under 1MB each
- **Quality**: 44.1kHz, 16-bit recommended

### 3. **File Names (IMPORTANT)**
Your downloaded files must be renamed to exactly:
- `fire_alert.mp3`
- `medical_alert.mp3` 
- `accident_alert.mp3`
- `general_alert.mp3`
- `test_notification.mp3`

### 4. **Installation Steps**

#### Step 1: Place Files
```bash
# Copy your downloaded and renamed MP3 files to BOTH locations:

# Location 1: Flutter assets (optional)
cp *.mp3 assets/sounds/

# Location 2: Android raw resources (REQUIRED)
cp *.mp3 android/app/src/main/res/raw/
```

#### Step 2: Verify Placement
```bash
ls -la assets/sounds/
ls -la android/app/src/main/res/raw/
```

### 5. **Test the Implementation**

1. **Build the app**:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --debug
   ```

2. **Install and test**:
   ```bash
   flutter install
   ```

3. **Test notifications**:
   - Open admin dashboard
   - Tap the 🔔 bell icon next to refresh
   - You should hear the test notification sound

4. **Test incident notifications**:
   - Create different incident types (Fire, Medical, Accident)
   - Change status to IN-PROGRESS
   - Each should play its specific alert sound

## Alternative: Use Default System Sounds

If you prefer not to download custom sounds, I can modify the code to use system default sounds:

```dart
// Use system default instead of custom sound
sound: null, // This will use system default
```

## Emergency Sound Recommendations

### 🔥 Fire Alert (`fire_alert.mp3`)
- Fire truck siren
- Fire alarm bell
- Urgent beeping pattern
- **Example searches**: "fire alarm", "fire truck siren", "smoke detector"

### 🚑 Medical Alert (`medical_alert.mp3`)
- Ambulance siren
- Medical equipment beeping
- Hospital alert tone
- **Example searches**: "ambulance siren", "medical alert", "hospital alarm"

### 🚗 Accident Alert (`accident_alert.mp3`)
- Warning buzzer
- Traffic alert sound
- Emergency broadcast tone
- **Example searches**: "warning buzzer", "emergency alert", "accident alarm"

### 📢 General Alert (`general_alert.mp3`)
- Standard emergency alert
- Generic alarm tone
- Official alert sound
- **Example searches**: "emergency alert", "notification alarm", "general alarm"

### 🔔 Test Notification (`test_notification.mp3`)
- Pleasant chime
- Soft bell
- Non-urgent notification sound
- **Example searches**: "notification chime", "soft bell", "phone notification"

## Troubleshooting

### Sound Not Playing?
1. Check file names match exactly (case-sensitive)
2. Ensure files are in `android/app/src/main/res/raw/`
3. Rebuild the app: `flutter clean && flutter build apk`
4. Check Android notification permissions

### File Too Large?
- Use online compressor: https://www.mp3smaller.com/
- Keep under 1MB per file
- Trim to 3-5 seconds max

### Need Custom Sounds?
Use **Audacity** (free) to:
- Trim sounds to desired length
- Adjust volume levels
- Convert between formats
- Create fade in/out effects

## Current Status ✅
- ✅ Sound system implemented
- ✅ File structure created  
- ✅ Test notification working
- ❌ Real audio files needed

Once you add the audio files, your incident notification system will be complete with custom emergency alert sounds!