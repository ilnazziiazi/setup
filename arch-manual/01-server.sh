#!/bin/bash
set -e

# ==============================================================================
# 01-SERVER.SH - Base System and CLI Tools
# ==============================================================================

# Inherit variables from config.env (loaded by install.sh or loaded locally)
if [ -z "$USERNAME" ]; then
    if [ -f "config.env" ]; then source "config.env"
    elif [ -f "$(dirname "$0")/config.env" ]; then source "$(dirname "$0")/config.env"
    fi
fi

echo "Synchronizing time..."
timedatectl set-ntp true

echo "Configuring mirrors..."
reflector --country "${MIRROR_COUNTRIES}" --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

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

echo "Installing base system (Server/CLI)..."
pacstrap -K /mnt base base-devel linux linux-firmware intel-ucode networkmanager efibootmgr git sudo zsh curl zram-generator docker tailscale stow neovim tmux zoxide noto-fonts wget

echo "Generating fstab..."
genfstab -U /mnt >>/mnt/etc/fstab

# ==============================================================================
# CONFIGURATION TRANSFER
# ==============================================================================
echo "Setting up workspace in chroot (/setup_tmp)..."
mkdir -p /mnt/setup_tmp

# Get absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Copy scripts and config to /mnt/setup_tmp
cp "$SCRIPT_DIR/"* /mnt/setup_tmp/ 2>/dev/null || true
chmod +x /mnt/setup_tmp/*.sh 2>/dev/null || true

# Generate environment file for chroot
cat <<ENV >/mnt/setup_tmp/setup_env.sh
USER_PW="$USER_PW"
ROOT_PW="$ROOT_PW"
INSTALL_MODE="$INSTALL_MODE"
ENV

echo "Cloning dotfiles..."
git clone "${DOTFILES_REPO:-https://github.com/ilnazziiazi/dotfiles}" -b "${DOTFILES_BRANCH:-main}" "/mnt/home/${USERNAME}/dotfiles"

# ==============================================================================
# CHROOT EXECUTION (SERVER PHASE)
# ==============================================================================
echo "Configuring system inside chroot (Server Phase)..."

if [ ! -f "/mnt/setup_tmp/01-server-chroot.sh" ]; then
    echo "ERROR: Failed to copy scripts to /mnt/setup_tmp/. Cannot proceed with chroot."
    exit 1
fi

arch-chroot /mnt bash /setup_tmp/01-server-chroot.sh
