# Android on WSL2

Run a full Android environment on Windows Subsystem for Linux 2 using Waydroid. This toolkit handles everything from kernel compilation to Android setup, giving you a native Android experience inside WSL2.

## 📋 Overview

This project enables you to run Android apps and the full Android UI on WSL2 by:
- Building a custom WSL2 kernel with Android Binder support
- Installing Waydroid (Android 11 container) with Google Play Store
- Configuring networking for Android app connectivity
- Enabling audio support for media playback
- Providing tools for file management between Windows and Android

## 🎯 What You Get

### Full Android Experience
- **Android 11** running natively in WSL2
- **Google Play Store** pre-installed (GAPPS)
- **Full UI** with window manager support
- **App Installation** via Play Store or APK files
- **Network Access** for apps requiring internet
- **Audio Playback** for media and games

### Complete Automation
- **One-Click Kernel Build**: Automated PowerShell + Bash scripts
- **Waydroid Setup**: Single command installation with GAPPS
- **Web File Manager**: Modern UI for Android file access
- **Auto-Configuration**: BinderFS mounts automatically on boot

## 📦 Project Files

| File | Purpose | When to Use |
|------|---------|-------------|
| `Build-WSL_kernel.ps1` | Windows orchestrator | Run once to build kernel |
| `kernel-binder-build.sh` | Kernel compilation | Automatically called by PowerShell |
| `install-waydroid-gapps.sh` | Android setup | Run once after kernel is ready |
| `adb_file_manager.py` | File management UI | Optional, for easy file transfers |

### Verbose Mode

All main scripts support verbose output:

```bash
# Kernel build with full output
bash /tmp/kernel-binder-build.sh verbose

# Waydroid install with download progress
bash /tmp/install-waydroid-gapps.sh verbose
```

**When to use verbose mode:**
- Debugging build/install issues
- Monitoring download progress
- Understanding what's happening
- Reporting errors

**When to use normal mode:**
- Clean, minimal output
- Faster visual feedback
- Production deployments

## 🚀 Quick Start Guide

### Prerequisites
- Windows 10/11 with WSL2 enabled
- Ubuntu distribution installed in WSL
- At least 10GB free disk space
- 30-40 minutes for initial setup

### Step 1: Build Android-Ready Kernel

**On Windows** (Right-click → Run as Administrator):
```powershell
.\Build-WSL_kernel.ps1
```

**In Ubuntu/WSL** (when prompted by PowerShell):
```bash
# Standard build (recommended)
bash /tmp/kernel-binder-build.sh

# Verbose mode (show all compiler output)
bash /tmp/kernel-binder-build.sh verbose
```

⏱️ **Build time**: 20-30 minutes

The script will:
- Install build dependencies
- Clone WSL2 kernel source from Microsoft
- Configure Android Binder + networking + audio
- Compile kernel and modules
- Create VHDX module package
- Copy everything to Windows

### Step 2: Restart WSL with New Kernel

The PowerShell script will automatically:
1. Update your `.wslconfig` 
2. Shutdown WSL
3. Prompt you to restart WSL

```bash
# Verify the new kernel is loaded
uname -r
# Should show: 6.6.114.1-microsoft-standard-WSL2+ (or similar)

# Check Android Binder support
ls -la /dev/binder*
# Should show: binder, hwbinder, vndbinder devices
```

### Step 3: Install Android (Waydroid)

```bash
# Standard installation
bash /tmp/install-waydroid-gapps.sh

# Verbose mode (see all download/installation details)
bash /tmp/install-waydroid-gapps.sh verbose
```

⏱️ **Installation time**: 5-10 minutes (downloads ~500MB-1GB)

This installs:
- Waydroid container system
- Android 11 system image
- Google Play Store (GAPPS)
- All necessary Android services

### Step 4: Launch Android!

```bash
# Start Android in full-screen mode
waydroid show-full-ui
```

🎉 **You now have Android running on Windows via WSL2!**

## 🎮 Using Android on WSL2

### First Launch Setup

When you first launch Android:

1. **Initial Boot**: Takes 30-60 seconds
2. **Setup Wizard**: Follow Android's setup screens
3. **Google Account**: Sign in to access Play Store
4. **Play Store**: Browse and install apps normally

### Essential Commands

```bash
# Launch Android UI
waydroid show-full-ui

# Start Android in background
waydroid session start

# Check Android status
waydroid status

# Stop Android
waydroid session stop

# Install APK file
waydroid app install /path/to/app.apk

# Launch specific app
waydroid app launch com.android.settings

# List installed apps
waydroid app list

# Open Android shell
waydroid shell
```

### Installing Apps

