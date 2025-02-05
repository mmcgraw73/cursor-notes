# Cursor Notes CLI Documentation

A set of command-line tools for managing markdown notes in `~/Developer/CLI/cursor-notes/`.

## Commands

### Create New Note
Create and open a new timestamped note:
```bash
note "Title of Note"     # Creates and opens a new note
new-note "Title"        # Alternative command
```

### List Notes
View your recent notes:
```bash
notes                   # Lists recent notes
list-notes             # Alternative command
```

### Open Note
Select and open notes interactively:
```bash
open-note              # Interactive note selector
```

### View Note Content
Display note contents with different formatting:
```bash
viewnote filename.md   # View entire note
vn filename.md        # Shorthand alias
vnr filename.md       # Raw view with syntax highlighting
vnm filename.md       # Rendered markdown view
vnc filename.md       # Clean view (no formatting)
```

### Search Notes
Search within notes with context:
```bash
searchnote filename.md "search term" [before] [after]
sn filename.md "search term"
```

**Context Options:**
- `before`: Number of lines before match (default: 1)
- `after`: Number of lines after match (default: 20)

## Directory Structure
Notes are stored in:
```bash
$CURSOR_NOTES_DIR = ~/Developer/CLI/cursor-notes/
```

## File Format
Standard markdown format:
```markdown
# Title of Note
Content goes here...
```

## Examples
Common usage patterns:
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