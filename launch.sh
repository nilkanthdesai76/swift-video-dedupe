#!/bin/bash
set -e

# VideoHashKit One-Click Launcher & Tester
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo "==================================================================="
echo "  🎥 VideoHashKit — Zero-Thermal Video Deduplication Engine"
echo "  Temporal dHash + pHash • Hardware AVFoundation Downsampling"
echo "==================================================================="

echo "🔨 Building Swift Video Dedupe package..."
swift build -c release

echo "🧪 Running unit tests..."
swift test

echo ""
echo "🚀 Running CLI Benchmark Mode..."
.build/release/VideoDedupeCLI

echo ""
echo "🖥️ Launching SwiftUI VideoDedupeApp GUI..."
.build/release/VideoDedupeApp &
APP_PID=$!
echo "✅ App launched with PID: $APP_PID"
