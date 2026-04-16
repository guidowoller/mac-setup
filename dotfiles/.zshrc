export PATH="/opt/homebrew/bin:$PATH"
export PATH="$HOME/bin:$PATH"

# load only for interactive shells
if [[ -o interactive && "$TERM_PROGRAM" == "iTerm.app" ]]; then
  [ -f "$HOME/.zshrc.iterm" ] && source "$HOME/.zshrc.iterm"
fi
export PATH="$HOME/.local/bin:$PATH"

# aliase

# Git
alias gs="git status"
alias gp="git pull"
alias gd="git diff"

# Navigation
alias ..="cd .."
alias ...="cd ../.."

# Utilities
alias cls="clear"
alias myip="curl ifconfig.me"

# Work helpers
alias a="$HOME/bin/a.sh"
alias closeall="$HOME/bin/close-all-apps.sh"

# nvim for vi
alias vi="nvim"

# ms365 sync script
alias ms365="ms365.sh"

#script aliase
alias vpn="~/mac-setup/scripts/vpn.sh"
alias mode="~/mac-setup/scripts/mode.sh"

