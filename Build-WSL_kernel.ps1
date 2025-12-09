################################################################################
# WSL2 Kernel Builder - Windows Orchestrator
# 
# PURPOSE:
#   Coordinates the WSL2 kernel build process and configures Windows to use
#   the custom kernel with Android binder support.
#
# WHAT THIS SCRIPT DOES:
#   1. Verifies that kernel-binder-build.sh exists
#   2. Copies kernel-binder-build.sh into WSL (/tmp)
#   3. Instructs you to run the Linux build script in WSL
#   4. Asks you for the built KERNEL_VERSION
#   5. Auto-detects kernel & modules in C:\Users\<You>\wsl-kernel (with fallback)
#   6. Writes .wslconfig to point WSL2 to the new kernel + modules
#   7. Shuts down WSL so the new kernel will be used next start
#   8. After you restart WSL, copies helper scripts (/tmp) into WSL
#
# USAGE:
#   1. Right-click this file → Run with PowerShell (as Administrator)
#   2. Follow on-screen instructions
#
# VERBOSE BUILD:
#   To build the kernel with full verbose output from the Linux side:
#     - Run this script
#     - When it tells you to run the Linux script, use:
#         bash /tmp/kernel-binder-build.sh verbose
################################################################################

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [switch]$BuildVerbose   # Only affects messaging, not PowerShell internals
)

$ErrorActionPreference = "Stop"

# Paths & constants
$SCRIPT_DIR    = Split-Path -Parent $MyInvocation.MyCommand.Path
$WSL_DISTRO    = "Ubuntu"
$KERNEL_FOLDER = "$env:USERPROFILE\wsl-kernel"
$VERBOSE_BUILD = $BuildVerbose.IsPresent

################################################################################
# Helper Functions
################################################################################

