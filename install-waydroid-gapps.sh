#!/bin/bash
###############################################################################
# Waydroid Installer with GAPPS Support (ASCII-safe + Verbose mode)
#
# USAGE:
#   Normal:  bash install-waydroid-gapps.sh
#   Verbose: bash install-waydroid-gapps.sh verbose
#
# PURPOSE:
#   Install Waydroid with Google Play Store support (GAPPS)
#   No Google device certification steps are included in this script.
#   (Those will be handled by a separate script.)
###############################################################################

set -e

# Detect verbose mode
VERBOSE=false
if [[ "$1" =~ ^(verbose|-v|--verbose)$ ]]; then
    VERBOSE=true
fi

echo ""
echo "================================================================"
echo "   Waydroid Installer with GAPPS Support"
echo "================================================================"
echo ""
echo "This script will:"
echo "  - Verify binder devices"
echo "  - Install Waydroid"
echo "  - Initialize Waydroid with GAPPS"
echo "  - Start Waydroid session"
echo "  - Provide launch instructions"
echo ""
echo "Time required: 5 to 10 minutes"
echo ""

read -p "Continue? (y/n): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

###############################################################################
# STEP 1: Verify Binder Devices
###############################################################################
echo ""
echo "================================================================"
echo " STEP 1: Verifying Android binder devices"
echo "================================================================"
echo ""

echo "[*] Checking for /dev/binder /dev/hwbinder /dev/vndbinder ..."

if [ ! -e /dev/binder ] || [ ! -e /dev/hwbinder ] || [ ! -e /dev/vndbinder ]; then
    echo "ERROR: Binder devices missing."
    echo ""
    echo "Expected:"
    echo "  /dev/binder"
    echo "  /dev/hwbinder"
    echo "  /dev/vndbinder"
    echo ""
    echo "Found:"
    ls -la /dev/binder* 2>/dev/null || echo "  (none)"
    echo ""
    echo "Custom kernel was NOT loaded."
    echo ""
    echo "Fix:"
    echo " 1. Check ~/.wslconfig kernel paths"
    echo " 2. Run: wsl --shutdown"
    echo " 3. Restart WSL"
    echo " 4. Run: uname -r"
    exit 1
fi

echo "OK: Binder devices detected:"
ls -la /dev/binder /dev/hwbinder /dev/vndbinder

###############################################################################
# STEP 2: Install Dependencies
###############################################################################
echo ""
echo "================================================================"
echo " STEP 2: Installing dependencies"
echo "================================================================"
echo ""

echo "[*] Updating package list..."
sudo apt-get update -qq

echo "[*] Installing curl and ca-certificates..."
if [ "$VERBOSE" = true ]; then
    sudo apt-get install -y curl ca-certificates
else
    sudo apt-get install -y curl ca-certificates >/dev/null 2>&1
fi

echo "Dependencies installed."

###############################################################################
# STEP 3: Add Waydroid Repository
###############################################################################
echo ""
echo "================================================================"
echo " STEP 3: Adding Waydroid repository"
echo "================================================================"
echo ""

echo "[*] Adding Waydroid repository..."
if [ "$VERBOSE" = true ]; then
    curl -s https://repo.waydro.id | sudo bash
else
    curl -s https://repo.waydro.id | sudo bash >/dev/null 2>&1
fi

echo "Repository added."

###############################################################################
# STEP 4: Install Waydroid
###############################################################################
echo ""
echo "================================================================"
echo " STEP 4: Installing Waydroid"
echo "================================================================"
echo ""

echo "[*] Installing Waydroid..."
if [ "$VERBOSE" = true ]; then
    sudo apt-get install -y waydroid
else
    sudo apt-get install -y waydroid 2>&1 | grep -E "Setting up|Unpacking|Processing"
fi

if ! command -v waydroid >/dev/null 2>&1; then
    echo "ERROR: Waydroid did not install."
    exit 1
fi

WAYDROID_VERSION=$(waydroid --version 2>/dev/null || echo "unknown")
echo "Waydroid installed. Version: $WAYDROID_VERSION"

###############################################################################
# STEP 5: Initialize Waydroid with GAPPS
###############################################################################
echo ""
echo "================================================================"
echo " STEP 5: Initializing Waydroid with GAPPS"
echo "================================================================"
echo ""

NEED_INIT=true

if [ -f /var/lib/waydroid/waydroid.cfg ]; then
    echo "Waydroid already initialized."
    read -p "Reinitialize? (y/n): " reinit
    if [[ "$reinit" =~ ^[Yy]$ ]]; then
        echo "Cleaning old Waydroid installation..."
        sudo waydroid session stop 2>/dev/null || true
        sudo rm -rf /var/lib/waydroid
    else
        NEED_INIT=false
    fi
fi

if [ "$NEED_INIT" = true ]; then
    echo "[*] Initializing (GAPPS enabled)..."
    echo "    Download size: approx. 500MB - 1GB"

    if [ "$VERBOSE" = true ]; then
        sudo waydroid init -s GAPPS -f
    else
        sudo waydroid init -s GAPPS -f 2>&1 | grep -E "Downloading|Extracting|done|Done|Error|Failed"
    fi

    if [ ! -f /var/lib/waydroid/waydroid.cfg ]; then
        echo "ERROR: Waydroid initialization failed."
        exit 1
    fi

    echo "Waydroid initialized successfully."
fi

###############################################################################
# STEP 6: Start Waydroid Session
###############################################################################
echo ""
echo "================================================================"
echo " STEP 6: Starting Waydroid session"
echo "================================================================"
echo ""

sudo waydroid session stop 2>/dev/null || true
sleep 2

echo "[*] Starting session..."
sudo waydroid session start >/dev/null 2>&1 &

echo "Waiting for session..."
SESSION_OK=false
for i in $(seq 1 20); do
    if waydroid status | grep -q RUNNING; then
        SESSION_OK=true
        break
    fi
    sleep 1
done

if [ "$SESSION_OK" = true ]; then
    echo "Waydroid session is running."
else
    echo "Warning: Waydroid session did not report RUNNING."
fi

###############################################################################
# STEP 7: Wait for Android Boot
###############################################################################
echo ""
echo "================================================================"
echo " STEP 7: Waiting for Android to finish booting"
echo "================================================================"
echo ""

echo "[*] Checking Android boot status... (90s timeout)"

BOOT_OK=false
for i in $(seq 1 90); do
    if timeout 3 waydroid shell getprop sys.boot_completed 2>/dev/null | grep -q 1; then
        echo "Android booted in $i seconds."
        BOOT_OK=true
        break
    fi
    if [ $((i % 10)) -eq 0 ]; then
        echo "Still booting... ($i seconds)"
    fi
    sleep 1
done

if [ "$BOOT_OK" != true ]; then
    echo "Warning: Android did not confirm boot completion."
fi

###############################################################################
# FINAL SUMMARY (NO PLAY CERTIFICATION)
###############################################################################
echo ""
echo "================================================================"
echo "   WAYDROID INSTALLED SUCCESSFULLY"
echo "================================================================"
echo ""
echo "You can now launch the Android UI:"
echo "    waydroid show-full-ui"
echo ""
echo "Useful commands:"
echo "    waydroid session start"
echo "    waydroid session stop"
echo "    waydroid status"
echo "    waydroid app install myapp.apk"
echo ""
echo "Done."
echo ""