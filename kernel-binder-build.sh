#!/bin/bash
################################################################################
# WSL2 Kernel Build Script (ASCII-safe version)
#
# This script will:
#   1. Install all required build dependencies
#   2. Clone the official Microsoft WSL2 kernel source
#   3. Apply Android Binder configuration changes
#   4. Build the WSL2 kernel
#   5. Build and export modules into a VHDX file
#   6. Copy the kernel and modules into Windows folder:
#        /mnt/c/Users/<YourUser>/wsl-kernel/
#   7. Set up automatic BinderFS mount and /dev/binder* creation on boot
#   8. Print the KERNEL_VERSION to give to the PowerShell script
################################################################################

set -e

# Detect verbose build
VERBOSE=false
if [[ "$1" =~ ^(verbose|-v|--verbose)$ ]]; then
    VERBOSE=true
fi

echo ""
echo "================================================================"
echo "      WSL2 Kernel Builder with Android Binder Support"
echo "================================================================"
echo ""
echo "This script will:"
echo "  - Install all build dependencies"
echo "  - Clone the WSL2 kernel source (if missing)"
echo "  - Enable Android Binder, BinderFS, and required flags"
echo "  - Compile the kernel"
echo "  - Compile the kernel modules"
echo "  - Create a modules VHDX image for WSL to mount"
echo "  - Copy the final kernel and modules into your Windows folder"
echo "  - Configure BinderFS to auto-mount and expose /dev/binder* on boot"
echo ""
echo "Your Windows kernel directory will be:"
echo "  /mnt/c/Users/<YourUser>/wsl-kernel/"
echo ""
read -p "Continue? (Y/N): " ans
[[ ! "$ans" =~ ^[Yy]$ ]] && exit 0

WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
WIN_DEST="/mnt/c/Users/${WIN_USER}/wsl-kernel"
WORKSPACE="$HOME/wsl-kernel-src"
KERNEL_DIR="$WORKSPACE/wsl-kernel"
BUILD_OUTPUT="$HOME/wsl-kernel-build"

mkdir -p "$WIN_DEST"
mkdir -p "$WORKSPACE"

###############################################################################
echo ""
echo "===== STEP 1: Installing dependencies ====="
###############################################################################

sudo apt-get update -qq
sudo apt-get install -y \
    git build-essential bc flex bison dwarves \
    libelf-dev libssl-dev libncurses-dev qemu-utils \
    android-sdk-libsparse-utils e2fsprogs util-linux \
    python3 wget curl unzip cpio

echo "Dependencies installed"

###############################################################################
echo ""
echo "===== STEP 2: Fetching WSL2 kernel source ====="
###############################################################################

cd "$WORKSPACE"

if [ ! -d "$KERNEL_DIR" ]; then
    git clone --depth 1 https://github.com/microsoft/WSL2-Linux-Kernel.git wsl-kernel
    echo "Kernel source cloned"
else
    echo "Kernel source already available (skipping clone)"
fi

###############################################################################
echo ""
echo "===== STEP 3: Configuring kernel with Android Binder + Waydroid Networking ====="
###############################################################################

cd "$KERNEL_DIR"