**Method 1: Google Play Store** (Recommended)
1. Launch Android UI
2. Open Play Store app
3. Search and install apps normally

**Method 2: APK Files**
```bash
# From Linux/WSL
waydroid app install myapp.apk

# Using the web file manager (see below)
# 1. Open http://localhost:8765
# 2. Select APK in left pane
# 3. Click "INSTALL" button
```

### Performance Tips

```bash
# For better performance, use system RAM for Waydroid
sudo mkdir -p /var/lib/waydroid
sudo mount -t tmpfs -o size=2G tmpfs /var/lib/waydroid

# Check Android system properties
waydroid shell getprop

# Monitor Android logs
waydroid logcat
```

## 🌐 Managing Android Files

### Web-Based File Manager

The included ADB file manager provides an easy way to transfer files between Windows/Linux and Android.

**Start the server:**
```bash
python3 adb_file_manager.py
```

**Open in browser:** `http://localhost:8765`

### Features
- **Dual-pane UI**: Windows/Linux (left) ↔ Android (right)
- **Drag & drop**: Multi-file selection and transfer
- **APK installer**: Direct install from host
- **Windows drives**: Browse C:, D:, etc. on Windows
- **Virtual scrolling**: Handle thousands of files smoothly

### Usage Examples

**Transfer photos from Android to Windows:**
1. Left pane: Navigate to `C:\Users\YourName\Pictures`
2. Right pane: Navigate to `/sdcard/DCIM/Camera`
3. Select photos in right pane
4. Click **PULL TO HOST**

**Install an APK:**
1. Left pane: Navigate to your APK location
2. Select the APK file
3. Click **INSTALL**

**Push files to Android:**
1. Left pane: Select files/folders
2. Right pane: Navigate to destination (e.g., `/sdcard/Download`)
3. Click **PUSH TO DEVICE**

### Command-Line Alternative

```bash
# Push file to Android
adb push myfile.txt /sdcard/Download/

# Pull file from Android
adb pull /sdcard/Download/myfile.txt ~/

# Install APK
adb install myapp.apk

# Browse Android filesystem
adb shell ls -la /sdcard/
```

## 🔧 Troubleshooting

### Android Won't Start

**Problem**: `waydroid show-full-ui` fails or hangs

**Solutions**:
```bash
# Check if binder devices exist
ls -la /dev/binder*
# Should show: binder, hwbinder, vndbinder

# Verify kernel version
uname -r
# Should contain "WSL2" or your custom version

# Check Waydroid status
waydroid status

# Restart Waydroid session
waydroid session stop
sudo waydroid session start
waydroid show-full-ui

# Check logs
waydroid log
```

### Binder Devices Missing

**Problem**: `/dev/binder*` symlinks not found after kernel update

**Solution**:
```bash
# Check if binderfs is mounted
mount | grep binder

# Manual mount (temporary fix)
sudo mkdir -p /dev/binderfs
sudo mount -t binder binder /dev/binderfs
sudo ln -sf /dev/binderfs/binder /dev/binder
sudo ln -sf /dev/binderfs/hwbinder /dev/hwbinder
sudo ln -sf /dev/binderfs/vndbinder /dev/vndbinder

# Enable automatic mounting
sudo systemctl enable binderfs.service
sudo systemctl start binderfs.service
```

### Android Has No Internet

**Problem**: Apps can't connect to internet

**Solution**:
```bash
# Check network configuration
waydroid shell ip addr

# Restart networking
sudo waydroid-net.sh stop
sudo waydroid-net.sh start

# Verify iptables modules
lsmod | grep -E 'ip_tables|xt_'

# Manual module loading if needed
sudo modprobe xt_CHECKSUM
sudo modprobe iptable_mangle
sudo modprobe iptable_nat
```

### Kernel Build Fails

**Problem**: Compilation errors during kernel build

**Solutions**:
```bash
# Clean and retry
cd ~/wsl-kernel-src/wsl-kernel
make clean
bash /tmp/kernel-binder-build.sh verbose

# Update build tools
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install -y build-essential bc flex bison

# Check disk space
df -h
# Need at least 10GB free
```

### Play Store Not Working

**Problem**: Google Play Store won't open or sign in

**Solution**:
```bash
# Restart Android services
waydroid session stop
sleep 3
sudo waydroid session start
waydroid show-full-ui

# Re-initialize Waydroid (nuclear option)
sudo waydroid session stop
sudo rm -rf /var/lib/waydroid
bash /tmp/install-waydroid-gapps.sh
```

### WSL Won't Start After Kernel Update

**Problem**: WSL fails to boot with custom kernel

