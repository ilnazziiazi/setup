#!/bin/bash

USER_NAME="ziiazi"
USER_HOME="/home/$USER_NAME"
DOTFILES_REPO="https://github.com/ilnazziiazi/dotfiles.git"

echo "=== Post installation ==="

echo "Configuring passwordless sudo for post-install script..."
echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/temp_nopasswd
chmod 440 /etc/sudoers.d/temp_nopasswd

echo "Packages installation..."
pacman -S --noconfirm base-devel git stow neovim zsh docker tailscale tmux

echo "AUR installation..."
sudo -u $USER_NAME bash -c "
  cd /tmp && \
  git clone https://aur.archlinux.org/yay-bin.git && \
  cd yay-bin && \
  makepkg -si --noconfirm
"

echo "dotfiles installation from $DOTFILES_REPO..."
sudo -u $USER_NAME bash -c "
  git clone $DOTFILES_REPO $USER_HOME/dotfiles
"

echo "Stowing dotfiles..."
sudo -u $USER_NAME bash -c "
  cd $USER_HOME/dotfiles && \
  stow git nvim p10k tmux zsh niri waybar fuzzel mako
"

echo "Packages installation from AUR..."
sudo -u $USER_NAME bash -c "
  yay -S --noconfirm helium-browser-bin otf-sf-pro
"

echo "Installing SF Mono Nerd Font..."
mkdir -p /usr/share/fonts/OTF
git clone --depth=1 https://github.com/epk/SF-Mono-Nerd-Font /tmp/sf-mono-nerd-font
cp /tmp/sf-mono-nerd-font/*.otf /usr/share/fonts/OTF/
fc-cache -f
rm -rf /tmp/sf-mono-nerd-font
rm /etc/sudoers.d/temp_nopasswd

echo "Enabling services..."
systemctl enable NetworkManager
systemctl enable docker
systemctl enable tailscaled
systemctl enable fstrim.timer

echo "=== Installation completed ==="
