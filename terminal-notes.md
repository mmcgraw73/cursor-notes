# Cursor Notes CLI Documentation

A set of command-line tools for managing markdown notes in `~/Developer/CLI/cursor-notes/`.

## Commands

### Create New Note
```bash
note "Title of Note"    # Creates and opens a new note with timestamp
new-note "Title"        # Alternative command
```
- Creates a markdown file with format: `YYYYMMDD_HHMMSS_title.md`
- Opens the new file in Cursor
- If no title provided, prompts for one

### List Notes
```bash
notes           # Lists recent notes
list-notes      # Alternative command
```
- Shows 10 most recent notes
- Displays filename and first line of each note

### Open Note
```bash
open-note       # Interactive note selector
```
- Shows numbered list of available notes
- Select note by number to open in Cursor

### View Note Content
```bash
viewnote filename.md    # View entire note
vn filename.md         # Shorthand alias
```
- Displays content of specified note
- Shows available notes if file not found

### Search Notes
```bash
searchnote filename.md "search term" [before] [after]
sn filename.md "search term"
```
- Searches within specified note
- Optional context lines:
  - `before`: lines before match (default: 1)
  - `after`: lines after match (default: 20)

## Directory Structure
```bash
$CURSOR_NOTES_DIR = ~/Developer/CLI/cursor-notes/
```

## File Format
```
# Title of Note
Content goes here...
```

## Examples
```bash
# Create new note
note "Meeting Minutes"

# List recent notes
notes

# View specific note
vn meeting.md

# Search in note with context
sn meeting.md "Action Items" 2 5
```
