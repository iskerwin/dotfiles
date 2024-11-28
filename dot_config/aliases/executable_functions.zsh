#!/bin/zsh

install_missing() {
    local package="${1:-}"
    if command -v brew &>/dev/null; then
        echo "Installing $package..."
        brew install "$package"
    else
        echo "Error: Homebrew not found. Please install Homebrew first."
        echo "Visit https://brew.sh for installation instructions."
        return 1
    fi
}

clean_ds() {
    # Check the fd command
    if ! command -v fd &>/dev/null; then
        echo "fd command not found. Installing..."
        if command -v brew &>/dev/null; then
            brew install fd
        else
            echo "Error: Homebrew not found. Please install Homebrew first."
            echo "Visit https://brew.sh for installation instructions."
            return 1
        fi
    fi

    # Help info
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: clean_ds [path]"
        echo "Clean .DS_Store files recursively"
        echo
        echo "Options:"
        echo "  path    Specify directory to clean (default: current directory)"
        echo "  -h      Show this help message"
        return 0
    fi

    local target_dir="${1:-.}" # directory specified or default to the current directory

    echo "Cleaning .DS_Store files in ${target_dir}..."
    fd -H -I -t f ".DS_Store" "${target_dir}" --exec rm -f {}
    echo "Clean complete!"
}

#================================================#
# System Operations                              #
#================================================#

portcheck() {
    nc -zv "$1" "${2:-80}"
}

ip() {
    if [ "$1" = "internal" ]; then
        proxy off && curl ipv4.im/info
    elif [ "$1" = "external" ]; then
        proxy on && curl ipv4.im/info && proxy off
    else
        ifconfig en0 | grep inet
    fi
}

ipw() {
    local target="${1:-}"
    if [[ -z "$target" ]]; then
        curl -s ip.im
    else
        curl -s "ip.im/$target"
    fi
}

proxy() {
    if [ "$1" = "on" ]; then
        export https_proxy=http://127.0.0.1:7890 \
            http_proxy=http://127.0.0.1:7890 \
            all_proxy=socks5://127.0.0.1:7890
        echo "Proxy enabled"
    elif [ "$1" = "off" ]; then
        unset https_proxy http_proxy all_proxy
        echo "Proxy disabled"
    else
        echo "Usage: proxy [on|off]"
    fi
}

#================================================#
# Screen Management                              #
#================================================#

# Run command in new screen window
srun() {
    screen -dm bash -c "$@"
}

# An intelligent screen session management tool
sattach() {
    # Check if there are any screen sessions
    if screen -ls | grep -q "[0-9]\..*"; then
        # Check if there is only one session
        if [ "$(screen -ls | grep -c "[0-9]\..*")" -eq 1 ]; then
            # If there is only one session, connect it directly
            screen -r
        else
            # If there are multiple sessions, list all sessions and prompt the user to specify
            screen -ls
            echo "Multiple sessions exist - please specify one"
        fi
    else
        # If you don't have a session, create a new session named "main".
        screen -S "main"
    fi
}

#================================================#
# Chezmoi                                        #
#================================================#

# Full sync workflow
czsync() {
    czg pull
    czp
    czg add -A
    czg commit -m "Auto sync: $(date +%Y-%m-%d_%H:%M:%S)"
    czg push
}
