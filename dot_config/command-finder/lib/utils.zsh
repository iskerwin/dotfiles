cf::require() {
  (( $+commands[$1] ))
}

cf::history_file() {
  print -r -- "$HOME/.config/command-finder/history"
}