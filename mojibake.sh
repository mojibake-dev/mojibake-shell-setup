#!/usr/bin/env bash
set -euo pipefail

# ---- helper to install zsh ----
install_zsh() {
  echo "🔨 Zsh not found: installing…"
  os="$(uname -s)"
  if [[ "$os" == Darwin ]]; then
    # macOS → use Homebrew
    echo "macOS detected: installing zsh via Homebrew…"
    if ! command -v brew &>/dev/null; then
      echo "Homebrew not found. Installing Homebrew…"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      eval "$(/opt/homebrew/bin/brew shellenv)"  # adjust if Intel
    fi
    brew install zsh
    return
  fi

  # else → Linux / other Unix → build from source
  echo "Building zsh from source…"
  
  # pick compiler
  if command -v gcc &>/dev/null; then
    export CC=gcc
  elif command -v clang &>/dev/null; then
    export CC=clang
  else
    echo "Error: neither gcc nor clang found. Please install a C compiler." >&2
    exit 1
  fi

  # optimize for native architecture
  export CFLAGS="-O2 -march=native"

  # ensure Git & make
  for tool in git make; do
    if ! command -v "$tool" &>/dev/null; then
      echo "Error: '$tool' is required to build zsh." >&2
      exit 1
    fi
  done

  tmpdir=$(mktemp -d)
  git clone https://github.com/zsh-users/zsh.git "$tmpdir/zsh"
  cd "$tmpdir/zsh"
  ./Util/preconfig
  ./configure --prefix=/usr/local
  make -j"$(getconf _NPROCESSORS_ONLN)"
  sudo make install
  cd - && rm -rf "$tmpdir"
}

# ---- locate our script directory ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- 1) ensure zsh is installed ----
if ! command -v zsh &>/dev/null; then
  install_zsh
fi

# ---- 2) make it the default shell ----
ZSH_PATH="$(command -v zsh)"
if [ "$SHELL" != "$ZSH_PATH" ]; then
  echo "🔄 Changing default shell to zsh…"
  chsh -s "$ZSH_PATH"
fi

# ---- 3) install oh-my-zsh (no .zshrc touch) ----
if [ ! -d "${HOME}/.oh-my-zsh" ]; then
  echo "📥 Cloning Oh My Zsh…"
  git clone https://github.com/ohmyzsh/ohmyzsh.git "${HOME}/.oh-my-zsh"
fi

# ---- 4) pull in custom plugins ----
ZSH_CUSTOM="${HOME}/.oh-my-zsh/custom"
declare -A plugins=(
  [asdf]=https://github.com/asdf-vm/asdf.git
  [zsh-autosuggestions]=https://github.com/zsh-users/zsh-autosuggestions.git
  [zsh-completions]=https://github.com/zsh-users/zsh-completions.git
  [zsh-history-substring-search]=https://github.com/zsh-users/zsh-history-substring-search.git
  [zsh-syntax-highlighting]=https://github.com/zsh-users/zsh-syntax-highlighting.git
)
for name in "${!plugins[@]}"; do
  dest="$ZSH_CUSTOM/plugins/$name"
  if [ ! -d "$dest" ]; then
    echo "🔌 Installing plugin $name…"
    git clone "${plugins[$name]}" "$dest"
  fi
done

# note: 'git' and 'docker' ship with core OMZ

# ---- 5) install oh-my-posh ----
if [[ "$(uname -s)" == Darwin ]]; then
  echo "🖌️  Installing Oh My Posh via Homebrew…"
  if ! command -v brew &>/dev/null; then
    echo "Homebrew missing. Bootstrapping Homebrew…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  brew install janisdd/oh-my-posh/oh-my-posh
else
  POSH_BIN="${HOME}/.local/bin/oh-my-posh"
  if [ ! -x "$POSH_BIN" ]; then
    echo "🖌️  Installing Oh My Posh (Linux)…"
    mkdir -p "$(dirname "$POSH_BIN")"
    arch=$(uname -m)
    case "$arch" in
      x86_64)       binfile="posh-linux-amd64" ;;
      aarch64|arm64) binfile="posh-linux-arm64" ;;
      armv7*)       binfile="posh-linux-arm" ;;
      *)            echo "⚠️ Unsupported arch: $arch"; exit 1 ;;
    esac
    URL="https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/$binfile"
    curl -sSL "$URL" -o "$POSH_BIN"
    chmod +x "$POSH_BIN"
  fi
fi

# ---- 6) install Hermit Nerd Font ----
if [[ "$(uname -s)" == Darwin ]]; then
  FONT_DIR="${HOME}/Library/Fonts"
else
  FONT_DIR="${HOME}/.local/share/fonts"
fi
echo "🔤 Installing Hermit Nerd Font…"
mkdir -p "$FONT_DIR"
curl -fLo "$FONT_DIR/Hermit Nerd Font Complete.ttf" \
  "https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hermit/Regular/complete/Hermit%20Nerd%20Font%20Complete.ttf" \
  || echo "⚠️ Failed to download font."
if [[ "$(uname -s)" != Darwin ]]; then fc-cache -f -v; fi

# ---- 7) symlink your .zshrc ----
echo "🔗 Linking .zshrc…"
ln -sf "${SCRIPT_DIR}/.zshrc" "${HOME}/.zshrc"

# ---- 8) link your custom oh-my-posh theme ----
echo "🔗 Linking mojibake theme…"
mkdir -p "${HOME}/.oh-my-posh/themes"
ln -sf "${SCRIPT_DIR}/mojibake.omp.json" "${HOME}/.oh-my-posh/themes/mojibake.omp.json"

# ---- 9) launch zsh ----
echo "🎉 Setup complete! Switching to zsh…"
exec zsh -l
