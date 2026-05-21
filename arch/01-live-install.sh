#!/bin/bash
set -e

# ==============================================================================
# 0. PRE-FLIGHT CHECKS
# ==============================================================================
echo "=== AUTOMATED ARCH LINUX INSTALLER ==="

if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Please run this script as root (use sudo or switch to root user)."
  exit 1
fi

if [ ! -d "/sys/firmware/efi/efivars" ]; then
  echo "ERROR: System is not booted in UEFI mode. This script requires UEFI."
  exit 1
fi

# ==============================================================================
# 1. DATA COLLECTION
# ==============================================================================
echo "Please provide the installation details:"

if [ -f "config.env" ]; then
  source "config.env"
elif [ -f "$(dirname "$0")/config.env" ]; then
  source "$(dirname "$0")/config.env"
else
  echo "ERROR: config.env not found!"
  exit 1
fi

while true; do
  read -s -p "Enter password for user $USERNAME: " USER_PW
  echo ""
  read -s -p "Confirm password: " USER_PW2
  echo ""
  [ "$USER_PW" = "$USER_PW2" ] && [ -n "$USER_PW" ] && break
  echo "ERROR: Passwords do not match or are empty. Try again."
done

echo ""
while true; do
  read -s -p "Enter ROOT password: " ROOT_PW
  echo ""
  read -s -p "Confirm ROOT password: " ROOT_PW2
  echo ""
  [ "$ROOT_PW" = "$ROOT_PW2" ] && [ -n "$ROOT_PW" ] && break
  echo "ERROR: Passwords do not match or are empty. Try again."
done

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

# ==============================================================================
# 2. PREPARATION
# ==============================================================================
echo "Synchronizing time..."
timedatectl set-ntp true

echo "Configuring mirrors..."
reflector --country "${MIRROR_COUNTRIES}" --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# ==============================================================================
# 3. DISK PARTITIONING
# ==============================================================================
echo "Partitioning $TARGET_DISK..."
sgdisk -Z "$TARGET_DISK"
sgdisk -n 1:0:+1G -t 1:ef00 "$TARGET_DISK"
sgdisk -n 2:0:0 -t 2:8300 "$TARGET_DISK"

if [[ "$TARGET_DISK" == *nvme* ]] || [[ "$TARGET_DISK" == *mmcblk* ]]; then
  PART_EFI="${TARGET_DISK}p1"
  PART_ROOT="${TARGET_DISK}p2"
else
  PART_EFI="${TARGET_DISK}1"
  PART_ROOT="${TARGET_DISK}2"
fi

echo "Formatting partitions..."
mkfs.fat -F32 "$PART_EFI"
mkfs.ext4 -F "$PART_ROOT"

echo "Mounting partitions..."
mount "$PART_ROOT" /mnt
mkdir -p /mnt/boot
mount "$PART_EFI" /mnt/boot

# ==============================================================================
# 4. PACKAGE INSTALLATION
# ==============================================================================
echo "Installing base system..."
pacstrap -K /mnt base linux linux-firmware intel-ucode \
  networkmanager niri ghostty efibootmgr git \
  mesa vulkan-intel intel-media-driver \
  pipewire wireplumber \
  xdg-desktop-portal

# ==============================================================================
# 5. FSTAB
# ==============================================================================
echo "Generating fstab..."
genfstab -U /mnt >>/mnt/etc/fstab

# ==============================================================================
# 6. CONFIGURATION TRANSFER
# ==============================================================================
echo "Copying config..."

cp "config.env" /mnt/config.env 2>/dev/null || cp "$(dirname "$0")/config.env" /mnt/config.env

cat <<ENV >/mnt/setup_env.sh
USER_PW="$USER_PW"
ROOT_PW="$ROOT_PW"
ENV

# ==============================================================================
# 7. COMPLETION
# ==============================================================================
echo "BASE INSTALLATION SUCCESSFULLY COMPLETED!"
echo ""
echo "Next steps:"
echo "1. arch-chroot /mnt"
echo "2. git clone ${DOTFILES_REPO:-https://github.com/ziiazi/dotfiles} dotfiles"
echo "3. cd dotfiles/setup/arch"
echo "4. bash 02-setup-system.sh"
