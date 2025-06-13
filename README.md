# mojibake-shell-setup
---
## mojibake.sh

Sets up the following:

---
### .zshrc

- Sources 
    - oh-my-zsh
        - autosuggestions
        - history
        - autocomplete
        - syntax highlighting
    - oh-my-posh theme

---
### My oh-my-posh theme.

- Displays git branch info
- Dispalys venv info
- Replaced prompt char with an Ankh
- Replaced Home char with the mercury(intersex) symbol

---
## Installation

``` sh
mkdir -p ~/Code/mojibake && cd ~/Code/mojibake && \
( git clone https://github.com/mojibake-dev/mojibake-shell-setup.git \
  || { echo "Clone failed—falling back to curl"; \
       curl -fsSL https://codeload.github.com/mojibake-dev/mojibake-shell-setup/tar.gz/main \
         | tar -xz; \
       mv mojibake-shell-setup-main mojibake-shell-setup; } ) \
&& cd mojibake-shell-setup \
&& chmod +x mojibake.sh \
&& ./mojibake.sh
```