**Solution**:
```powershell
# On Windows PowerShell (as Admin)

# Check .wslconfig
cat $env:USERPROFILE\.wslconfig

# Verify kernel file exists
Test-Path "C:\Users\$env:USERNAME\wsl-kernel\bzImage-*"

# Temporarily revert to default kernel
# Comment out kernel line in .wslconfig
# (Edit: C:\Users\YourName\.wslconfig)
# Then:
wsl --shutdown
wsl -d Ubuntu

# Check WSL logs
wsl --debug-shell
```

### Audio Not Working

**Problem**: No sound in Android apps

**Check audio modules**:
```bash
# Verify audio support in kernel
zcat /proc/config.gz | grep -E 'CONFIG_SND'

# Check loaded modules
lsmod | grep snd

# Try loading USB audio
sudo modprobe snd-usb-audio
```

**Note**: Audio in WSL2 is experimental. For best results, use WSLg (Windows 11) or a third-party X server.

### Development & Testing

```bash
# Install your APK for testing
waydroid app install ~/myapp.apk

# View logs in real-time
waydroid logcat

# Access Android shell for debugging
waydroid shell

# Use ADB for advanced debugging
adb devices
adb logcat
adb shell dumpsys
```

**Note**: DRM-protected content may have limitations.

## 🛠️ Technical Details (For Advanced Users)

### What Makes This Work

**Android Binder IPC**: Android's core inter-process communication system. Required for all Android apps to function.

**BinderFS**: Virtual filesystem that creates binder device nodes automatically.

**Waydroid**: Lightweight Android container that uses Linux namespaces and binder to run Android natively (not emulation).

### Kernel Modules Enabled

The custom kernel includes these critical Android components:

```
CONFIG_ANDROID=y
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_BINDERFS=y
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"
```

**Networking for Android apps:**
```
CONFIG_IP_NF_IPTABLES=y
CONFIG_IP_NF_MANGLE=y          # Required by Waydroid
CONFIG_IP_NF_NAT=y
CONFIG_NETFILTER_XT_TARGET_CHECKSUM=y  # Fixes network errors
CONFIG_BRIDGE=y
CONFIG_VETH=y
CONFIG_TUN=y
```

**Audio support:**
```
CONFIG_SND=y
CONFIG_SND_USB_AUDIO=y
CONFIG_SND_HDA_INTEL=y
CONFIG_SND_VIRTIO=y
```

### Architecture

```
┌─────────────────────────────────────┐
│         Windows 10/11               │
│  ┌──────────────────────────────┐   │
│  │          WSL2                │   │
│  │  ┌────────────────────────┐  │   │
│  │  │  Custom Linux Kernel   │  │   │
│  │  │  (Android Binder)      │  │   │
│  │  └────────────────────────┘  │   │
│  │  ┌────────────────────────┐  │   │
│  │  │      Waydroid          │  │   │
│  │  │  (Android Container)   │  │   │
│  │  │  ┌──────────────────┐  │  │   │
│  │  │  │  Android 11      │  │  │   │
│  │  │  │  + GAPPS         │  │  │   │
│  │  │  └──────────────────┘  │  │   │
│  │  └────────────────────────┘  │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
```

### File Locations

**Windows:**
```
C:\Users\<YourName>\.wslconfig                    # WSL configuration
C:\Users\<YourName>\wsl-kernel\
  ├── bzImage-6.6.114.1-microsoft-standard-WSL2+  # Kernel image
  └── modules-6.6.114.1-microsoft-standard-WSL2+.vhdx  # Modules
```

**Linux/WSL:**
```
/var/lib/waydroid/                    # Android system files
~/.local/share/waydroid/              # Android user data
/dev/binderfs/                        # Binder devices
/tmp/                                 # Build scripts (temporary)
```

### Performance Specs

| Component | Resource Usage |
|-----------|---------------|
| Custom Kernel | +50-100MB RAM |
| Waydroid (Idle) | ~200-300MB RAM |
| Waydroid (Active) | ~500MB-1GB RAM |
| Android System | ~500MB disk |
| App Storage | Variable |

### Build Process Details

When you run the build scripts:

1. **PowerShell Script** (`Build-WSL_kernel.ps1`):
   - Copies bash script into WSL
   - Monitors build progress
   - Configures `.wslconfig`
   - Manages WSL shutdown/restart

2. **Bash Script** (`kernel-binder-build.sh`):
   - Installs: gcc, make, flex, bison, libelf, openssl
   - Clones: Microsoft WSL2 kernel source (~1.5GB)
   - Configures: Binder + networking + audio modules
   - Compiles: Kernel in ~20-30 minutes
   - Packages: Modules into VHDX format
   - Exports: Files to Windows directory

