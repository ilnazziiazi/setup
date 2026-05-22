#!/bin/bash
set -e

source /setup_tmp/config.env
source /setup_tmp/setup_env.sh

echo "Configuring timezone..."
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc

echo "Configuring locales..."
sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" >/etc/locale.conf

echo "Setting hostname..."
echo "${HOSTNAME}" >/etc/hostname

echo "Setting up users..."
echo "root:${ROOT_PW}" | chpasswd
useradd -m -G wheel,docker,video,audio -s /bin/zsh "${USERNAME}"
echo "${USERNAME}:${USER_PW}" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "Configuring ZRAM..."
mkdir -p /etc/systemd/zram-generator.conf.d
cat <<ZRAM >/etc/systemd/zram-generator.conf
[zram0]
zram-size = ram
compression-algorithm = zstd
ZRAM

echo "Installing systemd-boot..."
bootctl install

cat <<LOADER >/boot/loader/loader.conf
default arch.conf
timeout 3
console-mode max
editor no
LOADER

ROOT_PARTUUID=$(blkid -s PARTUUID -o value $(findmnt / -n -o SOURCE))
cat <<ENTRY >/boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=PARTUUID=${ROOT_PARTUUID} rw
ENTRY

echo "Enabling core services..."
systemctl enable NetworkManager
systemctl enable docker
systemctl enable tailscaled
systemctl enable fstrim.timer

echo "Fixing permissions on home directory..."
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}"

echo "Installing oh-my-zsh..."
sudo -u "${USERNAME}" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

echo "Stowing CLI dotfiles..."
cd "/home/${USERNAME}/dotfiles"
sudo -u "${USERNAME}" rm ../.zshrc
sudo -u "${USERNAME}" stow git nvim p10k tmux zsh
