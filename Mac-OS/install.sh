#!/usr/bin/env bash
#
# Installs the macOS terminal setup: Homebrew packages, then symlinks every
# config into place.
#
# Idempotent - safe to re-run. Anything already in the way is backed up with a
# timestamp before being replaced. Symlinks that already point at this repo are
# left alone.
#
#   ./install.sh                 full install
#   ./install.sh --no-tools      configs only, skip brew bundle
#   ./install.sh --dry-run       show what would happen, change nothing
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
NO_TOOLS=0

for arg in "$@"; do
  case "$arg" in
    --no-tools) NO_TOOLS=1 ;;
    --dry-run)  DRY_RUN=1 ;;
    -h|--help)  sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

# ------------------------------------------------------------------ output --
BOLD=$'\033[1m'; CYAN=$'\033[36m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
RED=$'\033[31m'; GREY=$'\033[90m'; RESET=$'\033[0m'

step() { printf '\n%s==> %s%s\n' "$CYAN$BOLD" "$1" "$RESET"; }
ok()   { printf '    %s[ok]%s   %s\n' "$GREEN" "$RESET" "$1"; }
skip() { printf '    %s[skip] %s%s\n' "$GREY" "$1" "$RESET"; }
warn() { printf '    %s[warn]%s %s\n' "$YELLOW" "$RESET" "$1"; }
fail() { printf '    %s[fail]%s %s\n' "$RED" "$RESET" "$1"; }

FAILED=0

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '    %swould run:%s %s\n' "$GREY" "$RESET" "$*"
  else
    "$@"
  fi
}

# Symlink $1 (inside the repo) to $2, backing up whatever is already there.
link() {
  local src="$REPO/$1" dest="$2" label="${3:-$1}"

  if [[ ! -e $src ]]; then
    fail "$label - missing in repo: $src"
    FAILED=$((FAILED + 1))
    return
  fi

  # Already pointing at this repo? nothing to do.
  if [[ -L $dest && "$(readlink "$dest")" == "$src" ]]; then
    skip "$label already linked"
    return
  fi

  run mkdir -p "$(dirname "$dest")"

  if [[ -e $dest || -L $dest ]]; then
    run mv "$dest" "$dest.$STAMP.bak"
    ok "backed up existing -> $(basename "$dest").$STAMP.bak"
  fi

  run ln -sfn "$src" "$dest"
  ok "$label -> $dest"
}

printf '\n%s  dotfiles - macOS setup%s\n  repo: %s\n' "$BOLD" "$RESET" "$REPO"
[[ $DRY_RUN -eq 1 ]] && warn 'dry run - nothing will be changed'

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "this installer is for macOS; detected $(uname -s)"
  exit 1
fi

# ------------------------------------------------------------------- tools --
if [[ $NO_TOOLS -eq 0 ]]; then
  step 'Homebrew packages'
  if ! command -v brew >/dev/null 2>&1; then
    warn 'Homebrew is not installed. Install it first:'
    warn '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    warn 'then re-run this script.'
    FAILED=$((FAILED + 1))
  else
    run brew bundle --file "$REPO/Brewfile" || {
      warn 'brew bundle reported errors - continuing with configs'
      FAILED=$((FAILED + 1))
    }
    ok 'brew bundle finished'
  fi
else
  step 'Homebrew packages'
  skip 'skipped (--no-tools)'
fi

# ----------------------------------------------------------------- configs --
step 'Shell'
link '.zshrc'         "$HOME/.zshrc"
link '.zprofile'      "$HOME/.zprofile"
link '.bashrc'        "$HOME/.bashrc"
link '.bash_profile'  "$HOME/.bash_profile"
link '.tmux.conf'     "$HOME/.tmux.conf"

step 'Git'
link '.gitconfig'      "$HOME/.gitconfig"
link '.gitignore_global' "$HOME/.gitignore_global"
link 'config/delta/themes/rose-pine.gitconfig' "$HOME/.config/delta/themes/rose-pine.gitconfig" 'delta theme'

# Identity is deliberately not in the repo - seed it once, never overwrite.
if [[ -e "$HOME/.gitconfig.local" ]]; then
  skip '~/.gitconfig.local already exists'
else
  run cp "$REPO/.gitconfig.local.example" "$HOME/.gitconfig.local"
  ok 'created ~/.gitconfig.local - edit it to set your name and email'
fi

step 'Tools'
link 'config/starship/starship.toml' "$HOME/.config/starship.toml"        'starship'
link 'config/bat/config'             "$HOME/.config/bat/config"           'bat'
link 'config/lazygit/config.yml'     "$HOME/.config/lazygit/config.yml"   'lazygit'
link 'config/btop/btop.conf'         "$HOME/.config/btop/btop.conf"       'btop'
link 'config/fastfetch/config.jsonc' "$HOME/.config/fastfetch/config.jsonc" 'fastfetch'

step 'Terminals'
link 'config/alacritty/alacritty.toml' "$HOME/.config/alacritty/alacritty.toml" 'alacritty'
link 'config/kitty/kitty.conf'         "$HOME/.config/kitty/kitty.conf"        'kitty'
link 'config/ghostty/config'           "$HOME/.config/ghostty/config"           'ghostty'

step 'Editors'
link 'config/nvim/init.lua'    "$HOME/.config/nvim/init.lua"  'neovim'
link 'config/zed/settings.json' "$HOME/.config/zed/settings.json" 'zed'

# ----------------------------------------------------------------- summary --
step 'Notes'
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  warn '.tmux.conf expects tpm and several plugins that are not vendored here:'
  warn '  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm'
  warn 'then press prefix + I inside tmux to fetch the rest.'
fi
warn 'Some tmux keybindings call helper scripts in ~/.config/tmux/ that are not'
warn 'part of this repo; those bindings stay inert until you add them.'

printf '\n'
if [[ $FAILED -gt 0 ]]; then
  printf '  %s%d step(s) need attention - see above.%s\n\n' "$RED" "$FAILED" "$RESET"
  exit 1
fi
printf '  %sAll done.%s Set your git identity in ~/.gitconfig.local, then restart your shell.\n\n' "$GREEN" "$RESET"
