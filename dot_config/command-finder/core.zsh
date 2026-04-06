command_finder() {
  emulate -L zsh

  local input result cmd

  input=$(
    cf::source_history
    cf::source_alias
    cf::source_function
  )

local sorted width
sorted=$(print -r -- "$input" | sort -t $'\t' -k1,1nr)
width=$(print -r -- "$sorted" | awk -F '\t' '{l=length($2); if(l>m) m=l} END{print m}')
input=$(print -r -- "$sorted" | cf::render "$width")

  result=$(print -r -- "$input" | cf::fzf)
  [[ -z "$result" ]] && return

  # 取 raw 字段（第3列）
  cmd=$(print -r -- "$result" | cut -f3)

  cf::history_add "$cmd"

  if [[ -n $ZLE ]]; then
    LBUFFER+="$cmd"
  else
    print -z "$cmd"
  fi
}