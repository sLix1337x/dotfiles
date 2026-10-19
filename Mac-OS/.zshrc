# ~/.zshrc — modular zsh configuration
# Core options, completions, and history. Everything else lives in ~/.zsh/*.zsh.

# ── History ──────────────────────────────────────────────────────────────────
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt extended_history hist_expire_dups_first hist_ignore_dups hist_ignore_space hist_verify share_history

# ── Directory navigation ─────────────────────────────────────────────────────
setopt auto_cd auto_pushd pushd_ignore_dups pushdminus

# ── Completions ──────────────────────────────────────────────────────────────
autoload -Uz compinit
ZSH_COMPDUMP="${HOME}/.zcompdump-${ZSH_VERSION}"
# Rebuild the dump if it is missing or older than 24 hours; otherwise use the
# cached dump for a fast startup.
if [[ ! -f "$ZSH_COMPDUMP" ]] || [[ -n "$ZSH_COMPDUMP"(#qN.mh+24) ]]; then
  compinit -d "$ZSH_COMPDUMP"
else
  compinit -C -d "$ZSH_COMPDUMP"
fi

# ── Modules ──────────────────────────────────────────────────────────────────
# Order matters: paths/env first, then tools/plugins, then aliases/functions,
# then the welcome message which depends on functions already being loaded.
for module in paths env tmux tools plugins ai aliases functions title; do
  [[ -f "${HOME}/.zsh/${module}.zsh" ]] && source "${HOME}/.zsh/${module}.zsh"
done

# ── Welcome message + CLI tools menu ─────────────────────────────────────────
[[ -o interactive ]] && {
  welcome
  show-cli-tools 2>/dev/null
}

# ── zsh-syntax-highlighting must load last ───────────────────────────────────
source "${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# ── zsh-history-substring-search (after syntax-highlighting, required order) ─
source "${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND="fg=#201926,bg=#b899ff,bold"
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND="fg=#f2e7fa,bg=#ff8fc7,bold"
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

# Zero runner (added by the zero plugin SessionStart hook)
export PATH="$HOME/.zero/runtime/bin:$PATH"
