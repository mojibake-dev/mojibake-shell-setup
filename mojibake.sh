#!/usr/bin/env bash
set -euo pipefail

# Determine OS and architecture
tmp_os=$(uname | tr '[:upper:]' '[:lower:]')
case "$tmp_os" in
  linux) OS=linux ;;  
  darwin) OS=osx ;;
  *) echo "Unsupported OS: $tmp_os" >&2; exit 1 ;;
esac

arch_raw=$(uname -m)
case "$arch_raw" in
  x86_64) ARCH=amd64 ;;  
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $arch_raw" >&2; exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to fallback install from bundled binary
install_bundled_zsh() {
  BIN_NAME="zsh.${OS}.${ARCH}"
  BIN_SRC="$SCRIPT_DIR/$BIN_NAME"
  if [ ! -x "$BIN_SRC" ]; then
    echo "❌ Bundled zsh binary not found: $BIN_SRC" >&2
    exit 1
  fi

  # choose install path
  if [ -w "/usr/local/bin" ]; then
    DEST="/usr/local/bin/zsh"
    echo "⚠️  Installing bundled zsh to $DEST"
    sudo install -m755 "$BIN_SRC" "$DEST"
  else
    mkdir -p "$HOME/bin"
    DEST="$HOME/bin/zsh"
    echo "⚠️  Installing bundled zsh to $DEST"
    install -m755 "$BIN_SRC" "$DEST"
    export PATH="$HOME/bin:$PATH"
  fi

  # make it shell
  chsh -s "$DEST"
}

# 1) Check if zsh is already installed
if command -v zsh &>/dev/null; then
  echo "✅ zsh is already installed at $(command -v zsh)"
  # ensure default shell
  if [ "$SHELL" != "$(command -v zsh)" ]; then
    echo "🔄 Setting zsh as default shell"
    chsh -s "$(command -v zsh)"
  fi
else
  echo "🔍 zsh not found — trying package manager install"
  INSTALLED=0
  if command -v brew &>/dev/null; then
    brew install zsh && INSTALLED=1
  elif command -v apt-get &>/dev/null; then
    sudo apt-get update
    sudo apt-get install -y zsh && INSTALLED=1
  elif command -v pacman &>/dev/null; then
    sudo pacman -Sy --noconfirm zsh && INSTALLED=1
  fi

  if [ $INSTALLED -eq 1 ] && command -v zsh &>/dev/null; then
    echo "✅ zsh installed via package manager"
    chsh -s "$(command -v zsh)"
  else
    echo "⚠️  Package manager install failed or not available"
    install_bundled_zsh
  fi
fi

# 2) Install Oh My Zsh (no .zshrc overwrite)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "📥 Installing Oh My Zsh"
  mkdir -p "$HOME/.oh-my-zsh"
  curl -fsSL https://codeload.github.com/ohmyzsh/ohmyzsh/tar.gz/master \
    | tar -xz --strip-components=1 -C "$HOME/.oh-my-zsh"
fi

# 3) Plugins for Oh My Zsh
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
declare -A PLUGINS=(
  [asdf]="asdf-vm/asdf"
  [zsh-autosuggestions]="zsh-users/zsh-autosuggestions"
  [zsh-completions]="zsh-users/zsh-completions"
  [zsh-history-substring-search]="zsh-users/zsh-history-substring-search"
  [zsh-syntax-highlighting]="zsh-users/zsh-syntax-highlighting"
)
for name in "${!PLUGINS[@]}"; do
  dest="$ZSH_CUSTOM/plugins/$name"
  if [ ! -d "$dest" ]; then
    echo "🔌 Installing plugin $name"
    mkdir -p "$dest"
    curl -fsSL "https://codeload.github.com/${PLUGINS[$name]}/tar.gz/master" \
      | tar -xz --strip-components=1 -C "$dest"
  fi
done

# 4) Install Oh My Posh
echo "🖌️ Installing Oh My Posh"
if [ "$OS" = "osx" ]; then
  if ! command -v brew &>/dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  brew install janisdd/oh-my-posh/oh-my-posh
else
  BIN="${HOME}/.local/bin/oh-my-posh"
  mkdir -p "$(dirname "$BIN")"
  case "$ARCH" in
    amd64) FILE=posh-linux-amd64 ;;
    arm64) FILE=posh-linux-arm64 ;;
  esac
  curl -fsSL "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/$FILE" \
    -o "$BIN" && chmod +x "$BIN"
fi

# 5) Install Hermit Nerd Font
if [ "$OS" = "osx" ]; then
  FONT_DIR="$HOME/Library/Fonts"
else
  FONT_DIR="$HOME/.local/share/fonts"
fi
mkdir -p "$FONT_DIR"
echo "🔤 Installing Hermit Nerd Font"
curl -fsSL \
  "https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hermit/Regular/complete/Hermit%20Nerd%20Font%20Complete.ttf" \
  -o "$FONT_DIR/Hermit Nerd Font Complete.ttf"
[[ "$OS" != "osx" ]] && fc-cache -f

# 6) Symlinks for dotfiles and theme
ln -sf "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
mkdir -p "$HOME/.oh-my-posh/themes"
ln -sf "$SCRIPT_DIR/mojibake.omp.json" \
      "$HOME/.oh-my-posh/themes/mojibake.omp.json"

# 7) Launch zsh
exec zsh -l
