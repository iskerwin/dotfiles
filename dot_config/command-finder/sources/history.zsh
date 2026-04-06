cf::history_add() {
  local file=$(cf::history_file)
  mkdir -p "${file:h}"

  print -r -- "$1" >> "$file"
  tail -n 1000 "$file" > "$file.tmp" && mv -f "$file.tmp" "$file"
}

cf::source_history() {
  local file=$(cf::history_file)
  [[ -f "$file" ]] || return

  awk '{count[$0]++} END {
    for (cmd in count)
      printf "%d\t%s\t\thistory\n", 3000 + count[cmd], cmd
  }' "$file"
}