#!/bin/bash
set -e

source /config.env
source /setup_env.sh

echo "Installing additional packages..."
pacman -Syu --noconfirm base-devel git sudo zsh curl zram-generator \
  vpl-gpu-rt pipewire-alsa pipewire-pulse \
  docker tailscale polkit hyprpolkitagent wayland xwayland-satellite \
  xdg-desktop-portal-gnome xdg-desktop-portal-gtk nautilus alacritty dms-shell-niri matugen cava qt6-multimedia-ffmpeg \
  fuzzel waybar mako grim slurp wl-clipboard \
  stow neovim tmux swaybg pavucontrol zoxide swayidle gnome-keyring \
  noto-fonts noto-fonts-emoji dconf

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

echo "Configuring gnome-keyring auto-unlock..."
sed -i '/^auth.*include.*system-local-login/a auth       optional   pam_gnome_keyring.so' /etc/pam.d/login
sed -i '/^session.*include.*system-local-login/a session    optional   pam_gnome_keyring.so auto_start' /etc/pam.d/login

echo "Cloning dotfiles..."
sudo -u "${USERNAME}" git clone "${DOTFILES_REPO}" -b "${DOTFILES_BRANCH}" "/home/${USERNAME}/dotfiles"

echo "Installing oh-my-zsh..."
sudo -u "${USERNAME}" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

echo "Configuring ZRAM..."
mkdir -p /etc/systemd/zram-generator.conf.d
cat <<ZRAM >/etc/systemd/zram-generator.conf
[zram0]
zram-size = ram
compression-algorithm = zstd
ZRAM

echo "Installing systemd-boot..."

# remove all stale EFI boot entries from nvram (case-insensitive)
efibootmgr | while read -r line; do
  lower=$(echo "$line" | tr '[:upper:]' '[:lower:]')
  case "$lower" in
  *"linux boot manager"* | *grub* | *limine* | *refind* | *"windows boot manager"*)
    b=$(echo "$line" | sed -n 's/Boot\([0-9A-F]*\).*/\1/p')
    [ -n "$b" ] && efibootmgr -b "$b" -B 2>/dev/null || true
    ;;
  esac
done

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

echo "Enabling services..."
systemctl enable NetworkManager
systemctl enable docker
systemctl enable tailscaled
systemctl enable fstrim.timer

echo "Installing yay and helium-browser..."
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >/etc/sudoers.d/temp_nopasswd
sudo -u "${USERNAME}" bash -c "cd /home/${USERNAME} && git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si --noconfirm"
sudo -u "${USERNAME}" bash -c "yay -S --noconfirm helium-browser-bin"
sudo -u "${USERNAME}" bash -c "yay -S --noconfirm otf-sf-pro"

echo "Installing SF Mono Nerd Font..."
mkdir -p /usr/share/fonts/OTF
git clone --depth=1 https://github.com/epk/SF-Mono-Nerd-Font /tmp/sf-mono-nerd-font
cp /tmp/sf-mono-nerd-font/*.otf /usr/share/fonts/OTF/
fc-cache -f
rm -rf /tmp/sf-mono-nerd-font
rm /etc/sudoers.d/temp_nopasswd
rm -rf "/home/${USERNAME}/yay-bin"

echo "Setting up dotfiles..."
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/dotfiles"

echo "Stowing dotfiles..."
cd "/home/${USERNAME}/dotfiles"
sudo -u "${USERNAME}" bash -c "
  stow ghostty git nvim p10k tmux zsh niri waybar fuzzel mako
"

echo "Configuring niri services and portal settings..."
sudo -u "${USERNAME}" systemctl --user add-wants niri.service dms

echo "Configuring hyprpolkitagent override..."
sudo -u "${USERNAME}" mkdir -p "/home/${USERNAME}/.config/systemd/user/hyprpolkitagent.service.d"
sudo -u "${USERNAME}" bash -c "cat <<EOF > '/home/${USERNAME}/.config/systemd/user/hyprpolkitagent.service.d/override.conf'
[Unit]
After=graphical-session.target
EOF"

# Clean up passwords file
rm -f /setup_env.sh
