#!/usr/bin/env zsh

# Enhanced SSH/Telnet completion for Zsh using FZF
# Features:
# - Parses SSH config files with Include directive support
# - Interactive host selection with preview
# - Supports custom host descriptions
# - Configurable key bindings

# Basic configuration
# Disable terminal beep
setopt no_beep
# Default SSH config file location, can be overridden by environment variable
SSH_CONFIG_FILE="${SSH_CONFIG_FILE:-$HOME/.ssh/config}"
# Set FZF completion trigger character
export FZF_COMPLETION_TRIGGER='\'

# Parse SSH config file and handle Include directives recursively
# @param $1 Path to the SSH config file
# Returns: Concatenated content of all config files
_parse_config_file() {
  # Enable PCRE regex and disable nomatch
  setopt localoptions rematchpcre
  unsetopt nomatch

  # Get absolute path of config file
  local config_file_path=$(realpath "$1")
  
  # Process each line of the config file
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Handle Include directives
    if [[ $line =~ ^[Ii]nclude[[:space:]]+(.*) ]] && (( $#match > 0 )); then
      local include_path="${match[1]}"
      # Expand paths starting with ~
      if [[ $include_path == ~* ]]; then
        local expanded_include_path=${include_path/#\~/$HOME}
      else
        # Default to ~/.ssh/ if path is relative
        local expanded_include_path="$HOME/.ssh/$include_path"
      fi
      # Process each included file
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

# Generate list of SSH hosts from config files
# Returns: Formatted list of hosts with details
_ssh_host_list() {
  local ssh_config host_list

  # Get and pre-process SSH config
  ssh_config=$(_parse_config_file $SSH_CONFIG_FILE)
  # Remove comments except for #_desc
  ssh_config=$(echo $ssh_config | command grep -v -E "^\s*#[^_]")

  # Parse SSH config using awk
  host_list=$(echo $ssh_config | command awk '
    # Utility function to join array elements
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

    # Parse single config line into key-value pair
    function parse_line(line) {
      n = split(line, line_array, " ")
      key = line_array[1]
      value = join(line_array, 2, n)
      return key "#-#" value
    }

    # Initialize variables
    BEGIN {
      IGNORECASE = 1
      FS="\n"
      RS=""
      host_list = ""
    }
    
    # Process each host block
    {
      user = " "
      host_name = ""
      alias = ""
      desc = ""
      desc_formated = " "

      # Parse each line in the host block
      for (line_num = 1; line_num <= NF; ++line_num) {
        line = parse_line($line_num)
        split(line, tmp, "#-#")
        key = tolower(tmp[1])
        value = tmp[2]

        # Extract host information
        if (key == "host") { alias = value }
        if (key == "user") { user = value }
        if (key == "hostname") { host_name = value }
        if (key == "#_desc") { desc = value }
      }

      # Format description if available
      if (desc) {
        desc_formated = sprintf("[\033[00;34m%s\033[0m]", desc)
      }

      # Use alias as hostname if not specified
      if (host_name == "") {
        host_name = alias
      }

      # Generate output if we have valid host information
      if (alias && host_name) {
        host = sprintf("%s|->|%s|%s|%s\n", alias, host_name, user, desc_formated)
        host_list = host_list host
      }
    }
    
    # Output the final host list
    END {
      print host_list
    }
  ')

  # Sort and remove duplicates
  echo $host_list | command sort -u
}

# Generate formatted list for FZF display
# Returns: Formatted table with headers
_fzf_list_generator() {
  local header host_list

  # Get host list
  host_list=$(_ssh_host_list)

  # Add table header
  header="
Alias|->|Hostname|User|Desc
─────|──|────────|────|────
"

  # Combine header and host list
  host_list="${header}\n${host_list}"
  # Format as table
  echo $host_list | command column -t -s '|'
}

# Common FZF interface for host selection
# @param $1 Prompt string to display
# Returns: Selected host entry
_fzf_remote_common() {
  local prompt="$1"
  local result selected_host
  
  # Launch FZF with custom configuration
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

# FZF completion handler for SSH and Telnet
# @param $1 Command name
# Returns: Selected host for completion
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

# Modified interactive host selection function with command check
# Returns: None (modifies BUFFER directly)
remote-fzf() {
  # Get current command word
  local cmd=${${(Az)BUFFER}[1]}
  
  # List of commands that should trigger completion
  local valid_commands=(ssh telnet scp sftp rsync)
  
  # Only proceed if current command is in the valid_commands list
  if [[ ${valid_commands[(ie)$cmd]} -le ${#valid_commands} ]]; then
    local result selected_host
    
    # Get host selection
    result=$(_fzf_remote_common "Remote > ")

    if [ -n "$result" ]; then
      # Extract host and prepare command
      selected_host=$(echo "$result" | awk '{print $1}')
      # Preserve the original command
      BUFFER="$cmd $selected_host"
      zle accept-line
    fi
  else
    # If not a valid command, perform default tab completion
    zle complete-word
  fi
  
  # Reset prompt
  zle reset-prompt
}

# Register and bind the widget
zle -N remote-fzf
bindkey '^i' remote-fzf

# vim: set ft=zsh sw=2 ts=2 et