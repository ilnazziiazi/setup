#!/bin/bash
set -e

# ==============================================================================
# INSTALL.SH - Master Installer
# ==============================================================================

echo "=== AUTOMATED ARCH LINUX INSTALLER ==="

if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Please run this script as root (use sudo or switch to root user)."
  exit 1
fi

if [ ! -d "/sys/firmware/efi/efivars" ]; then
  echo "WARNING: System is not booted in UEFI mode. This script is designed for UEFI."
  read -p "Press Enter to continue anyway, or Ctrl+C to abort..."
fi

# 1. READ CONFIG
if [ -f "config.env" ]; then
  source "config.env"
elif [ -f "$(dirname "$0")/config.env" ]; then
  source "$(dirname "$0")/config.env"
else
  echo "ERROR: config.env not found!"
  exit 1
fi

# 2. CHOOSE INSTALL MODE
echo ""
echo "Select installation mode:"
echo "1) Server (Base system + CLI tools)"
echo "2) Desktop (Server + Niri Wayland Environment)"
while true; do
  read -p "Enter choice [1-2]: " mode_choice
  case $mode_choice in
    1) INSTALL_MODE="server"; break;;
    2) INSTALL_MODE="desktop"; break;;
    *) echo "Invalid choice. Please enter 1 or 2.";;
  esac
done

# 3. GET PASSWORDS
echo ""
while true; do
  read -s -p "Enter password (will be used for both root and $USERNAME): " USER_PW
  echo ""
  read -s -p "Confirm password: " USER_PW2
  echo ""
  [ "$USER_PW" = "$USER_PW2" ] && [ -n "$USER_PW" ] && break
  echo "ERROR: Passwords do not match or are empty. Try again."
done
ROOT_PW="$USER_PW"

# 4. SELECT DISK
echo -e "\nAvailable disks:"
lsblk -d -p -n -l -o NAME,SIZE,MODEL | grep -v "loop" | grep -v "airootfs"
echo ""
while true; do
  read -p "Enter disk to format (e.g. /dev/sda or /dev/nvme0n1): " TARGET_DISK
  if [ -b "$TARGET_DISK" ]; then
    break
  else
    echo "ERROR: Disk $TARGET_DISK not found. Try again."
  fi
done

echo "WARNING: Disk $TARGET_DISK will be COMPLETELY WIPED in 5 seconds. Press Ctrl+C to cancel..."
sleep 5

# Export variables for child scripts
export INSTALL_MODE
export USER_PW
export ROOT_PW
export TARGET_DISK

# 5. RUN SERVER SETUP
echo ""
echo ">>> STARTING SERVER INSTALLATION <<<"
bash "$(dirname "$0")/01-server.sh"

# 6. RUN DESKTOP SETUP (CONDITIONAL)
if [ "$INSTALL_MODE" = "desktop" ]; then
    echo ""
    echo ">>> DESKTOP MODE SELECTED. STARTING GUI INSTALLATION IN CHROOT <<<"
    arch-chroot /mnt bash /setup_tmp/02-desktop.sh
fi

echo "Cleaning up temporary files..."
rm -rf /mnt/setup_tmp 2>/dev/null || true

echo ""
echo "=== ALL DONE ==="
echo "Installation successfully completed in $INSTALL_MODE mode!"
echo "You can now reboot your computer using the command: reboot"