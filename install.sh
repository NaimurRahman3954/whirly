#!/bin/zsh
# Build Whirly in Release and install it on an iPhone over USB or Wi-Fi.
# Usage: ./install.sh <device-udid>   (or put the UDID in a file named .device)
# Find the UDID with: xcrun devicectl list devices
set -e
cd "$(dirname "$0")"
DEVICE=${1:-$(cat .device 2>/dev/null)}
if [[ -z "$DEVICE" ]]; then echo "Pass a device UDID or save it in .device"; exit 1; fi
xcodebuild -project Whirly.xcodeproj -target Whirly -configuration Release -sdk iphoneos \
  -allowProvisioningUpdates SYMROOT="$PWD/build" build -quiet
xcrun devicectl device install app --device "$DEVICE" build/Release-iphoneos/Whirly.app
echo "Installed. If iOS asks, trust the developer in Settings › General › VPN & Device Management."
