#command-finder/sources/history.zsh

cf::history_add() {
  local file=$(cf::history_file)
  mkdir -p "${file:h}"

  print -r -- "$1" >> "$file"
  tail -n 1000 "$file" > "$file.tmp" && mv -f "$file.tmp" "$file"
}

cf::source_history() {
  local file=$(cf::history_file)
  [[ -f "$file" ]] || return

  awk '{count[$0]++} END {for (cmd in count) print count[cmd] "\t" cmd}' "$file" |
  sort -rn |
  head -5 |
  while IFS=$'\t' read -r count cmd; do
    cf::format_row "$((3000 + count))" "$cmd" "used ${count}x" "history"
  done
}