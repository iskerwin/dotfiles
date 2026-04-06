#command-finder/lib/format.zsh

cf::format_row() {
  printf "%s\t%s\t%s\t%s\n" "$1" "$2" "$3" "$4"
}