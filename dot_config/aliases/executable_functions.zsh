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
    # Help information
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: clean_ds [options]"
        echo "Clean .DS_Store files safely using fd and safe-rm."
        echo 
        echo "Options:"
        echo "  -h, --help    Show this help message"
        echo "  --all         Clean .DS_Store files across the entire filesystem (requires sudo)"
        return 0
    fi

    # Verify installation of fd and safe-rm tools.
    if ! command -v fd &>/dev/null; then
        echo "Error: 'fd' is not installed. Please install 'fd' to use this script."
        return 1
    fi

    if ! command -v safe-rm &>/dev/null; then
        echo "Error: 'safe-rm' is not installed. Please install 'safe-rm' to use this script."
        return 1
    fi

    # Clean up the .DS_Store files in the current directory
    echo "Using fd to clean .DS_Store files in the current directory..."
    fd -H -I -t f ".DS_Store" . -X safe-rm

    # If the --all parameter is specified, clean up the entire disk
    if [[ "$1" == "--all" ]]; then
        echo "Cleaning .DS_Store files across the entire filesystem. This requires sudo..."
        sudo fd -H -I -t f ".DS_Store" / -X safe-rm
        echo ".DS_Store file cleanup complete for the entire filesystem."
    else
        echo "Current directory cleanup complete."
    fi
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
