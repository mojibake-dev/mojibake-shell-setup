#!/usr/bin/env bash
set -euo pipefail

install_zsh_from_release() {
  REPO="mojibake-dev/mojibake-shell-setup"   # ← your GitHub repo
  OS=$(uname | tr '[:upper:]' '[:lower:]')
  case "$OS" in
    linux)   os_part="linux" ;;
    darwin)  os_part="macos" ;;
    *)       echo "Unsupported OS: $OS"; exit 1 ;;
  esac

  arch=$(uname -m)
  case "$arch" in
    x86_64)   arch_part="x86_64" ;;
    aarch64|arm64) arch_part="arm64" ;;
    *)        echo "Unsupported ARCH: $arch"; exit 1 ;;
  esac

  file="zsh-${os_part}-${arch_part}.zip"
  url="https://github.com/${REPO}/releases/latest/download/${file}"
  echo "📥 Downloading $file from $url"
  tmp="/tmp/$file"
  curl -fsSL "$url" -o "$tmp"
  echo "📦 Unpacking to /usr/local/bin"
  unzip -jo "$tmp" "*/bin/zsh" -d /usr/local/bin
  chmod +x /usr/local/bin/zsh
}

# 1) Ensure Zsh
if ! command -v zsh &>/dev/null; then
  install_zsh_from_release
fi

# 2) Make default shell
ZSH_PATH=$(command -v zsh)
if [ "$SHELL" != "$ZSH_PATH" ]; then
  echo "🔄 chsh to $ZSH_PATH"
  chsh -s "$ZSH_PATH"
fi

# …then the rest of your script: Oh My Zsh/plugins install, oh-my-posh, fonts, symlinks, exec zsh …


# ---- locate script dir for symlinks ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- 3) Ensure Zsh is installed ----
if ! command -v zsh &>/dev/null; then
  install_zsh
fi

# ---- 4) Make Zsh the default shell ----
ZSH_PATH="$(command -v zsh)"
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
  echo "🔄 Setting default shell to $ZSH_PATH…"
  chsh -s "$ZSH_PATH"
fi

# ---- 5) Install Oh My Zsh via curl (no git) ----
if [[ ! -d "${HOME}/.oh-my-zsh" ]]; t
