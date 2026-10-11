#!/bin/bash
set -e

# VideoHashKit iOS Demo App Launcher
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo "==================================================================="
echo "  📱 VideoHashKit — iOS Demo App Launcher"
echo "  Temporal Perceptual Dual-Hash (dHash + pHash) • Zero-Thermal Video"
echo "==================================================================="

echo "🔨 Verifying iOS Demo build in Xcode..."
xcodebuild -project Demo/Demo.xcodeproj -scheme Demo -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build

echo ""
echo "✅ Build Succeeded!"
echo "📂 Opening Demo project in Xcode..."
open Demo/Demo.xcodeproj
echo "🚀 Ready to run in iPhone Simulator or on a connected device."