if [ ! -f ".config" ]; then
    cp Microsoft/config-wsl .config

    ###########################################################################
    # Networking support REQUIRED for Waydroid under WSL2
    ###########################################################################

    # Virtual networking interfaces
    scripts/config --enable CONFIG_TUN
    scripts/config --enable CONFIG_VETH
    scripts/config --enable CONFIG_MACVLAN
    scripts/config --enable CONFIG_IPVLAN

    # Legacy iptables + NAT support (Waydroid *requires* legacy stack)
    scripts/config --enable CONFIG_IP_NF_IPTABLES
    scripts/config --enable CONFIG_IP_NF_FILTER
    scripts/config --enable CONFIG_IP_NF_NAT
    scripts/config --enable CONFIG_IP_NF_TARGET_MASQUERADE

    # MANGLE table support (missing in your logs → required!)
    scripts/config --enable CONFIG_IP_NF_MANGLE
    scripts/config --enable CONFIG_IP6_NF_MANGLE

    # IPv6 NAT, filtering, iptables support
    scripts/config --enable CONFIG_IP6_NF_IPTABLES
    scripts/config --enable CONFIG_IP6_NF_FILTER
    scripts/config --enable CONFIG_IP6_NF_NAT

    # xtables matches and targets used by waydroid-net.sh
    scripts/config --enable CONFIG_NETFILTER_XT_MATCH_CONNTRACK
    scripts/config --enable CONFIG_NETFILTER_XT_MATCH_STATE
    scripts/config --enable CONFIG_NETFILTER_XT_MATCH_MULTIPORT
    scripts/config --enable CONFIG_NETFILTER_XT_MATCH_PHYSDEV
    scripts/config --enable CONFIG_NETFILTER_XT_TARGET_MASQUERADE
    scripts/config --enable CONFIG_NETFILTER_XT_MARK

    # CHECKSUM target — FIXES your “missing kernel module” error
    scripts/config --enable CONFIG_NETFILTER_XT_TARGET_CHECKSUM

    # Bridge networking (recommended for Waydroid)
    scripts/config --enable CONFIG_BRIDGE
    scripts/config --enable CONFIG_BRIDGE_NETFILTER
    scripts/config --enable CONFIG_BRIDGE_NF_EBTABLES

    ###########################################################################
    # Sound support (ALSA, USB audio, HDA, VirtIO audio)
    ###########################################################################
    scripts/config --enable CONFIG_SND
    scripts/config --enable CONFIG_SND_PCM
    scripts/config --enable CONFIG_SND_TIMER
    scripts/config --enable CONFIG_SND_SEQ
    scripts/config --enable CONFIG_SND_SEQ_DEVICE
    scripts/config --enable CONFIG_SND_RAWMIDI

    # HDA audio drivers (fallback compatibility)
    scripts/config --enable CONFIG_SND_HDA_INTEL
    scripts/config --enable CONFIG_SND_HDA_GENERIC

    # USB audio (works well in WSL)
    scripts/config --enable CONFIG_USB_AUDIO
    scripts/config --enable CONFIG_SND_USB_AUDIO

    # VirtIO sound (future-proof for WSL improvements)
    scripts/config --enable CONFIG_SND_VIRTIO

    ###########################################################################
    # Android Binder / BinderFS support required for Waydroid
    ###########################################################################
    scripts/config --enable CONFIG_ANDROID
    scripts/config --enable CONFIG_ANDROID_BINDER_IPC
    scripts/config --enable CONFIG_ANDROID_BINDERFS
    scripts/config --enable CONFIG_ANDROID_BINDER_DEVICES
    scripts/config --set-str CONFIG_ANDROID_BINDER_DEVICES "binder,hwbinder,vndbinder"

    # Remove deprecated ashmem
    scripts/config --disable CONFIG_ASHMEM
    scripts/config --enable CONFIG_MEMFD_CREATE

    ###########################################################################
    # Disable BTF debugging (prevents WSL kernel build crashes)
    ###########################################################################
    scripts/config --disable CONFIG_DEBUG_INFO_BTF

    ###########################################################################
    # Apply updated configuration
    ###########################################################################
    make olddefconfig
    echo "Kernel configured"

else
    echo "Existing kernel configuration detected"
fi

###############################################################################
echo ""
echo "===== STEP 4: Building kernel ====="
###############################################################################

JOBS=$(nproc)

if [ "$VERBOSE" = true ]; then
    make -j"$JOBS"
else
    make -j"$JOBS" 2>&1 | grep -E "^(CC|LD|AR|GEN|INSTALL|UPD|CHK)"
fi

BZIMAGE=arch/x86/boot/bzImage
if [ ! -f "$BZIMAGE" ]; then
    echo "Kernel build failed"
    exit 1
fi

echo "Kernel built successfully"
ls -lh "$BZIMAGE"

###############################################################################
echo ""
echo "===== STEP 5: Building kernel modules ====="
###############################################################################

mkdir -p "$BUILD_OUTPUT"

if [ "$VERBOSE" = true ]; then
    echo "Building modules..."
    make -j"$JOBS" modules

    echo "Installing modules..."
    make INSTALL_MOD_PATH="$BUILD_OUTPUT" modules_install

else
    echo "Building modules..."
    make -j"$JOBS" modules 2>&1 | grep -E "MODPOST|CC|LD|Building|^  *INSTALL"

    echo "Installing modules..."
    make INSTALL_MOD_PATH="$BUILD_OUTPUT" modules_install 2>&1 | grep -E "INSTALL|DEPMOD"
fi

echo "Kernel modules built successfully"

