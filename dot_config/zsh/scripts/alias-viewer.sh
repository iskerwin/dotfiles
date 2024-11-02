#!/usr/bin/env bash

show_aliases() {
    local search_term="$1"
    local temp_file=$(mktemp)
    
    # Create a formatted temporary file
    {
        echo "# Alias Reference Guide"
        echo
        
        # Read the aliases file and process it
        while IFS= read -r line || [ -n "$line" ]; do
            # Skip empty lines or lines starting with #
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            
            # If we find a section comment, print it
            if [[ "$line" =~ ^# ]]; then
                echo
                echo "$line"
                echo
                continue
            fi
            
            # Process and format alias lines
            if [[ "$line" =~ ^alias ]]; then
                # If search term is provided, only show matching lines
                if [[ -n "$search_term" ]] && ! echo "$line" | grep -qi "$search_term"; then
                    continue
                fi
                echo "$line"
            fi
        done < ~/.config/zsh/aliases.zsh
        
    } > "$temp_file"
    
    # Display with bat using specified format
    if command -v bat &> /dev/null; then
        bat --style=plain \
            --theme=TwoDark \
            --language=bash \
            --paging=never \
            "$temp_file"
    else
        cat "$temp_file"
    fi
    
    rm "$temp_file"
}

case "$1" in
    -h|--help)
        echo "Usage: aliases [search_term]"
        echo "Show all aliases with syntax highlighting using bat"
        ;;
    *)
        show_aliases "$1"
        ;;
esac