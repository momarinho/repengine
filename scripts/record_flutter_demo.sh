#!/usr/bin/env bash
set -euo pipefail

ADB="/home/mateus/Android/Sdk/platform-tools/adb"
VIDEO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../docs/videos" && pwd)"
mkdir -p "$VIDEO_DIR"

echo "=========================================================="
echo "🎬 Starting Automated Flutter Native App Recording"
echo "=========================================================="

# 1. Verify emulator is ready
$ADB wait-for-device
echo "✅ Android emulator detected."

# 2. Enable visual touch circles
$ADB shell settings put system show_touches 1

# 3. Clean start RepEngine Mobile
echo "🔄 Clearing and restarting RepEngine Mobile..."
$ADB shell pm clear com.repengine.repengine_mobile >/dev/null
$ADB shell am start -n com.repengine.repengine_mobile/.MainActivity >/dev/null
sleep 3

# 4. Start screen recording in background
echo "📹 Launching adb screenrecord (1080x2340, 60fps)..."
$ADB shell rm -f /sdcard/flutter_raw_demo.mp4
# Launch screenrecord in background via adb
$ADB shell "screenrecord --bit-rate 10000000 --size 1080x2340 --time-limit 40 /sdcard/flutter_raw_demo.mp4" &
RECORD_PID=$!

sleep 2

# Scene 1: Dashboard overview
echo "[Scene 1] Exploring routines on Kanagawa Dark Dashboard..."
sleep 2.5

# Scene 2: Start Workout A
echo "[Scene 2] Tapping 'START WORKOUT A (GZCLP HYBRID)'..."
$ADB shell input tap 720 2956
sleep 2.5

# Scene 3: Adjust load and reps using thumb zone
echo "[Scene 3] Tapping +2.5kg on load..."
$ADB shell input tap 458 2703
sleep 0.8

echo "[Scene 3] Tapping +1 on reps..."
$ADB shell input tap 1172 2700
sleep 1.2

# Scene 4: Open Plate Calculator
echo "[Scene 4] Opening Plate Calculator..."
$ADB shell input tap 485 2457
sleep 2.8

echo "[Scene 4] Closing Plate Calculator..."
$ADB shell input tap 720 500
sleep 1.5

# Scene 5: Log Set & Rest HUD
echo "[Scene 5] Logging Set 1..."
$ADB shell input tap 720 2910
sleep 4.5 # Let native Canvas rest timer visibly tick down

# Scene 6: Skip Rest to advance to Set 2
echo "[Scene 6] Skipping Rest timer..."
$ADB shell input tap 1278 242
sleep 2.5 # See Set 2 auto-carry-forward and green checkmark pill

# Scene 7: Log Set 2
echo "[Scene 7] Logging Set 2 (instant 1-tap logging)..."
$ADB shell input tap 720 2910
sleep 3.5

# Scene 8: Finish Session
echo "[Scene 8] Opening finish workout flow..."
$ADB shell input tap 1278 242
sleep 2.5

# Stop screen recording
echo "🛑 Stopping screen recording..."
kill -INT "$RECORD_PID" 2>/dev/null || true
# Also kill on device just in case
$ADB shell pkill -INT -f screenrecord 2>/dev/null || true
sleep 3

# Pull recording
RAW_MP4="$VIDEO_DIR/repengine-flutter-mobile-raw.mp4"
FINAL_MP4="$VIDEO_DIR/repengine-flutter-mobile-demo.mp4"

echo "📥 Pulling video from emulator..."
$ADB pull /sdcard/flutter_raw_demo.mp4 "$RAW_MP4"
$ADB shell rm -f /sdcard/flutter_raw_demo.mp4

# Optimize with FFmpeg
echo "⚙️ Optimizing with FFmpeg (H.264, 60fps, faststart)..."
ffmpeg -y -i "$RAW_MP4" \
  -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p \
  -profile:v high -level 4.2 -movflags +faststart \
  "$FINAL_MP4"

rm -f "$RAW_MP4"

# Generate thumbnails
echo "📸 Generating high-res thumbnails..."
ffmpeg -y -ss 00:00:08 -i "$FINAL_MP4" -vframes 1 -q:v 2 "$VIDEO_DIR/demo-flutter-thumbnail-hud.png" 2>/dev/null || true
ffmpeg -y -ss 00:00:16 -i "$FINAL_MP4" -vframes 1 -q:v 2 "$VIDEO_DIR/demo-flutter-thumbnail-rest.png" 2>/dev/null || true

echo "=========================================================="
echo "🎉 SUCCESS: Flutter Native Video Recorded at:"
echo "   $FINAL_MP4"
echo "=========================================================="
ls -lh "$FINAL_MP4" "$VIDEO_DIR"/demo-flutter-thumbnail-*.png
