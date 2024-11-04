# ~/.config/fzf/init.zsh

# ===== 基础设置 =====
# Setup fzf path
if [[ ! "$PATH" == */opt/homebrew/opt/fzf/bin* ]]; then
    PATH="${PATH:+${PATH}:}/opt/homebrew/opt/fzf/bin"
fi

# Load fzf
source <(fzf --zsh)

# ===== 基础命令配置 =====
# 定义要排除的目录和文件
export FZF_IGNORE_DIRS=(
    .m2
    .npm
    .git
    .idea
    .cache
    .vscode
    .gradle
    .DS_Store
    dist
    build
    target
    vendor
    Public
    Library
    Library/Logs
    Applications
    node_modules
    __pycache__
)

# 构建 fd 命令的排除参数
FZF_FD_OPTS=()
for dir in "${FZF_IGNORE_DIRS[@]}"; do
    FZF_FD_OPTS+=(--exclude "$dir")
done

# 设置基础命令
if command -v fd > /dev/null; then
    export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --max-depth 8 ${FZF_FD_OPTS[@]}"
    export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --max-depth 8 ${FZF_FD_OPTS[@]}"
else
    # 构建 rg 的排除参数
    RG_OPTS=()
    for dir in "${FZF_IGNORE_DIRS[@]}"; do
        RG_OPTS+=(--glob "!$dir/*")
    done
    export FZF_DEFAULT_COMMAND="rg --files --hidden --follow ${RG_OPTS[@]}"
fi

# 设置补全触发器为反斜杠
export FZF_COMPLETION_TRIGGER='\'

# ===== 外观和功能配置 =====
export FZF_DEFAULT_OPTS='
    --height=90%
    --layout=reverse
    --border=rounded
    --margin=1
    --padding=1
    --info=inline
    --separator="─"

    --preview "([[ -f {} ]] && (bat --style=numbers,changes --color=always {} || cat {})) || ([[ -d {} ]] && (tree -C {} | less)) || echo {} 2> /dev/null | head -200"
    --preview-window="right:60%:wrap"
    --bind="ctrl-/:toggle-preview"

    --border-label=" 🔍 Fuzzy Finder "
    --border-label-pos=3
    --prompt="  "
    --pointer="▶"
    --marker="✓"

    --bind="ctrl-d:half-page-down"
    --bind="ctrl-u:half-page-up"
    --bind="ctrl-a:select-all"
    --bind="ctrl-y:execute-silent(echo {+} | pbcopy)"
    --bind="ctrl-o:execute-silent(open -R {+})"
    --bind="ctrl-e:execute(code {+})"

    --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
    --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
    --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6
    --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4
    --color=border:#6272a4,label:#6272a4
    
    --header="
╭───────────── Controls ──────────────╮
│ CTRL-R: reload   • CTRL-Y: copy     │
│ CTRL-O: open dir • CTRL-E: vscode   │
╰───────────────────────────────────--╯"
'

# ===== 类型搜索函数 =====
# 按文件类型搜索的函数
fzf_type() {
    case "$1" in
        "code")
            echo "Searching for code files..."
            if command -v fd > /dev/null; then
                fd --type f -e py -e js -e ts -e java -e cpp -e c -e go -e rs -e rb -e php | fzf --multi
            else
                rg --files | grep -i "\.\(py\|js\|ts\|java\|cpp\|c\|go\|rs\|rb\|php\)$" | fzf --multi
            fi
            ;;
        "doc")
            echo "Searching for document files..."
            if command -v fd > /dev/null; then
                fd --type f -e md -e txt -e pdf -e doc -e docx -e xls -e xlsx -e ppt -e pptx | fzf --multi
            else
                rg --files | grep -i "\.\(md\|txt\|pdf\|doc\|docx\|xls\|xlsx\|ppt\|pptx\)$" | fzf --multi
            fi
            ;;
        "config")
            echo "Searching for config files..."
            if command -v fd > /dev/null; then
                fd --type f -e json -e yaml -e yml -e toml -e ini -e conf | fzf --multi
            else
                rg --files | grep -i "\.\(json\|yaml\|yml\|toml\|ini\|conf\)$" | fzf --multi
            fi
            ;;
        "image")
            echo "Searching for image files..."
            if command -v fd > /dev/null; then
                fd --type f -e jpg -e jpeg -e png -e gif -e svg -e webp | fzf --multi
            else
                rg --files | grep -i "\.\(jpg\|jpeg\|png\|gif\|svg\|webp\)$" | fzf --multi
            fi
            ;;
        "video")
            echo "Searching for video files..."
            if command -v fd > /dev/null; then
                fd --type f -e mp4 -e mkv -e avi -e mov -e wmv | fzf --multi
            else
                rg --files | grep -i "\.\(mp4\|mkv\|avi\|mov\|wmv\)$" | fzf --multi
            fi
            ;;
        "audio")
            echo "Searching for audio files..."
            if command -v fd > /dev/null; then
                fd --type f -e mp3 -e wav -e flac -e m4a -e ogg | fzf --multi
            else
                rg --files | grep -i "\.\(mp3\|wav\|flac\|m4a\|ogg\)$" | fzf --multi
            fi
            ;;
        *)
            echo "Usage: fzf_type <type>"
            echo "Available types: code, doc, config, image, video, audio"
            return 1
            ;;
    esac
}

# 按扩展名搜索文件的函数
fzf_ext() {
    if [[ -z "$1" ]]; then
        echo "Usage: fzf_ext <extension>"
        return 1
    fi
    
    echo "Searching for .$1 files..."
    if command -v fd > /dev/null; then
        fd --type f -e "$1" | fzf --multi
    else
        rg --files | grep -i "\.$1$" | fzf --multi
    fi
}

# ===== 类型搜索别名 =====
alias fzc='fzf_type code'     # fzf 搜索代码文件
alias fzd='fzf_type doc'      # fzf 搜索文档文件
alias fzcf='fzf_type config'  # fzf 搜索配置文件
alias fzi='fzf_type image'    # fzf 搜索图片文件
alias fzv='fzf_type video'    # fzf 搜索视频文件
alias fza='fzf_type audio'    # fzf 搜索音频文件

# 清理函数
fzfcleanup() {
    unset FZF_IGNORE_DIRS
    unset FZF_FD_EXCLUDE
    unset FZF_RG_EXCLUDE
}

trap fzfcleanup EXIT