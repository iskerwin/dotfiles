# ===== FZF 文件类型搜索函数 =====

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