function Write-Header {
    param([string]$Message)
    Write-Host "`n================================================================" -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "================================================================`n" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Wait-UserConfirmation {
    param([string]$Message)
    Write-Host "`n$Message" -ForegroundColor Yellow
    Write-Host "Press ENTER to continue..." -ForegroundColor Gray
    Read-Host | Out-Null
}

################################################################################
# MAIN SCRIPT
################################################################################

Clear-Host
Write-Header "WSL2 Kernel Builder with Binder Support (Windows Orchestrator)"

Write-Host "This script will:" -ForegroundColor White
Write-Host "  1. Copy the Linux kernel build script into WSL" -ForegroundColor White
Write-Host "  2. Instruct you to run it from an Ubuntu terminal" -ForegroundColor White
Write-Host "  3. Verify that the built kernel and modules exist in your Windows folder" -ForegroundColor White
Write-Host "  4. Configure .wslconfig to use the new kernel" -ForegroundColor White
Write-Host "  5. Shutdown WSL so the new kernel is used next time" -ForegroundColor White
Write-Host "  6. After reboot, copy helper scripts into WSL (/tmp)" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "Estimated time: 20–35 minutes (most of it compiling inside WSL)" -ForegroundColor Yellow
if ($VERBOSE_BUILD) {
    Write-Host "Verbose build: you should run the Linux script with the 'verbose' flag." -ForegroundColor Magenta
}
Write-Host "" -ForegroundColor White

$confirm = Read-Host "Continue? (Y/N)"
if ($confirm -notin @("Y", "y")) {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit
}

################################################################################
# STEP 1: Verify Files & WSL
################################################################################

Write-Header "STEP 1: Verifying required files and WSL"

$bashScript = Join-Path $SCRIPT_DIR "kernel-binder-build.sh"
if (-not (Test-Path $bashScript)) {
    Write-Error-Custom "kernel-binder-build.sh not found in: $SCRIPT_DIR"
    Write-Host "Please ensure this PowerShell script and kernel-binder-build.sh are in the same folder." -ForegroundColor Yellow
    exit 1
}
Write-Success "Found kernel-binder-build.sh"

# Verify WSL and Ubuntu distro exist
try {
    $null = wsl --version 2>&1
    Write-Success "WSL2 is installed"

    $distroList = wsl -l -q 2>&1
    $foundUbuntu = $false
    foreach ($line in $distroList) {
        $cleanLine = $line -replace '\s+', ''
        if ($cleanLine -eq 'Ubuntu') {
            $foundUbuntu = $true
            break
        }
    }

    if (-not $foundUbuntu) {
        Write-Error-Custom "Ubuntu distribution not found in WSL"
        Write-Host "Install 'Ubuntu' from Microsoft Store and set it up before running this script." -ForegroundColor Yellow
        exit 1
    }
    Write-Success "Ubuntu distribution found in WSL"
} catch {
    Write-Error-Custom "WSL2 not installed or not accessible"
    exit 1
}

################################################################################
# STEP 2: Copy Build Script to WSL
################################################################################

Write-Header "STEP 2: Copying Linux build script into WSL"

$wslScriptPath = "/tmp/kernel-binder-build.sh"
Write-Info "Transferring kernel-binder-build.sh to WSL: $wslScriptPath"

# Read script from Windows and normalize ALL line endings
$content = Get-Content $bashScript -Raw

# Remove Windows CRLF and stray CR bytes (FULL FIX)
$content = $content -replace "`r`n", "`n"   # Convert CRLF -> LF
$content = $content -replace "`r", ""       # Remove any standalone CR

# Transfer clean script into WSL
$content | wsl -d $WSL_DISTRO -- bash -c "cat > $wslScriptPath"
wsl -d $WSL_DISTRO -- chmod +x $wslScriptPath

Write-Success "Linux build script copied to: $wslScriptPath"

################################################################################
# STEP 3: User Runs Build in Linux
################################################################################

Write-Header "STEP 3: Build the kernel inside WSL (Ubuntu)"

Write-Host "Now you need to run the build script inside Ubuntu/WSL." -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "1. Open a NEW Ubuntu/WSL terminal window." -ForegroundColor Yellow
Write-Host "" -ForegroundColor White
Write-Host "2. Run this command:" -ForegroundColor Yellow
Write-Host "" -ForegroundColor White

if ($VERBOSE_BUILD) {
    Write-Host "   bash $wslScriptPath verbose" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor White
    Write-Host "   (Verbose mode: all compiler output will be shown.)" -ForegroundColor Gray
} else {
    Write-Host "   bash $wslScriptPath" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor White
    Write-Host "   (For full output, you can run: bash $wslScriptPath verbose)" -ForegroundColor Gray
}

Write-Host "" -ForegroundColor White
Write-Host "3. Wait for the build to complete (this is the long part)." -ForegroundColor Yellow
Write-Host "4. At the end, it will print: KERNEL_VERSION=<version>" -ForegroundColor Yellow
Write-Host "5. When it finishes and tells you to return to PowerShell, come back here." -ForegroundColor Yellow
Write-Host "" -ForegroundColor White

Wait-UserConfirmation "After the Linux build script finishes successfully, press ENTER here to continue..."

################################################################################
# STEP 4: Get Kernel Version from User
################################################################################

Write-Header "STEP 4: Kernel version"

Write-Host "The Linux script should have printed a line like:" -ForegroundColor Yellow
Write-Host "  KERNEL_VERSION=6.6.114.1-microsoft-standard-WSL2+" -ForegroundColor Gray
Write-Host "" -ForegroundColor White

do {
    $kernelVersion = Read-Host "Enter the exact KERNEL_VERSION shown in the Linux terminal"
    if ([string]::IsNullOrWhiteSpace($kernelVersion)) {
        Write-Host "Kernel version cannot be empty. Please try again." -ForegroundColor Red
        continue
    }
    break
} while ($true)

Write-Success "Using kernel version: $kernelVersion"

################################################################################
# STEP 5: Locate Kernel Files in Windows (Auto-detect + Fallback)
################################################################################

Write-Header "STEP 5: Locating kernel files in Windows"

# Ensure kernel folder exists (Linux script should have created it, but be safe)
if (-not (Test-Path $KERNEL_FOLDER)) {
    Write-Info "Kernel folder does not exist yet. Creating: $KERNEL_FOLDER"
    New-Item -ItemType Directory -Path $KERNEL_FOLDER -Force | Out-Null
    Write-Success "Created kernel folder: $KERNEL_FOLDER"
} else {
    Write-Info "Kernel folder exists: $KERNEL_FOLDER"
}

$winKernelDest  = $null
$winModulesDest = $null

# Try to auto-detect kernel image: bzImage-<KERNEL_VERSION>
Write-Info "Attempting to auto-detect kernel image and modules VHDX in: $KERNEL_FOLDER"

$autoKernel  = Get-ChildItem -Path $KERNEL_FOLDER -Filter "bzImage-$kernelVersion" -File -ErrorAction SilentlyContinue
$autoModules = Get-ChildItem -Path $KERNEL_FOLDER -Filter "modules-$kernelVersion.vhdx" -File -ErrorAction SilentlyContinue

if ($autoKernel -and $autoKernel.Count -eq 1) {
    $winKernelDest = $autoKernel.FullName
    Write-Success "Auto-detected kernel image: $winKernelDest"
} else {
    if (-not $autoKernel) {
        Write-Info "No bzImage-$kernelVersion auto-detected. You will be asked to provide the path."
    } else {
        Write-Info "Multiple matching kernel images found. You will be asked to provide the exact path."
    }
}

if ($autoModules -and $autoModules.Count -eq 1) {
    $winModulesDest = $autoModules.FullName
    Write-Success "Auto-detected modules VHDX: $winModulesDest"
} else {
    if (-not $autoModules) {
        Write-Info "No modules-$kernelVersion.vhdx auto-detected. You will be asked to provide the path."
    } else {
        Write-Info "Multiple matching modules VHDX files found. You will be asked to provide the exact path."
    }
}

# Fallback: ask user for kernel image path
while (-not $winKernelDest -or -not (Test-Path $winKernelDest)) {
    Write-Host "" -ForegroundColor White
    $inputKernel = Read-Host "Enter the FULL path to the kernel image (bzImage-$kernelVersion)"
    if ([string]::IsNullOrWhiteSpace($inputKernel)) {
        Write-Host "Path cannot be empty. Please try again." -ForegroundColor Red
        continue
    }
    if (-not (Test-Path $inputKernel)) {
        Write-Host "File not found at: $inputKernel" -ForegroundColor Red
        continue
    }
    $winKernelDest = $inputKernel
    break
}

# Fallback: ask user for modules VHDX path
while (-not $winModulesDest -or -not (Test-Path $winModulesDest)) {
    Write-Host "" -ForegroundColor White
    $inputModules = Read-Host "Enter the FULL path to the modules VHDX (modules-$kernelVersion.vhdx)"
    if ([string]::IsNullOrWhiteSpace($inputModules)) {
        Write-Host "Path cannot be empty. Please try again." -ForegroundColor Red
        continue
    }
    if (-not (Test-Path $inputModules)) {
        Write-Host "File not found at: $inputModules" -ForegroundColor Red
        continue
    }
    $winModulesDest = $inputModules
    break
}

Write-Host "" -ForegroundColor White
Write-Success "Kernel files resolved:"
Write-Host "  Kernel image:  $winKernelDest" -ForegroundColor Gray
Write-Host "  Modules VHDX:  $winModulesDest" -ForegroundColor Gray

################################################################################
# STEP 6: Configure .wslconfig
################################################################################

Write-Header "STEP 6: Configuring .wslconfig"

$wslConfigPath = "$env:USERPROFILE\.wslconfig"

# Escape backslashes for clarity
$kernelPath  = $winKernelDest  -replace '\\', '\\'
$modulesPath = $winModulesDest -replace '\\', '\\'

$wslConfigContent = @"
[wsl2]
kernel=$kernelPath
kernelCommandLine=modules_vhd=$modulesPath
"@

if (Test-Path $wslConfigPath) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = "$wslConfigPath.backup.$timestamp"
    Write-Info "Backing up existing .wslconfig to: $backupPath"
    Copy-Item $wslConfigPath $backupPath
}

