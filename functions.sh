#!/bin/bash

# Set up Cursor notes directory
export CURSOR_NOTES_DIR="$HOME/Developer/CLI/cursor-notes/notes"
[ ! -d "$CURSOR_NOTES_DIR" ] && mkdir -p "$CURSOR_NOTES_DIR"

# Create and open a new note
function mdview() {
    local input_path="$1"
    local fullpath=""
    
    # Debug - print current locations
    echo "Searching for note: $input_path"
    
    # First try mcgraw/daily with absolute path
    if [[ -f "$CURSOR_NOTES_DIR/mcgraw/daily/$input_path" ]]; then
        fullpath="$CURSOR_NOTES_DIR/mcgraw/daily/$input_path"
        echo "Found in daily notes"
    # Then try the notes directory
    elif [[ -f "$CURSOR_NOTES_DIR/$input_path" ]]; then
        fullpath="$CURSOR_NOTES_DIR/$input_path"
        echo "Found in notes root"
    else
        echo "Cannot find note: $input_path"
        if [[ -d "$CURSOR_NOTES_DIR/mcgraw/daily" ]]; then
            echo "Available notes in mcgraw/daily:"
            /bin/ls -1 "$CURSOR_NOTES_DIR/mcgraw/daily"
        fi
        return 1
    fi
    
    if [[ -f "$fullpath" ]]; then
        if command -v glow &> /dev/null; then
            /opt/homebrew/bin/glow "$fullpath"
        else
            /bin/cat "$fullpath"
        fi
    fi
}

alias mdv='mdview'

alias mdv='mdview'

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
    local input_path="$1"
    local mode="$2"
    local fullpath=""
    
    # Check locations in order
    if [[ -f "$input_path" ]]; then
        fullpath="$input_path"
    elif [[ -f "$CURSOR_NOTES_DIR/mcgraw/daily/$input_path" ]]; then
        fullpath="$CURSOR_NOTES_DIR/mcgraw/daily/$input_path"
    elif [[ -f "$CURSOR_NOTES_DIR/$input_path" ]]; then
        fullpath="$CURSOR_NOTES_DIR/$input_path"
    else
        echo "📝 Cannot find note: $input_path"
        if [[ -d "$CURSOR_NOTES_DIR/mcgraw/daily" ]]; then
            echo "Available notes in mcgraw/daily:"
            /bin/ls -1 "$CURSOR_NOTES_DIR/mcgraw/daily"
        fi
        return 1
    fi
    
    if command -v glow &> /dev/null; then
        /opt/homebrew/bin/glow "$fullpath"
    else
        /bin/cat "$fullpath"
    fi
}

alias mdv='viewnote'

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