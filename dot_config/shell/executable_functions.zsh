#!/bin/zsh

# ══════════════════════════════════════════════
# Package Management
# ══════════════════════════════════════════════

# @desc: 通过 Homebrew 安装缺失的软件包 / Install a missing package via Homebrew
# @usage: install_missing <package>
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

# ══════════════════════════════════════════════
# File Cleanup
# ══════════════════════════════════════════════

# @desc: 安全清理 .DS_Store 文件，依赖 fd 和 safe-rm / Clean .DS_Store files safely using fd and safe-rm
# @usage: clean_ds [--current | --all | -h | --help]
clean_ds() {
    if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
        echo "Usage: clean_ds [options]"
        echo "Clean .DS_Store files safely using fd and safe-rm."
        echo
        echo "Options:"
        echo "  -h, --help    Show this help message"
        echo "  --current     Clean .DS_Store files in the current directory"
        echo "  --all         Clean .DS_Store files across the entire filesystem (requires sudo)"
        return 0
    fi
 
    if ! command -v fd &>/dev/null; then
        install_missing fd || return 1
    fi
 
    if ! command -v safe-rm &>/dev/null; then
        install_missing safe-rm || return 1
    fi
 
    if [[ "$1" == "--current" ]]; then
        local files
        files=$(fd -H -I -t f ".DS_Store" .)
        if [[ -z "$files" ]]; then
            echo "No .DS_Store files found in current directory."
            return 0
        fi
        echo "Files to be removed:"
        echo "$files"
        echo
        read "confirm?Clean all of the above? [y/N] "
        [[ "$confirm" =~ ^[Yy]$ ]] || return 0
        echo "$files" | xargs safe-rm 2>&1 | grep -v "^$"
        echo "Done."
 
    elif [[ "$1" == "--all" ]]; then
        local files
        echo "Scanning filesystem (this may take a while)..."
        files=$(sudo fd -H -I -t f ".DS_Store" / 2>/dev/null)
        if [[ -z "$files" ]]; then
            echo "No .DS_Store files found."
            return 0
        fi
        echo "Files to be removed:"
        echo "$files"
        echo
        read "confirm?Clean all of the above? [y/N] "
        [[ "$confirm" =~ ^[Yy]$ ]] || return 0
        echo "$files" | xargs sudo safe-rm 2>&1 | grep -v "^$"
        echo "Done."
 
    else
        echo "Unknown option: $1"
        echo "Run 'clean_ds --help' for usage."
        return 1
    fi
}

# ══════════════════════════════════════════════
# System Operations
# ══════════════════════════════════════════════

# @desc: 检查目标主机的指定端口是否可达 / Check if a host is reachable on a given port using netcat
# @usage: portcheck <host> [port]
portcheck() {
    if [[ -z "$1" ]]; then
        echo "Usage: portcheck <host> [port]"
        return 1
    fi
    nc -zv "$1" "${2:-80}"
}

# @desc: 开启、关闭或查看系统 HTTP/SOCKS 代理状态 / Enable, disable, or check the status of the system HTTP/SOCKS proxy
# @usage: proxy [on | off | status]
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

# @desc: 查看内网、外网或本机 IP 信息，或查询指定 IP 地址 / Display internal, external, or local IP info; or query a specific IP address
# @usage: ip [internal | external | local | query <ip>]
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

# ══════════════════════════════════════════════
# Screen Session Management
# ══════════════════════════════════════════════

# @desc: 在新的后台 screen 会话中运行指定命令 / Run a command in a new detached GNU screen session
# @usage: srun <command>
srun() {
    screen -dm bash -c "$*"
}

# @desc: 智能附加到已有 screen 会话，若不存在则新建名为 main 的会话 / Attach to an existing screen session, or create one named "main" if none exists
# @usage: sattach
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

# ══════════════════════════════════════════════
# Chezmoi
# ══════════════════════════════════════════════

# @desc: 将本地改动提交并推送到远端 / Commit and push local dotfile changes to remote
# @usage: cz-save
cz-save() {
    cz re-add -v && \
    cz git -- add -A && \
    cz git -- commit -m "sync: $(date +%Y-%m-%d_%H:%M:%S)" && \
    cz git -- push origin main || { echo "❌ cz-save failed"; return 1; }
}

# @desc: 拉取远端变更，预览差异后确认应用 / Pull remote changes, preview diff, and apply after confirmation
# @usage: cz-sync
cz-sync() {
    cz git -- pull origin main && \
    cz diff && \
    echo "👆 Review the diff above." && \
    read "?Apply changes? [y/N] " confirm && \
    [[ "$confirm" == [yY] ]] && \
    cz apply -v --exclude encrypted || { echo "❌ Aborted or failed"; return 1; }
}