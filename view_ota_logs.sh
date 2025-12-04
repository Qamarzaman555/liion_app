#!/bin/bash
# Simple script to view OTA logs

echo "=========================================="
echo "OTA Update Log Monitor"
echo "=========================================="
echo ""
echo "This will show logs related to OTA updates"
echo "Press Ctrl+C to stop"
echo ""
echo "Clearing log buffer..."
adb logcat -c

echo ""
echo "Starting log monitor..."
echo ""

adb logcat | grep --line-buffered -E "BleScanService|OTA|Firmware|startOtaUpdate|performOtaUpdate|otaProgress|otaMessage|Error|Exception|Failed|filePath|characteristic"

