# ~/.bashrc — Bash configuration
# Keep this file POSIX-ish where possible; bash-specific features are explicit.

# Only run for interactive shells.
case $- in
  *i*) ;;
  *) return ;;
esac

# ── Base environment ─────────────────────────────────────────────────────────
export EDITOR="nvim"
export VISUAL="nvim"
export KUBE_EDITOR="nvim"

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# ── PATH ─────────────────────────────────────────────────────────────────────
# Defensive additions for non-login shells.
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"
[[ -d /opt/homebrew/bin ]] && export PATH="/opt/homebrew/bin:$PATH"
[[ -d "$HOME/bin" ]] && export PATH="$HOME/bin:$PATH"

# Android SDK
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
[[ -d "$ANDROID_HOME/platform-tools" ]] && export PATH="$ANDROID_HOME/platform-tools:$PATH"
[[ -d "$ANDROID_HOME/emulator" ]] && export PATH="$ANDROID_HOME/emulator:$PATH"
[[ -d "$ANDROID_HOME/cmdline-tools/latest/bin" ]] && export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

# Java 17 for Android SDK tools
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
[[ -d "$JAVA_HOME/bin" ]] && export PATH="$JAVA_HOME/bin:$PATH"

# Deduplicate PATH entries (bash 4+).
if ((BASH_VERSINFO[0] >= 4)); then
  declare -A _seen
  _new_path=""
  IFS=: read -ra _path_parts <<< "$PATH"
  for _part in "${_path_parts[@]}"; do
    [[ -z "$_part" ]] && continue
    if [[ -z "${_seen[$_part]}" ]]; then
      _seen[$_part]=1
      _new_path="${_new_path:+$_new_path:}$_part"
    fi
  done
  export PATH="$_new_path"
  unset _seen _new_path _path_parts _part
fi

# ── History ──────────────────────────────────────────────────────────────────
export HISTFILE="$HOME/.bash_history"
export HISTSIZE=50000
export HISTFILESIZE=50000
shopt -s histappend
shopt -s cmdhist
export HISTCONTROL="ignoreboth:erasedups"
export HISTTIMEFORMAT="%F %T "

# ── Completion ───────────────────────────────────────────────────────────────
if [[ -r /opt/homebrew/etc/profile.d/bash_completion.sh ]]; then
  source /opt/homebrew/etc/profile.d/bash_completion.sh
elif [[ -r /usr/share/bash-completion/bash_completion ]]; then
  source /usr/share/bash-completion/bash_completion
elif [[ -r /etc/bash_completion ]]; then
  source /etc/bash_completion
fi

# ── Pager ────────────────────────────────────────────────────────────────────
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"

# ── Aliases ──────────────────────────────────────────────────────────────────
alias ls='ls -G'
alias ll='ls -la'
alias la='ls -A'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# ── Functions ────────────────────────────────────────────────────────────────
dev() {
  cd "${DEV_DIR:-$HOME/Documents/dev}" || return 1
}

# ── Tool integrations ────────────────────────────────────────────────────────
# Starship prompt
if command -v starship &>/dev/null; then
  eval "$(starship init bash)"
fi

# zoxide smart cd
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init bash)"
fi

# direnv
if command -v direnv &>/dev/null; then
  eval "$(direnv hook bash)"
fi

# fzf
if command -v fzf &>/dev/null; then
  eval "$(fzf --bash)"
fi

# ── Local overrides ──────────────────────────────────────────────────────────
[[ -f ~/.bash_aliases ]] && source ~/.bash_aliases
[[ -f ~/.bash_functions ]] && source ~/.bash_functions
