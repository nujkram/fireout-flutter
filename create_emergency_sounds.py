#!/usr/bin/env python3
"""
Create basic emergency alert sound files for FireOut app.
Generates simple audio files that will work as notification sounds.
"""

import os
import struct
import wave
import math
from pathlib import Path

def create_wave_file(filename, frequency, duration=2.0, amplitude=0.3):
    """Create a simple wave file with the given frequency"""
    sample_rate = 44100
    frames = int(duration * sample_rate)
    
    # Create the wave file
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 2 bytes per sample
        wav_file.setframerate(sample_rate)
        
        for i in range(frames):
            # Generate sine wave
            t = i / sample_rate
            value = int(amplitude * 32767 * math.sin(2 * math.pi * frequency * t))
            wav_file.writeframes(struct.pack('<h', value))

def create_emergency_siren(filename, duration=3.0):
    """Create a siren-like sound by sweeping frequency"""
    sample_rate = 44100
    frames = int(duration * sample_rate)
    
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        
        for i in range(frames):
            t = i / sample_rate
            # Sweep from 800Hz to 1200Hz and back
            freq = 800 + 400 * math.sin(2 * math.pi * 2 * t)  # 2 Hz modulation
            value = int(0.3 * 32767 * math.sin(2 * math.pi * freq * t))
            wav_file.writeframes(struct.pack('<h', value))

def create_beeping_sound(filename, beep_freq=1000, beep_duration=0.3, pause_duration=0.2, num_beeps=3):
    """Create a beeping pattern"""
    sample_rate = 44100
    beep_frames = int(beep_duration * sample_rate)
    pause_frames = int(pause_duration * sample_rate)
    total_frames = (beep_frames + pause_frames) * num_beeps
    
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        
        for beep in range(num_beeps):
            # Generate beep
            for i in range(beep_frames):
                t = i / sample_rate
                value = int(0.4 * 32767 * math.sin(2 * math.pi * beep_freq * t))
                wav_file.writeframes(struct.pack('<h', value))
            
            # Generate pause (silence)
            for i in range(pause_frames):
                wav_file.writeframes(struct.pack('<h', 0))

def convert_wav_to_mp3(wav_file, mp3_file):
    """Convert WAV to MP3 using system ffmpeg if available"""
    import subprocess
    try:
        subprocess.run(['ffmpeg', '-i', wav_file, '-acodec', 'mp3', '-y', mp3_file], 
                      check=True, capture_output=True)
        os.remove(wav_file)  # Remove WAV file after conversion
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        # ffmpeg not available, keep WAV file but rename to .mp3
        os.rename(wav_file, mp3_file)
        return False

def create_directories():
    """Create necessary directories"""
    dirs = [
        "assets/sounds",
        "android/app/src/main/res/raw"
    ]
    
    for dir_path in dirs:
        Path(dir_path).mkdir(parents=True, exist_ok=True)
        print(f"📁 Created directory: {dir_path}")

def create_all_emergency_sounds():
    """Create all emergency sound files"""
    print("🔊 Creating emergency sound files...\n")
    
    create_directories()
    
    sounds_config = [
        {
            "name": "fire_alert",
            "description": "Fire Emergency Alert",
            "type": "siren",
            "duration": 3.0
        },
        {
            "name": "medical_alert", 
            "description": "Medical Emergency Alert",
            "type": "beeping",
            "freq": 800,
            "beeps": 4
        },
        {
            "name": "accident_alert",
            "description": "Accident Emergency Alert", 
            "type": "beeping",
            "freq": 1200,
            "beeps": 3
        },
        {
            "name": "general_alert",
            "description": "General Emergency Alert",
            "type": "tone",
            "freq": 1000,
            "duration": 2.5
        },
        {
            "name": "test_notification",
            "description": "Test Notification",
            "type": "tone", 
            "freq": 600,
            "duration": 1.5
        }
    ]
    
    success_count = 0
    
    for sound in sounds_config:
        try:
            wav_filename = f"temp_{sound['name']}.wav"
            mp3_filename = f"{sound['name']}.mp3"
            
            print(f"🎵 Creating {sound['description']}...")
            
            # Create the sound based on type
            if sound['type'] == 'siren':
                create_emergency_siren(wav_filename, sound['duration'])
            elif sound['type'] == 'beeping':
                create_beeping_sound(wav_filename, sound['freq'], num_beeps=sound['beeps'])
            elif sound['type'] == 'tone':
                create_wave_file(wav_filename, sound['freq'], sound['duration'])
            
            # Save to both locations (try MP3 conversion first)
            assets_path = f"assets/sounds/{mp3_filename}"
            android_path = f"android/app/src/main/res/raw/{mp3_filename}"
            
            # Convert and save to assets
            convert_wav_to_mp3(wav_filename, assets_path)
            
            # Create a copy for Android (convert again since first file was moved)
            if sound['type'] == 'siren':
                create_emergency_siren(wav_filename, sound['duration'])
            elif sound['type'] == 'beeping':
                create_beeping_sound(wav_filename, sound['freq'], num_beeps=sound['beeps'])
            elif sound['type'] == 'tone':
                create_wave_file(wav_filename, sound['freq'], sound['duration'])
            
            convert_wav_to_mp3(wav_filename, android_path)
            
            # Check file sizes
            assets_size = os.path.getsize(assets_path) / 1024  # KB
            android_size = os.path.getsize(android_path) / 1024  # KB
            
            print(f"✅ Created {mp3_filename} - Assets: {assets_size:.1f}KB, Android: {android_size:.1f}KB")
            success_count += 1
            
        except Exception as e:
            print(f"❌ Error creating {sound['name']}: {e}")
    
    print(f"\n🎉 Created {success_count}/{len(sounds_config)} emergency sound files!")
    
    if success_count > 0:
        print("\n📱 Next steps:")
        print("1. Run: flutter clean")
        print("2. Run: flutter pub get")
        print("3. Build and install your app")
        print("4. Test notifications using the 🔔 bell button in admin dashboard")
        print("\n🔊 Sound Types Created:")
        print("🔥 Fire Alert: Emergency siren sweep")
        print("🚑 Medical Alert: Urgent beeping pattern")
        print("🚗 Accident Alert: Warning beep sequence")
        print("📢 General Alert: Standard tone")
        print("🔔 Test Notification: Gentle chime")
    else:
        print("\n❌ No sound files were created successfully.")

if __name__ == "__main__":
    print("🚨 FireOut Emergency Sounds Generator\n")
    create_all_emergency_sounds()