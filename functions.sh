#!/bin/bash

# Set up Cursor notes directory
export CURSOR_NOTES_DIR="$HOME/Developer/CLI/cursor-notes/notes"
[ ! -d "$CURSOR_NOTES_DIR" ] && mkdir -p "$CURSOR_NOTES_DIR"

# Create and open a new note
function new-note() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local title="$*"
    [ -z "$title" ] && read "title?Enter note title: "
    
    local filename="${timestamp}_${title// /_}.md"
    local filepath="$CURSOR_NOTES_DIR/$filename"
    
    echo "# $title" > "$filepath"
    cursor "$filepath"
}

# List recent notes
function list-notes() {
    echo "📝 Recent Cursor notes in $CURSOR_NOTES_DIR:"
    echo "----------------------------------------"
    find "$CURSOR_NOTES_DIR" -type f -name "*.md" -print0 | 
        xargs -0 ls -lt |
        head -n 10 |
        while read -r line; do
            local file=$(echo "$line" | awk '{print $NF}')
            echo "📄 $(basename "$file"): $(head -n 1 "$file" 2>/dev/null || echo 'Empty')"
        done
}

# View note content with different formatting options
function viewnote() {
    local notepath="$CURSOR_NOTES_DIR/$1"
    local mode="$2"
    
    if [[ ! -f "$notepath" ]]; then
        echo "📝 Cannot find note: $1"
        echo "Available notes:"
        ls -1 "$CURSOR_NOTES_DIR"
        return 1
    fi
    
    case "$mode" in
        "raw")
            # Syntax highlighted view with line numbers
            echo "📄 Raw view with syntax highlighting:"
            echo "-----------------------------------"
            sed '/^```/d' "$notepath" | \
                bat --theme="Dracula" \
                    --style=numbers \
                    --language=md
            ;;
        "render"|"")
            # Full markdown rendering
            echo "🎨 Rendered markdown view:"
            echo "----------------------"
            glow -s dark "$notepath"
            ;;
        "clean")
            # Clean text view
            echo "🧹 Clean view (no formatting):"
            echo "--------------------------"
            sed '/^```/d' "$notepath" | cat
            ;;
        *)
            echo "❓ Usage: viewnote <filename> [raw|render|clean]"
            echo "   - raw:    syntax highlighted view"
            echo "   - render: formatted markdown (default)"
            echo "   - clean:  plain text, no formatting"
            ;;
    esac
}

# Search within notes
function search-notes() {
    local term="$2"
    local notepath="$CURSOR_NOTES_DIR/$1"
    local before="${3:-1}"  # default to 1 line before
    local after="${4:-20}"  # default to 20 lines after
    
    if [ -z "$term" ]; then
        read "term?Enter search term: "
    fi
    
    if [[ ! -f "$notepath" ]]; then
        echo "🔍 Searching all notes for: $term"
        grep -l -i "$term" "$CURSOR_NOTES_DIR"/*.md | while read -r file; do
            echo "📄 $(basename "$file"):"
            grep -i -B"$before" -A"$after" "$term" "$file"
            echo "---"
        done
    else
        echo "🔍 Searching in $(basename "$notepath") for: $term"
        grep -i -B"$before" -A"$after" "$term" "$notepath"
    fi
}