###############################################################################
echo ""
echo "===== STEP 6: Determining kernel version ====="
###############################################################################

KERNEL_VERSION=$(make -s kernelrelease)
echo "Kernel Version: $KERNEL_VERSION"

###############################################################################
echo ""
echo "===== STEP 7: Exporting kernel to Windows ====="
###############################################################################

cp "$BZIMAGE" "$WIN_DEST/bzImage-$KERNEL_VERSION"
echo "Kernel exported -> $WIN_DEST/bzImage-$KERNEL_VERSION"

###############################################################################
echo ""
echo "===== STEP 8: Creating modules VHDX ====="
###############################################################################

MODULES_DIR="$BUILD_OUTPUT/lib/modules/$KERNEL_VERSION"
MODULES_IMG="$WIN_DEST/modules-$KERNEL_VERSION.img"
VHDX_PATH="$WIN_DEST/modules-$KERNEL_VERSION.vhdx"

SIZE_BYTES=$(du -bs "$MODULES_DIR" | awk '{print $1}')
SIZE_MB=$(( (SIZE_BYTES / 1024 / 1024) + 256 ))

dd if=/dev/zero of="$MODULES_IMG" bs=1M count=$SIZE_MB status=none
LOOP=$(sudo losetup --find --show "$MODULES_IMG")
sudo mkfs.ext4 -q "$LOOP"

TEMP_MNT="$HOME/tmp_mnt_$$"
mkdir -p "$TEMP_MNT"
sudo mount "$LOOP" "$TEMP_MNT"
sudo cp -r "$MODULES_DIR"/* "$TEMP_MNT"
sudo umount "$TEMP_MNT"
sudo losetup -d "$LOOP"
rmdir "$TEMP_MNT"

qemu-img convert -O vhdx "$MODULES_IMG" "$VHDX_PATH"
rm "$MODULES_IMG"

echo "Modules VHDX created -> $VHDX_PATH"

###############################################################################
echo ""
echo "===== STEP 9: Setting up BinderFS auto-mount at startup ====="
###############################################################################

if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    echo "Systemd detected - installing binderfs.service"

    sudo bash -c 'cat > /etc/systemd/system/binderfs.service' << 'EOF'
[Unit]
Description=Mount BinderFS and create Android binder devices (WSL)
DefaultDependencies=no
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/mkdir -p /dev/binderfs
ExecStart=/usr/bin/mount -t binder binder /dev/binderfs
ExecStart=/usr/bin/ln -sf /dev/binderfs/binder /dev/binder
ExecStart=/usr/bin/ln -sf /dev/binderfs/hwbinder /dev/hwbinder
ExecStart=/usr/bin/ln -sf /dev/binderfs/vndbinder /dev/vndbinder
ExecStart=/usr/bin/ln -sf /dev/binderfs/binder-control /dev/binder-control
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl enable binderfs.service
    echo "BinderFS systemd service installed and enabled"

else
    echo "Systemd not detected - installing profile.d auto-setup"

    sudo bash -c 'cat > /etc/profile.d/binderfs.sh' << 'EOF'
#!/bin/sh
if [ ! -d /dev/binderfs ]; then
  mkdir -p /dev/binderfs
fi
if ! mountpoint -q /dev/binderfs 2>/dev/null; then
  mount -t binder binder /dev/binderfs 2>/dev/null || exit 0
fi
[ -e /dev/binder ] || ln -sf /dev/binderfs/binder /dev/binder
[ -e /dev/hwbinder ] || ln -sf /dev/binderfs/hwbinder /dev/hwbinder
[ -e /dev/vndbinder ] || ln -sf /dev/binderfs/vndbinder /dev/vndbinder
[ -e /dev/binder-control ] || ln -sf /dev/binderfs/binder-control /dev/binder-control
EOF

    sudo chmod +x /etc/profile.d/binderfs.sh
    echo "BinderFS auto-setup script installed at /etc/profile.d/binderfs.sh"
fi

###############################################################################
echo ""
echo "================================================================"
echo "BUILD COMPLETE!"
echo "================================================================"
echo ""
echo "KERNEL_VERSION=$KERNEL_VERSION"
echo "Kernel:  $WIN_DEST/bzImage-$KERNEL_VERSION"
echo "Modules: $VHDX_PATH"
echo ""
echo "BinderFS will be set up automatically on boot."
echo ""
echo "Return to Windows PowerShell to continue installation."
echo ""