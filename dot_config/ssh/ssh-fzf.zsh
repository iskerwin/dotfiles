# Enhance the host listing function to include more details
__fzf_list_hosts() {
  setopt localoptions nonomatch
  local header host_list

  host_list=$(
    (
      command cat ~/.ssh/config ~/.ssh/config.d/* /etc/ssh/ssh_config 2>/dev/null | \
        command grep -i '^\s*host\(name\)\? ' | \
        awk '{printf "%s|->|%s| |\n", $2, $2}'
      
      if [[ -f ~/.ssh/known_hosts ]]; then
        command grep -oE '^[[a-z0-9.,:-]+' ~/.ssh/known_hosts 2>/dev/null | \
          tr ',' '\n' | tr -d '[' | \
          awk '{printf "%s|->|%s| |\n", $1, $1}'
      fi
      
      if [[ -f /etc/hosts ]]; then
        command grep -v '^\s*\(#\|$\)' /etc/hosts 2>/dev/null | \
          command grep -Fv '0.0.0.0' | \
          command sed 's/#.*//' | \
          awk '{printf "%s|->|%s| |\n", $2, $1}'
      fi
    ) | sort -u
  )

  header=$'Alias|->|Hostname|User|Desc\n─────|──|────────|────|────'
  host_list="${header}\n${host_list}"
  
  echo $host_list | column -t -s '|'
}

# Enhanced telnet completion
_fzf_complete_telnet() {
  _fzf_complete --ansi --border --cycle \
    --height 80% \
    --reverse \
    --header-lines=2 \
    --prompt='Telnet Remote > ' \
    --preview 'echo "Port: 23\nProtocol: TELNET\nHost: {1}"' \
    --preview-window=right:40% \
    -- "$@" < <(__fzf_list_hosts)
}

_fzf_complete_telnet_post() {
  awk '{print $1}'
}

# Enhanced SSH completion
_fzf_complete_ssh() {
  local -a tokens
  tokens=(${(z)1})
  
  case ${tokens[-1]} in
    -i|-F|-E)
      _fzf_path_completion "$prefix" "$1"
      ;;
    *)
      local user
      [[ $prefix =~ @ ]] && user="${prefix%%@*}@"
      
      _fzf_complete --ansi --border --cycle \
        --height 80% \
        --reverse \
        --header-lines=2 \
        --prompt='SSH Remote > ' \
        --preview 'ssh -T -G $(cut -f 1 -d " " <<< {}) 2>/dev/null | \
          grep -i -E "^User |^HostName |^Port |^ControlMaster |^ForwardAgent |^LocalForward |^IdentityFile |^RemoteForward |^ProxyCommand |^ProxyJump " | \
          column -t' \
        --preview-window=right:40% \
        -- "$@" < <(__fzf_list_hosts | awk -v user="$user" '{print user $0}')
      ;;
  esac
}

_fzf_complete_ssh_post() {
  awk '{print $1}'
}