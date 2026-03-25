export PATH="/opt/homebrew/bin:$PATH"
export PATH="$HOME/bin:$PATH"

# iTerm2 custom config
if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
  [ -f "$HOME/.zshrc.iterm" ] && source "$HOME/.zshrc.iterm"
fi