3. **Module VHDX Creation**:
   - Creates ext4 filesystem image
   - Copies all kernel modules
   - Converts to VHDX format (WSL2 native)
   - Windows mounts this automatically on boot

## ❓ Frequently Asked Questions

### Can I use this for app development?
Yes! This is perfect for testing Android apps. You get full ADB access and can use Android Studio's debugger.

### Does this work on Windows 10?
Yes, as long as you have WSL2 enabled. Windows 11 recommended for better graphics support.

### Will this break my existing WSL setup?
No. The custom kernel is isolated. You can revert by editing `.wslconfig` and running `wsl --shutdown`.

### Can I run multiple Android instances?
Currently, Waydroid runs one instance per WSL distribution. You could use multiple WSL distros for multiple instances.

### Does this require Hyper-V?
WSL2 uses Hyper-V automatically on Windows 10. On Windows 11, it uses the Virtual Machine Platform.

### Can I play games?
Yes, but performance depends on the game. 2D games and light 3D games work well. Heavy games may lag.

### Is this safe?
Yes. The kernel is built from official Microsoft sources with only configuration changes (no patches). Waydroid is open-source.

### How do I update Android apps?
Through the Play Store, just like a regular Android device.

### Can I use a different Android version?
Waydroid currently supports Android 11. Check their documentation for future versions.

### How do I uninstall everything?

```bash
# Stop and remove Waydroid
sudo waydroid session stop
sudo apt-get remove --purge waydroid
sudo rm -rf /var/lib/waydroid ~/.local/share/waydroid

# Revert kernel (Windows PowerShell)
Remove-Item $env:USERPROFILE\.wslconfig
wsl --shutdown

# Optional: Remove build files
rm -rf ~/wsl-kernel-src ~/wsl-kernel-build
```

Then delete `C:\Users\YourName\wsl-kernel\` from Windows.

## 🎓 Learning Resources

### Understanding the Stack
- **WSL2 Documentation**: [Microsoft Learn](https://learn.microsoft.com/en-us/windows/wsl/)
- **Waydroid Official**: [waydro.id](https://waydro.id)
- **Android Binder**: [Android Source](https://source.android.com/docs/core/architecture/hidl/binder-ipc)
- **Linux Kernel**: [kernel.org](https://www.kernel.org/)

### Community & Support
- **Waydroid Issues**: Report at [Waydroid GitHub](https://github.com/waydroid/waydroid)
- **WSL Issues**: Report at [WSL GitHub](https://github.com/microsoft/WSL)
- **This Project**: Use GitHub Issues for toolkit-specific problems

## 🤝 Contributing

Contributions welcome! Areas of interest:

**Kernel Improvements:**
- Additional Android features
- Performance optimizations
- Better audio support
- GPU passthrough

**Waydroid Enhancements:**
- Automated Play certification
- Camera support
- Better network configuration
- Multi-window mode

**Tools:**
- Enhanced file manager features
- Backup/restore scripts
- Performance monitoring
- Auto-update mechanisms

**Documentation:**
- Video tutorials
- Troubleshooting guides
- App compatibility lists
- Benchmark results

### How to Contribute
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📊 Compatibility

### Tested Configurations

| Component | Version | Status |
|-----------|---------|--------|
| Windows 10 21H2 | Build 19044 | ✅ Working |
| Windows 11 22H2 | Build 22621 | ✅ Working |
| Ubuntu 20.04 | WSL2 | ✅ Working |
| Ubuntu 22.04 | WSL2 | ✅ Working |
| Waydroid | 1.4.2+ | ✅ Working |
| Android | 11 | ✅ Full support |

## 📄 License

MIT License - See `LICENSE` file for details

## 🙏 Acknowledgments

- Microsoft for WSL2 and kernel source
- Waydroid team for Android containerization
- LineageOS for design inspiration
- Community testers and contributors

## 🔐 Security & Privacy

### What This Project Does
- Builds kernel from official Microsoft sources
- Applies only configuration changes (no code patches)
- Runs Android in an isolated container
- Requires explicit ADB authorization for file access

### What You Should Know
- **Google Account**: Required for Play Store access
- **App Permissions**: Android apps run with normal permissions
- **Network Access**: Apps can access internet through WSL2's network
- **Data Storage**: Android data stored in `/var/lib/waydroid/`
- **File Isolation**: Android can't access Windows files without explicit transfer

### Privacy Notes
- This setup does NOT bypass Google's SafetyNet
- Banking apps may detect "rooted" environment
- Some DRM content may be restricted
- Android device ID is unique per Waydroid installation

---

**Built with ❤️ for WSL2 + Android enthusiasts**
