sudo pacman -Syu --noconfirm \
  pipewire wireplumber pipewire-alsa pipewire-pulse pavucontrol \
  docker docker-compose \
  openssh tailscale

# greeter
dms greeter install
sudo systemctl start greetd

# docker
sudo systemctl enable --now docker
sudo groupadd docker
sudo usermod -aG docker "$USER"
newgrp docker

# ssh
sudo systemctl enable --now sshd

# tailscale
sudo systemctl enable --now tailscaled

# omz
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# omz plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
[[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] &&
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] &&
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
[[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]] &&
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"

# ssh-keygen
ssh-keygen -t ed25519 -C "ilnazziaziev@gmail.com"
cat $HOME/.ssh/id_ed25519.pub
