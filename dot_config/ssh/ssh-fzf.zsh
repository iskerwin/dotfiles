#!/usr/bin/env zsh

# Better completion for ssh/telnet in Zsh with FZF
setopt no_beep
SSH_CONFIG_FILE="${SSH_CONFIG_FILE:-$HOME/.ssh/config}"

# 设置补全触发器为反斜杠
export FZF_COMPLETION_TRIGGER='\'

# Parse the file and handle the include directive.
_parse_config_file() {
  setopt localoptions rematchpcre
  unsetopt nomatch

  local config_file_path=$(realpath "$1")
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ $line =~ ^[Ii]nclude[[:space:]]+(.*) ]] && (( $#match > 0 )); then
      local include_path="${match[1]}"
      if [[ $include_path == ~* ]]; then
        local expanded_include_path=${include_path/#\~/$HOME}
      else
        local expanded_include_path="$HOME/.ssh/$include_path"
      fi
      for include_file_path in $~expanded_include_path; do
        if [[ -f "$include_file_path" ]]; then
          echo ""
          _parse_config_file "$include_file_path"
        fi
      done
    else
      echo "$line"
    fi
  done < "$config_file_path"
}

_ssh_host_list() {
  local ssh_config host_list

  ssh_config=$(_parse_config_file $SSH_CONFIG_FILE)
  ssh_config=$(echo $ssh_config | command grep -v -E "^\s*#[^_]")

  host_list=$(echo $ssh_config | command awk '
    function join(array, start, end, sep, result, i) {
      if (sep == "")
        sep = " "
      else if (sep == SUBSEP)
        sep = ""
      result = array[start]
      for (i = start + 1; i <= end; i++)
        result = result sep array[i]
      return result
    }

    function parse_line(line) {
      n = split(line, line_array, " ")
      key = line_array[1]
      value = join(line_array, 2, n)
      return key "#-#" value
    }

    BEGIN {
      IGNORECASE = 1
      FS="\n"
      RS=""
      host_list = ""
    }
    {
      user = " "
      host_name = ""
      alias = ""
      desc = ""
      desc_formated = " "

      for (line_num = 1; line_num <= NF; ++line_num) {
        line = parse_line($line_num)
        split(line, tmp, "#-#")
        key = tolower(tmp[1])
        value = tmp[2]

        if (key == "host") { alias = value }
        if (key == "user") { user = value }
        if (key == "hostname") { host_name = value }
        if (key == "#_desc") { desc = value }
      }

      if (desc) {
        desc_formated = sprintf("[\033[00;34m%s\033[0m]", desc)
      }

      if (host_name == "") {
        host_name = alias
      }

      if (alias && host_name) {
        host = sprintf("%s|->|%s|%s|%s\n", alias, host_name, user, desc_formated)
        host_list = host_list host
      }
    }
    END {
      print host_list
    }
  ')

  echo $host_list | command sort -u
}

_fzf_list_generator() {
  local header host_list

  host_list=$(_ssh_host_list)

  header="
Alias|->|Hostname|User|Desc
─────|──|────────|────|────
"

  host_list="${header}\n${host_list}"
  echo $host_list | command column -t -s '|'
}

# 共享的 FZF 选项函数
_fzf_remote_common() {
  local prompt="$1"
  local result selected_host
  
  result=$(_fzf_list_generator | fzf \
    --height 60% \
    --ansi \
    --border \
    --cycle \
    --info=inline \
    --header-lines=2 \
    --reverse \
    --prompt="$prompt" \
    --no-separator \
    --header='' \
    --bind 'shift-tab:up,tab:down,bspace:backward-delete-char/eof' \
    --preview 'ssh -T -G $(cut -f 1 -d " " <<< {}) | grep -i -E "^User |^HostName |^Port |^ControlMaster |^ForwardAgent |^LocalForward |^IdentityFile |^RemoteForward |^ProxyCommand |^ProxyJump " | column -t' \
    --preview-window=right:40%)
    
  echo "$result"
}

# 修改 fzf 补全函数来处理 ssh 和 telnet 命令
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    ssh|telnet)
      local result selected_host
      result=$(_fzf_remote_common "Remote > ")
      
      if [ -n "$result" ]; then
        selected_host=$(echo "$result" | awk '{print $1}')
        echo "$selected_host"
      fi
      ;;
    *)
      fzf "$@"
      ;;
  esac
}

# 保留快捷键功能
remote-fzf() {
  local result selected_host
  
  result=$(_fzf_remote_common "Remote > ")

  if [ -n "$result" ]; then
    selected_host=$(echo "$result" | awk '{print $1}')
    BUFFER="ssh $selected_host"
    zle accept-line
  fi
  
  zle reset-prompt
}

# 创建并绑定快捷键
zle -N remote-fzf
bindkey '^i' remote-fzf

# vim: set ft=zsh sw=2 ts=2 et