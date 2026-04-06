#command-finder/sources/function.zsh

cf::source_function() {
  local file="$HOME/.config/aliases/functions.zsh"
  [[ -f "$file" ]] || return

  awk '
  /^[[:space:]]*#/ {
    last_comment = substr($0, index($0, "#") + 2)
    next
  }

  /^[a-zA-Z0-9_]+[[:space:]]*\(\)/ {
    name = $0
    sub(/[[:space:]]*\(.*/, "", name)
    print name "\t" last_comment
    last_comment = ""
  }

  /^function[[:space:]]+[a-zA-Z0-9_]+/ {
    name = $0
    sub(/^function[[:space:]]+/, "", name)
    sub(/[[:space:]]*\(.*/, "", name)
    print name "\t" last_comment
    last_comment = ""
  }

  !/^[[:space:]]*#/ && !/^[a-zA-Z0-9_]/ && !/^function[[:space:]]/ {
    last_comment = ""
  }
  ' "$file" |
  while IFS=$'\t' read -r name desc; do
    cf::format_row 1000 "$name" "$desc" "function"
  done
}