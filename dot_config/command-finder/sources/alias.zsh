#command-finder/sources/alias.zsh

cf::source_alias() {
  local name value

  for name value in ${(kv)aliases}; do
    value=${value//$'\n'/ }
    cf::format_row 2000 "$name" "$value" "alias" "" ""
  done
}