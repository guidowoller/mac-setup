#!/bin/zsh

# PATH
export PATH="/opt/homebrew/bin:$PATH"
export PATH="$HOME/bin:$PATH"

# Prompt / Tools
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

# SSH Agent (1Password)
export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# Completion
autoload -Uz compinit
compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# eza replacements
unalias ll 2>/dev/null
unalias l 2>/dev/null

ll() {
  eza -alh --icons --group-directories-first "$@"
}

l() {
  eza -l --icons "$@"
}

# Git aliases
alias gs="git status"
alias gp="git pull"
alias gd="git diff"

# Navigation
alias ..="cd .."
alias ...="cd ../.."

# Utilities
alias cls="clear"
alias myip="curl ifconfig.me"
alias cat="bat"

# Work helpers
alias wguni="$HOME/wg-uni.sh"
alias wgdown="$HOME/wg-uni-down.sh"
alias uni="$HOME/uni.sh"
alias a="$HOME/a.sh"

# mac-setup helpers
alias sync-dotfiles="~/mac-setup/sync.sh && cd ~/mac-setup && git status"
alias doctor="~/mac-setup/doctor.sh"
alias update="~/mac-setup/update.sh"

# History
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY
setopt HIST_IGNORE_SPACE

# Navigation convenience
setopt AUTO_CD