Write-Info "Writing new .wslconfig:"
Write-Host "  Kernel:  $kernelPath"  -ForegroundColor Gray
Write-Host "  Modules: $modulesPath" -ForegroundColor Gray

$wslConfigContent | Out-File -FilePath $wslConfigPath -Encoding UTF8
Write-Success ".wslconfig configured"

################################################################################
# STEP 6.5: Pause before shutdown (tmp will be wiped)
################################################################################

Write-Header "STEP 6.5: Final chance before WSL shutdown"

Write-Host "The kernel has been replaced and .wslconfig is updated." -ForegroundColor Yellow
Write-Host ""
Write-Host "Before WSL shuts down, this is your LAST chance to:" -ForegroundColor Cyan
Write-Host "  • Run any final commands inside your current Ubuntu session" -ForegroundColor White
Write-Host "  • Copy logs or any files from /tmp (which will be wiped on next start)" -ForegroundColor White
Write-Host "  • Double-check the build output if you wish" -ForegroundColor White
Write-Host ""
Write-Host "When WSL shuts down, the /tmp folder will be cleared." -ForegroundColor Red
Write-Host ""

Wait-UserConfirmation "Press ENTER ONLY when you are ready to shutdown WSL and apply the new kernel..."

################################################################################
# STEP 7: Final verification of files
################################################################################

