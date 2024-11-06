export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS
    --bind='ctrl-/:toggle-preview'
    --bind='ctrl-y:execute-silent(echo {+} | pbcopy)'
    --header='
╭───────────── Controls ──────────────╮
│ CTRL-/: preview  • CTRL-Y: copy     │
╰─────────────────────────────────────╯'
"
# Custom function to parse SSH config and format output
__fzf_list_hosts() {
  setopt localoptions nonomatch
  
  awk '
    BEGIN {
      IGNORECASE = 1
      RS=""
      FS="\n"
      print "Alias|->|Hostname|User|Desc\n─────|──|────────|────|────"
    }
    {
      user = " "
      hostname = ""
      alias = ""
      desc = " "
      
      # Get Host entry (alias)
      for (i = 1; i <= NF; i++) {
        line = $i
        gsub(/^[ \t]+|[ \t]+$/, "", line)
        
        if (line ~ /^Host /) {
          sub(/^Host /, "", line)
          if (line !~ /[*?]/) {
            alias = line
          }
        }
        else if (line ~ /^HostName /) {
          sub(/^HostName /, "", line)
          hostname = line
        }
        else if (line ~ /^User /) {
          sub(/^User /, "", line)
          user = line
        }
        else if (line ~ /^#_Desc /) {
          sub(/^#_Desc /, "", line)
          desc = line
        }
      }
      
      if (alias && hostname) {
        printf "%s|->|%s|%s|%s\n", alias, hostname, user, desc
      }
    }
  ' ~/.ssh/config 2>/dev/null | column -t -s "|"
}

# Enhanced SSH completion
_fzf_complete_ssh() {
  local tokens
  tokens=(${(z)1})
  
  _fzf_complete --ansi --border --cycle \
    --height 80% \
    --reverse \
    --header-lines=2 \
    --prompt="SSH Remote > " \
    --preview 'host=$(echo {} | awk "{print \$1}"); 
              echo -e "\033[1;34m=== SSH Config ===\033[0m";
              ssh -G $host 2>/dev/null | grep -i -E "^(hostname |port |user |identityfile |controlmaster |forwardagent |localforward |remoteforward |proxycommand )" | column -t' \
    --preview-window=right:50% \
    -- "$@" < <(__fzf_list_hosts)
}

_fzf_complete_ssh_post() {
  awk '{print $1}'
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