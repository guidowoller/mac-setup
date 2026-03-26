export PATH="/opt/homebrew/bin:$PATH"
export PATH="$HOME/bin:$PATH"

# load only for interactive shells
if [[ -o interactive && "$TERM_PROGRAM" == "iTerm.app" ]]; then
  [ -f "$HOME/.zshrc.iterm" ] && source "$HOME/.zshrc.iterm"
fi
