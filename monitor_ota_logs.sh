#!/bin/bash
# Script to monitor OTA-related logs

echo "Clearing logcat buffer..."
adb logcat -c

echo "Monitoring OTA logs... (Press Ctrl+C to stop)"
echo "================================================"

adb logcat | grep -E "BleScanService|OTA|Firmware|startOtaUpdate|performOtaUpdate|otaProgress|otaMessage" --line-buffered

