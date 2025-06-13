#!/usr/bin/env bash
set -euo pipefail

# ---- 1) Build & install ncurses from source (Linux only) ----
install_ncurses() {
  if [[ "$(uname -s)" == Darwin ]]; then
    return
  fi
  echo "📚 Building ncurses from source…"
  tmp=$(mktemp -d)
  pushd "$tmp"
    curl -fsSL https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.3.tar.gz \
      | tar xz
    cd ncurses-6.3
    ./configure --prefix=/usr/local \
                --with-shared=no \
                --enable-widec \
                --without-debug \
                --without-ada
    make -j"$(nproc)"
    sudo make install
  popd
  rm -rf "$tmp"
}

# ---- 2) Install Zsh (macOS via brew, Linux via static build) ----
install_zsh() {
  echo "🔨 Installing Zsh…"
  os="$(uname -s)"
  if [[ "$os" == Darwin ]]; then
    echo "macOS detected: installing zsh via Homebrew…"
    if ! command -v brew &>/dev/null; then
      echo "Bootstrapping Homebrew…"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    brew install zsh
    return
  fi

  # Linux → ensure ncurses, then build static Zsh
  install_ncurses

  # pick compiler
  if command -v gcc &>/dev/null; then
    export CC=gcc
  elif command -v clang &>/dev/null; then
    export CC=clang
  else
    echo "Error: neither gcc nor clang found." >&2
    exit 1
  fi

  export CFLAGS="-O2 -march=native"
  # require tools
  for tool in make tar xz; do
    command -v "$tool" &>/dev/null || { echo "Error: '$tool' is required." >&2; exit 1; }
  done

  ZSH_VER="5.9"
  tmp=$(mktemp -d)
  pushd "$tmp"
    curl -fsSL "https://www.zsh.org/pub/zsh-${ZSH_VER}.tar.xz" \
      | tar -xJ
    cd "zsh-${ZSH_VER}"
    ./configure --prefix=/usr/local \
                --enable-static \
                --with-term-lib=ncurses \
                LDFLAGS="-static -s -L/usr/local/lib" \
                CPPFLAGS="-I/usr/local/include"
    make -j"$(nproc)"
    sudo make install
  popd
  rm -rf "$tmp"
}

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
