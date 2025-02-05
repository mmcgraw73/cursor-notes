# Cursor Notes CLI

A command-line note management system integrated with the Cursor editor. Quickly create, view, search, and manage markdown notes directly from your terminal.

## Features

🚀 **Quick Note Creation**
- Create timestamped notes instantly
- Auto-opens in Cursor editor
- Markdown support by default

📝 **Multiple Viewing Options**
- Rendered markdown preview
- Syntax highlighted view
- Clean text view
- Terminal-friendly formatting

🔍 **Search Capabilities**
- Full-text search within notes
- Configurable context lines
- Quick file navigation

## Installation

1. Clone the repository:
```bash
git clone git@github.com:mmcgraw73/cursor-notes.git
cd cursor-notes
```

2. Add the functions to your `.zshrc`:
```bash
# Source the functions (add to your .zshrc)
source ~/Developer/CLI/cursor-notes/functions.sh
```

3. Install required dependencies:
```bash
brew install glow bat
```

## Usage

### Create Notes
```bash
note "Meeting Notes"          # Create and open new note
```

### View Notes
```bash
notes                        # List recent notes
vn meeting.md               # View note (default rendered)
vnr meeting.md              # View with syntax highlighting
vnm meeting.md              # View rendered markdown
vnc meeting.md              # View clean text
```

### Search Notes
```bash
sn meeting.md "Action Items" # Search with context
```

## Directory Structure

```
cursor-notes/
├── README.md               # This file
├── functions.sh           # Shell functions
├── LICENSE               # GNU GPL v3
└── notes/                # Your markdown notes
```

## Configuration

Default settings are stored in your `.zshrc`:
```bash
export CURSOR_NOTES_DIR="$HOME/Developer/CLI/cursor-notes"
```

## Dependencies

- [Cursor Editor](https://cursor.sh/)
- [glow](https://github.com/charmbracelet/glow) - Markdown rendering
- [bat](https://github.com/sharkdp/bat) - Syntax highlighting

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Author

Michael McGraw

## Acknowledgments

- Inspired by the need for quick, terminal-based note-taking
- Built for developers who live in the terminal
- Enhanced by the Cursor editor's capabilities
