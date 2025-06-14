#!/usr/bin/env bash
set -euo pipefail

# Determine OS
tmp_os=$(uname | tr '[:upper:]' '[:lower:]')
case "$tmp_os" in
  linux) OS=linux ;;  
  darwin) OS=osx ;;
  *) echo "Unsupported OS: $tmp_os" >&2; exit 1 ;;
esac

# Determine package manager
PKG_MANAGER=""
if command -v brew &>/dev/null; then
  PKG_MANAGER="brew"
elif command -v apt-get &>/dev/null; then
  PKG_MANAGER="apt-get"
elif command -v pacman &>/dev/null; then
  PKG_MANAGER="pacman"
else
  echo "No supported package manager found (brew, apt-get, pacman). Please install zsh manually." >&2
  exit 1
fi

# 1) Install zsh via package manager
echo "Installing zsh using $PKG_MANAGER"
case "$PKG_MANAGER" in
  brew)
    brew install zsh
    ;;
  apt-get)
    sudo apt-get update
    sudo apt-get install -y zsh
    ;;
  pacman)
    sudo pacman -Sy --noconfirm zsh
    ;;
esac

# Verify installation
if ! command -v zsh &>/dev/null; then
  echo "zsh installation failed." >&2
  exit 1
fi

# 2) Set as default shell if not already
ZSH_PATH=$(command -v zsh)
if [ "$SHELL" != "$ZSH_PATH" ]; then
  echo "Setting zsh as default shell: $ZSH_PATH"
  chsh -s "$ZSH_PATH"
fi

# 3) Install Oh My Zsh (no .zshrc overwrite)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing Oh My Zsh"
  mkdir -p "$HOME/.oh-my-zsh"
  curl -fsSL https://codeload.github.com/ohmyzsh/ohmyzsh/tar.gz/master \
    | tar -xz --strip-components=1 -C "$HOME/.oh-my-zsh"
fi

# 4) Install plugins
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
declare -A PLUGINS=(
  [git]=""
  [docker]=""
  [asdf]="asdf-vm/asdf"
  [zsh-autosuggestions]="zsh-users/zsh-autosuggestions"
  [zsh-completions]="zsh-users/zsh-completions"
  [zsh-history-substring-search]="zsh-users/zsh-history-substring-search"
  [zsh-syntax-highlighting]="zsh-users/zsh-syntax-highlighting"
)
for name in "${!PLUGINS[@]}"; do
  dest="$ZSH_CUSTOM/plugins/$name"
  if [ ! -d "$dest" ]; then
    echo "Installing plugin $name"
    mkdir -p "$dest"
    if [ -n "${PLUGINS[$name]}" ]; then
      curl -fsSL "https://codeload.github.com/${PLUGINS[$name]}/tar.gz/master" \
        | tar -xz --strip-components=1 -C "$dest"
    fi
  fi
done

# 5) Install Oh My Posh
echo "Installing Oh My Posh"
if [ "$OS" = "osx" ]; then
  if ! command -v brew &>/dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(brew shellenv)"
  fi
  brew install janisdd/oh-my-posh/oh-my-posh
elif [ "$PKG_MANAGER" = "apt-get" ]; then
  sudo apt-get update
  sudo apt-get install -y oh-my-posh
elif [ "$PKG_MANAGER" = "pacman" ]; then
  sudo pacman -Sy --noconfirm oh-my-posh
fi

# Fallback to binary if command not found
if ! command -v oh-my-posh &>/dev/null; then
  BIN="$HOME/.local/bin/oh-my-posh"
  mkdir -p "$(dirname "$BIN")"
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) FILE=posh-linux-amd64 ;;
    aarch64|arm64) FILE=posh-linux-arm64 ;;
    *) echo "Unsupported arch for oh-my-posh: $ARCH" >&2; exit 1 ;;
  esac
  curl -fsSL "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/$FILE" \
    -o "$BIN" && chmod +x "$BIN"
  export PATH="$HOME/.local/bin:$PATH"
fi

# Verify oh-my-posh
if ! command -v oh-my-posh &>/dev/null; then
  echo "oh-my-posh command not found in PATH." >&2
  exit 1
fi

# 6) Install Hermit Nerd Font
oh-my-posh font install hermit

# 7) Symlinks for config
echo "Linking dotfiles"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ln -sf "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
mkdir -p "$HOME/.oh-my-posh/themes"
ln -sf "$SCRIPT_DIR/mojibake.omp.json" "$HOME/.oh-my-posh/themes/mojibake.omp.json"

# 8) Start zsh
exec zsh -l
