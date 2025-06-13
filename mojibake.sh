#!/usr/bin/env bash
set -euo pipefail

# 1) Install Zsh from the official tarball as a static binary
install_zsh() {
  echo "🔨 Zsh not found: building static Zsh from source…"
  # ensure compiler & tools
  for tool in gcc make tar xz; do
    command -v "$tool" &>/dev/null || { echo "Error: '$tool' is required." >&2; exit 1; }
  done

  # pick a Zsh version (you can bump this as new releases appear)
  ZSH_VER="5.9"
  tmpdir="$(mktemp -d)"
  pushd "$tmpdir"
    curl -fsSL "https://www.zsh.org/pub/zsh-${ZSH_VER}.tar.xz" \
      | tar -xJ
    cd "zsh-${ZSH_VER}"
    # configure for a fully static build
    ./configure --prefix=/usr/local \
                --enable-static \
                LDFLAGS="-static -s"
    make -j"$(getconf _NPROCESSORS_ONLN)"
    sudo make install
  popd
  rm -rf "$tmpdir"
}

# 2) Locate script dir for later symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 3) Ensure Zsh is installed
if ! command -v zsh &>/dev/null; then
  install_zsh
fi

# 4) Make Zsh the default shell if needed
ZSH_PATH="$(command -v zsh)"
if [ "${SHELL}" != "$ZSH_PATH" ]; then
  echo "🔄 Changing default shell to $ZSH_PATH…"
  chsh -s "$ZSH_PATH"
fi

# 5) Install Oh My Zsh via curl (no git)
if [ ! -d "${HOME}/.oh-my-zsh" ]; then
  echo "📥 Installing Oh My Zsh…"
  mkdir -p "${HOME}/.oh-my-zsh"
  curl -fsSL https://codeload.github.com/ohmyzsh/ohmyzsh/tar.gz/master \
    | tar -xz --strip-components=1 -C "${HOME}/.oh-my-zsh"
fi

# 6) Install plugins via curl|tar
ZSH_CUSTOM="${HOME}/.oh-my-zsh/custom"
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
    echo "🔌 Installing plugin $name…"
    mkdir -p "$dest"
    curl -fsSL "https://codeload.github.com/${PLUGINS[$name]}/tar.gz/master" \
      | tar -xz --strip-components=1 -C "$dest"
  fi
done
# note: 'git' and 'docker' are already included as core OMZ plugins

# 7) Install Oh My Posh
if [[ "$(uname -s)" == Darwin ]]; then
  echo "🖌️ Installing Oh My Posh via Homebrew…"
  if ! command -v brew &>/dev/null; then
    echo "Bootstrapping Homebrew…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  brew install janisdd/oh-my-posh/oh-my-posh
else
  POSH_BIN="${HOME}/.local/bin/oh-my-posh"
  if [ ! -x "$POSH_BIN" ]; then
    echo "🖌️ Installing Oh My Posh (Linux)…"
    mkdir -p "$(dirname "$POSH_BIN")"
    arch=$(uname -m)
    case "$arch" in
      x86_64)       binfile="posh-linux-amd64" ;;
      aarch64|arm64) binfile="posh-linux-arm64" ;;
      armv7*)       binfile="posh-linux-arm" ;;
      *)            echo "⚠️ Unsupported arch: $arch"; exit 1 ;;
    esac
    curl -sSL "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/$binfile" \
      -o "$POSH_BIN"
    chmod +x "$POSH_BIN"
  fi
fi

# 8) Install Hermit Nerd Font
if [[ "$(uname -s)" == Darwin ]]; then
  FONT_DIR="${HOME}/Library/Fonts"
else
  FONT_DIR="${HOME}/.local/share/fonts"
fi
echo "🔤 Installing Hermit Nerd Font…"
mkdir -p "$FONT_DIR"
curl -fsSL \
  "https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hermit/Regular/complete/Hermit%20Nerd%20Font%20Complete.ttf" \
  -o "$FONT_DIR/Hermit Nerd Font Complete.ttf" \
  || echo "⚠️ Font download failed."
[[ "$(uname -s)" != Darwin ]] && fc-cache -f -v

# 9) Symlink your .zshrc and theme files
echo "🔗 Linking .zshrc and Oh My Posh theme…"
ln -sf "$SCRIPT_DIR/.zshrc" "${HOME}/.zshrc"
mkdir -p "${HOME}/.oh-my-posh/themes"
ln -sf "$SCRIPT_DIR/mojibake.omp.json" "${HOME}/.oh-my-posh/themes/mojibake.omp.json"

# 10) Exec into zsh
echo "🎉 Setup complete — launching zsh!"
exec zsh -l
