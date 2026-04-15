#command-finder/sources/alias.zsh

# command-finder/sources/alias.zsh

cf::source_alias() {
  local -A alias_desc alias_tag

  local alias_dir="$HOME/.config/aliases"
  if [[ -d "$alias_dir" ]]; then
    for f in "$alias_dir"/**/*.zsh(N) "$alias_dir"/*.zsh(N); do
      [[ -f "$f" ]] || continue
      awk '
      /^alias[[:space:]]+[a-zA-Z0-9_=.:-]+/ {
        # 提取 alias 名
        name = $0
        sub(/^alias[[:space:]]+/, "", name)
        sub(/=.*/, "", name)

        # 提取行尾注释：找最后一个未被引号包裹的 #
        line = $0
        desc = ""
        in_single = 0; in_double = 0
        n = split(line, chars, "")
        for (i = 1; i <= n; i++) {
          c = chars[i]
          if (c == "\x27" && !in_double) in_single = !in_single
          else if (c == "\"" && !in_single) in_double = !in_double
          else if (c == "#" && !in_single && !in_double) {
            desc = substr(line, i + 1)
            sub(/^[[:space:]]+/, "", desc)
            sub(/[[:space:]]+$/, "", desc)
            break
          }
        }

        printf "%s\t%s\n", name, desc
      }
      ' "$f"
    done | while IFS=$'\t' read -r name desc; do
      alias_desc[$name]="$desc"
    done
  fi

  local name value
  for name value in ${(kv)aliases}; do
    value=${value//$'\n'/ }
    local adesc="${alias_desc[$name]:-}"
    cf::format_row 2000 "$name" "$value" "alias" "$adesc" ""
  done
}