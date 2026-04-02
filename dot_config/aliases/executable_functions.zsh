#!/bin/zsh

#================================================#
# Package Management                             #
#================================================#

install_missing() {
    local package="${1:?'Error: package name required'}"
    if command -v brew &>/dev/null; then
        echo "Installing $package..."
        brew install "$package"
    else
        echo "Error: Homebrew not found. Please install Homebrew first."
        echo "Visit https://brew.sh for installation instructions."
        return 1
    fi
}

#================================================#
# File Cleanup                                   #
#================================================#

clean_ds() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: clean_ds [options]"
        echo "Clean .DS_Store files safely using fd and safe-rm."
        echo
        echo "Options:"
        echo "  -h, --help    Show this help message"
        echo "  --all         Clean .DS_Store files across the entire filesystem (requires sudo)"
        return 0
    fi

    if ! command -v fd &>/dev/null; then
        install_missing fd || return 1
    fi

    if ! command -v safe-rm &>/dev/null; then
        install_missing safe-rm || return 1
    fi

    echo "Cleaning .DS_Store files in the current directory..."
    fd -H -I -t f ".DS_Store" . -X safe-rm

    if [[ "$1" == "--all" ]]; then
        echo "Cleaning .DS_Store files across the entire filesystem (requires sudo)..."
        sudo fd -H -I -t f ".DS_Store" / -X safe-rm
        echo "Filesystem-wide cleanup complete."
    else
        echo "Current directory cleanup complete."
    fi
}

#================================================#
# System Operations                              #
#================================================#

portcheck() {
    if [[ -z "$1" ]]; then
        echo "Usage: portcheck <host> [port]"
        return 1
    fi
    nc -zv "$1" "${2:-80}"
}

proxy() {
    case "$1" in
        on)
            export https_proxy=http://127.0.0.1:6152
            export http_proxy=http://127.0.0.1:6152
            export all_proxy=socks5://127.0.0.1:6153
            echo "Proxy enabled"
            ;;
        off)
            unset https_proxy http_proxy all_proxy
            echo "Proxy disabled"
            ;;
        status)
            if [[ -n "$http_proxy" ]]; then
                echo "Proxy is ON ($http_proxy)"
            else
                echo "Proxy is OFF"
            fi
            ;;
        *)
            echo "Usage: proxy [on|off|status]"
            ;;
    esac
}

ip() {
    case "$1" in
        internal)
            # Bypass system proxy, show real ISP exit IP
            curl -s --noproxy '*' ipv4.im/info
            ;;
        external)
            # Force through proxy, show proxy exit IP
            curl -s --proxy http://127.0.0.1:6152 ipv4.im/info
            ;;
        local)
            ifconfig en0 | awk '
                /inet / {
                    mask = $4
                    if (mask ~ /^0x/) {
                        hex = substr(mask, 3)
                        split("", o)
                        for (i = 1; i <= 8; i += 2) {
                            cmd = "printf \"%d\" 0x" substr(hex, i, 2)
                            cmd | getline val
                            close(cmd)
                            o[int((i+1)/2)] = val
                        }
                        mask = o[1]"."o[2]"."o[3]"."o[4]
                    }
                    printf "IP Address : %s\n", $2
                    printf "Subnet     : %s\n", mask
                    printf "Broadcast  : %s\n", $6
                }
                /inet6 / && /fe80/ {
                    split($2, a, "%")
                    printf "IPv6       : %s\n", a[1]
                }
            '
            netstat -rn | awk '/default.*en0/ { printf "Gateway    : %s\n", $2; exit }'
            ;;
        query)
            # Look up info for a specific IP
            curl -s "ip.im/${2:-}"
            ;;
        *)
            echo "Usage: ip [internal|external|local|query <ip>]"
            ;;
    esac
}

#================================================#
# Screen Session Management                      #
#================================================#

# Run a command in a new detached screen window
srun() {
    screen -dm bash -c "$*"
}

# Intelligently attach to a screen session
sattach() {
    if screen -ls | grep -q "[0-9]\..*"; then
        if [[ "$(screen -ls | grep -c "[0-9]\\..*")" -eq 1 ]]; then
            screen -r
        else
            screen -ls
            echo "Multiple sessions exist - please specify one"
        fi
    else
        screen -S "main"
    fi
}

#================================================#
# Chezmoi                                        #
#================================================#

# Full sync workflow
czsync() {
    czg pull && \
    czp && \
    czg add -A && \
    czg commit -m "Auto sync: $(date +%Y-%m-%d_%H:%M:%S)" && \
    czg push || echo "Sync failed - please check the output above"
}