Write-Header "STEP 7: Final verification of files"

Write-Host "Kernel image:" -ForegroundColor Cyan
Write-Host "  $winKernelDest" -ForegroundColor White
Write-Host "  Exists: " -NoNewline
if (Test-Path $winKernelDest) { Write-Host "YES" -ForegroundColor Green } else { Write-Host "NO" -ForegroundColor Red }

Write-Host "" -ForegroundColor White
Write-Host "Modules VHDX:" -ForegroundColor Cyan
Write-Host "  $winModulesDest" -ForegroundColor White
Write-Host "  Exists: " -NoNewline
if (Test-Path $winModulesDest) { Write-Host "YES" -ForegroundColor Green } else { Write-Host "NO" -ForegroundColor Red }

Write-Host "" -ForegroundColor White
Write-Host ".wslconfig:" -ForegroundColor Cyan
Write-Host "  $wslConfigPath" -ForegroundColor White
Write-Host "  Exists: " -NoNewline
if (Test-Path $wslConfigPath) {
    Write-Host "YES" -ForegroundColor Green
    Write-Host "" -ForegroundColor White
    Write-Host "  Contents:" -ForegroundColor Gray
    Get-Content $wslConfigPath | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
} else {
    Write-Host "NO" -ForegroundColor Red
}

################################################################################
# STEP 8: Shutdown WSL
################################################################################

Write-Header "STEP 8: Shutting down WSL"

Write-Info "Shutting down all WSL instances to apply the new kernel on next start..."
wsl --shutdown
Start-Sleep -Seconds 2
Write-Success "WSL shutdown complete"

################################################################################
# STEP 9: Copy helper scripts AFTER WSL restart
################################################################################

Write-Header "STEP 9: Preparing optional helper scripts AFTER restart"

Write-Host "WSL has been shut down." -ForegroundColor Yellow
Write-Host ""
Write-Host "Please START WSL (Ubuntu) again now, so it boots with the new kernel:" -ForegroundColor Cyan
Write-Host "   wsl -d Ubuntu" -ForegroundColor White
Write-Host ""
Write-Host "Once Ubuntu is fully launched and you are at a shell prompt," -ForegroundColor White
Write-Host "return here and press ENTER to copy helper scripts into /tmp." -ForegroundColor Yellow

Wait-UserConfirmation "Press ENTER once WSL has restarted and you have an Ubuntu shell ready..."

$waydroidScript        = Join-Path $SCRIPT_DIR "install-waydroid-gapps.sh"
$sharedFolderScript    = Join-Path $SCRIPT_DIR "adb_file_manager.py"
$wslWaydroidScript     = $null
$wslSharedFolderScript = $null

