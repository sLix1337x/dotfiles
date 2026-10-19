# Homebrew environment (must load before .zshrc)
eval "$(/opt/homebrew/bin/brew shellenv)"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ANALYTICS=1

# Terminal emulators (for GUI-launched shells)
export PATH="/Applications/kitty.app/Contents/MacOS:/Applications/Ghostty.app/Contents/MacOS:$PATH"

# User-local binaries
export PATH="$HOME/.local/bin:$PATH"
