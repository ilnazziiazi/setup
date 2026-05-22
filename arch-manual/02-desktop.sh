#!/bin/bash
set -e

# ==============================================================================
# 02-DESKTOP.SH - GUI and Niri Environment
# ==============================================================================

source /setup_tmp/config.env
source /setup_tmp/setup_env.sh

echo "Installing Desktop & GUI packages..."
pacman -Syu --noconfirm \
  vpl-gpu-rt mesa vulkan-intel intel-media-driver \
  pipewire wireplumber pipewire-alsa pipewire-pulse \
  polkit hyprpolkitagent \
  wayland xwayland-satellite \
  xdg-desktop-portal-gnome xdg-desktop-portal-gtk \
  niri dms-shell-niri matugen cava qt6-multimedia-ffmpeg \
  nautilus alacritty wl-clipboard pavucontrol gnome-keyring noto-fonts-emoji dconf

echo "Configuring gnome-keyring auto-unlock..."
sed -i '/^auth.*include.*system-local-login/a auth       optional   pam_gnome_keyring.so' /etc/pam.d/login
sed -i '/^session.*include.*system-local-login/a session    optional   pam_gnome_keyring.so auto_start' /etc/pam.d/login

echo "Installing yay and AUR packages..."
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >/etc/sudoers.d/temp_nopasswd
sudo -u "${USERNAME}" bash -c "
  cd /home/${USERNAME} &&
  git clone https://aur.archlinux.org/yay-bin.git &&
  cd yay-bin &&
  makepkg -si --noconfirm
"

sudo -u "${USERNAME}" bash -c "yay -S --noconfirm helium-browser-bin otf-sf-pro"

echo "Installing SF Mono Nerd Font..."
mkdir -p /usr/share/fonts/OTF
git clone --depth=1 https://github.com/epk/SF-Mono-Nerd-Font /tmp/sf-mono-nerd-font
cp /tmp/sf-mono-nerd-font/*.otf /usr/share/fonts/OTF/
fc-cache -f
rm -rf /tmp/sf-mono-nerd-font
rm /etc/sudoers.d/temp_nopasswd
rm -rf "/home/${USERNAME}/yay-bin"

echo "Stowing GUI dotfiles..."
cd "/home/${USERNAME}/dotfiles"
sudo -u "${USERNAME}" stow niri

echo "Configuring niri services and portal settings..."
sudo -u "${USERNAME}" mkdir -p "/home/${USERNAME}/.config/systemd/user/niri.service.wants"
sudo -u "${USERNAME}" ln -sf "/usr/lib/systemd/user/dms.service" "/home/${USERNAME}/.config/systemd/user/niri.service.wants/"

echo "Configuring hyprpolkitagent override..."
sudo -u "${USERNAME}" mkdir -p "/home/${USERNAME}/.config/systemd/user/hyprpolkitagent.service.d"
sudo -u "${USERNAME}" bash -c "cat <<EOF > '/home/${USERNAME}/.config/systemd/user/hyprpolkitagent.service.d/override.conf'
[Unit]
After=graphical-session.target
EOF"

echo "Desktop setup complete!"