if (Test-Path $waydroidScript) {
    Write-Info "Copying install-waydroid-gapps.sh into WSL..."
    $waydroidContent = Get-Content $waydroidScript -Raw
    $waydroidContent = $waydroidContent -replace "`r`n", "`n"
    $wslWaydroidScript = "/tmp/install-waydroid-gapps.sh"
    $waydroidContent | wsl -d $WSL_DISTRO -- bash -c "cat > $wslWaydroidScript"
    wsl -d $WSL_DISTRO -- chmod +x $wslWaydroidScript
    Write-Success "Waydroid installer ready at: $wslWaydroidScript"
} else {
    Write-Info "install-waydroid-gapps.sh not found - skipping Waydroid helper"
}

if (Test-Path $sharedFolderScript) {
    Write-Info "Copying adb file manager into WSL..."
    $sharedContent = Get-Content $sharedFolderScript -Raw
    $sharedContent = $sharedContent -replace "`r`n", "`n"
    $wslSharedFolderScript = "adb_file_manager.py"
    $sharedContent | wsl -d $WSL_DISTRO -- bash -c "cat > $wslSharedFolderScript"
    wsl -d $WSL_DISTRO -- chmod +x $wslSharedFolderScript
    Write-Success "adb file manager ready at: $wslSharedFolderScript"
} else {
    Write-Info "adb_file_manager.py not found - skipping adb file manager"
}

################################################################################
# FINAL SUMMARY
################################################################################

Write-Host "" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Green
Write-Host "                    KERNEL SETUP COMPLETE" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host "" -ForegroundColor White
Write-Host "✓ Kernel version: $kernelVersion" -ForegroundColor Green
Write-Host "✓ Files directory: $KERNEL_FOLDER" -ForegroundColor Green
Write-Host "✓ .wslconfig configured at: $wslConfigPath" -ForegroundColor Green
Write-Host "✓ WSL shutdown and restarted with new kernel" -ForegroundColor Green
if ($wslWaydroidScript) {
    Write-Host "✓ Waydroid installer copied: $wslWaydroidScript" -ForegroundColor Green
}
if ($wslSharedFolderScript) {
    Write-Host "✓ adb file manager copied: $wslSharedFolderScript" -ForegroundColor Green
}
Write-Host "" -ForegroundColor White

Write-Host "NEXT STEPS INSIDE WSL (Ubuntu):" -ForegroundColor Cyan
Write-Host "" -ForegroundColor White

Write-Host "1. Verify you are running the new kernel:" -ForegroundColor Yellow
Write-Host "   uname -r" -ForegroundColor White
Write-Host "   (Expected: $kernelVersion)" -ForegroundColor Gray
Write-Host "" -ForegroundColor White

Write-Host "2. Verify binder support and devices:" -ForegroundColor Yellow
Write-Host "   zcat /proc/config.gz | grep -E 'CONFIG_ANDROID_BINDER|CONFIG_ANDROID_BINDERFS'" -ForegroundColor White
Write-Host "   mount | grep binder" -ForegroundColor White
Write-Host "   ls -la /dev/binder*" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "   You should see binderfs mounted on /dev/binderfs and symlinks like:" -ForegroundColor Gray
Write-Host "     /dev/binder -> /dev/binderfs/binder" -ForegroundColor Gray
Write-Host "     /dev/hwbinder -> /dev/binderfs/hwbinder" -ForegroundColor Gray
Write-Host "     /dev/vndbinder -> /dev/binderfs/vndbinder" -ForegroundColor Gray
Write-Host "" -ForegroundColor White

if ($wslWaydroidScript) {
    Write-Host "3. To install Waydroid with GAPPS (inside WSL):" -ForegroundColor Yellow
    Write-Host "   bash $wslWaydroidScript" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor White
}

if ($wslSharedFolderScript) {
    Write-Host "4. To setup a adb file server (inside WSL):" -ForegroundColor Yellow
    Write-Host "   python3 $SharedFolderScript" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor White
}

if (-not $wslWaydroidScript -and -not $wslSharedFolderScript) {
    Write-Host "3. (Optional) Install Waydroid and adb file server manually if you need them." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Press ENTER to exit..." -ForegroundColor Gray
[void][System.Console]::ReadLine()