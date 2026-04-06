cf::source_alias() {
  alias | while read -r line; do
    local name=${line%%=*}
    local value=${line#*=}
    value=${value#\'}
    value=${value%\'}

    cf::format_row 2000 "$name" "$value" "alias"
  done
}