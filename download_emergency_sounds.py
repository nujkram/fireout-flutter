#!/usr/bin/env python3
"""
Emergency Sounds Downloader for FireOut Flutter App
Downloads Creative Commons emergency alert sounds for incident notifications.
"""

import os
import requests
import time
from pathlib import Path

# Sound URLs from Creative Commons sources
EMERGENCY_SOUNDS = {
    "fire_alert.mp3": "https://cdn.pixabay.com/download/audio/2022/01/18/audio_d1f0e78c12.mp3?filename=fire-alarm-6068.mp3",
    "medical_alert.mp3": "https://cdn.pixabay.com/download/audio/2021/08/04/audio_12b0c7d710.mp3?filename=ambulance-siren-7005.mp3", 
    "accident_alert.mp3": "https://cdn.pixabay.com/download/audio/2022/03/11/audio_6de1fdb7df.mp3?filename=emergency-alarm-with-reverb-29431.mp3",
    "general_alert.mp3": "https://cdn.pixabay.com/download/audio/2021/08/04/audio_bb630c3ba0.mp3?filename=notification-sound-7062.mp3",
    "test_notification.mp3": "https://cdn.pixabay.com/download/audio/2022/03/15/audio_d2b6fee817.mp3?filename=positive-notification-31342.mp3"
}

def download_file(url, filename, max_retries=3):
    """Download a file with retry logic"""
    for attempt in range(max_retries):
        try:
            print(f"📥 Downloading {filename}... (attempt {attempt + 1})")
            
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            
            response = requests.get(url, headers=headers, timeout=30)
            response.raise_for_status()
            
            # Check if it's actually an audio file
            if 'audio' not in response.headers.get('content-type', '') and len(response.content) < 1000:
                print(f"⚠️  Warning: {filename} might not be a valid audio file")
            
            return response.content
            
        except requests.RequestException as e:
            print(f"❌ Error downloading {filename}: {e}")
            if attempt < max_retries - 1:
                print(f"🔄 Retrying in 2 seconds...")
                time.sleep(2)
            else:
                print(f"💥 Failed to download {filename} after {max_retries} attempts")
                return None

def create_directories():
    """Create necessary directories"""
    dirs = [
        "assets/sounds",
        "android/app/src/main/res/raw"
    ]
    
    for dir_path in dirs:
        Path(dir_path).mkdir(parents=True, exist_ok=True)
        print(f"📁 Created directory: {dir_path}")

def download_emergency_sounds():
    """Download all emergency sound files"""
    print("🔊 Starting emergency sounds download...\n")
    
    create_directories()
    
    success_count = 0
    total_count = len(EMERGENCY_SOUNDS)
    
    for filename, url in EMERGENCY_SOUNDS.items():
        content = download_file(url, filename)
        
        if content:
            try:
                # Save to both locations
                assets_path = f"assets/sounds/{filename}"
                android_path = f"android/app/src/main/res/raw/{filename}"
                
                # Save to assets
                with open(assets_path, 'wb') as f:
                    f.write(content)
                
                # Save to Android raw resources
                with open(android_path, 'wb') as f:
                    f.write(content)
                
                file_size = len(content) / 1024  # KB
                print(f"✅ Saved {filename} ({file_size:.1f} KB) to both locations")
                success_count += 1
                
            except Exception as e:
                print(f"❌ Error saving {filename}: {e}")
        
        # Small delay between downloads
        time.sleep(1)
    
    print(f"\n🎉 Download complete: {success_count}/{total_count} files downloaded successfully")
    
    if success_count > 0:
        print("\n📱 Next steps:")
        print("1. Run: flutter clean")
        print("2. Run: flutter pub get") 
        print("3. Build and test your app")
        print("4. Test notifications using the 🔔 bell button in admin dashboard")
    else:
        print("\n❌ No files were downloaded successfully.")
        print("Try the manual download method in get_emergency_sounds.md")

def create_placeholder_sounds():
    """Create placeholder sound files for testing"""
    print("🔊 Creating placeholder sound files...\n")
    
    create_directories()
    
    # Create very short silence files as placeholders
    silence_mp3_data = bytes([
        0xFF, 0xFB, 0x90, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ])
    
    for filename in EMERGENCY_SOUNDS.keys():
        assets_path = f"assets/sounds/{filename}"
        android_path = f"android/app/src/main/res/raw/{filename}"
        
        # Save placeholder to both locations
        with open(assets_path, 'wb') as f:
            f.write(silence_mp3_data)
        
        with open(android_path, 'wb') as f:
            f.write(silence_mp3_data)
        
        print(f"📄 Created placeholder {filename}")
    
    print("\n✅ Placeholder files created.")
    print("⚠️  These are silent placeholders. Download real sounds using the guide in get_emergency_sounds.md")

if __name__ == "__main__":
    print("🚨 FireOut Emergency Sounds Downloader\n")
    
    choice = input("Choose option:\n1. Download real emergency sounds (recommended)\n2. Create placeholder files only\nEnter choice (1 or 2): ").strip()
    
    if choice == "1":
        download_emergency_sounds()
    elif choice == "2":
        create_placeholder_sounds()
    else:
        print("Invalid choice. Please run again and choose 1 or 2.")