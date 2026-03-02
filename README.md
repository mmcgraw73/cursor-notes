# Cursor Notes

A terminal-first note-taking system for developers — timestamped markdown notes, architecture documentation, and daily task tracking, all managed from the command line and opened in [Cursor](https://cursor.sh/).

![CleanShot 2025-02-05 at 15 52 20@2x](https://github.com/user-attachments/assets/d980fdeb-d165-4f87-8b09-b5a41fb0a798)

---

## What's in here

| Category | Files | Purpose |
|----------|-------|---------|
| **Architecture docs** | `vbms-core-auth-flow.md` | Deep-dive technical references (VBMS auth flow, system traces) |
| **Timestamped notes** | `20260302_*.md`, etc. | Session notes, investigation logs, meeting captures |
| **Daily task lists** | `templates/doingit.md` | "Doing It" lists — 5 items per day + timesheet reminder |
| **Dev reference** | `aliases.md` | Quick-reference for git, npm, and editor commands |
| **CLI toolkit** | `functions.sh` | Shell functions for creating, viewing, and searching notes |
| **Templates** | `templates/` | Reusable note scaffolds (daily dev notes, doing-it lists) |

### Architecture Documentation

The repo doubles as a living knowledge base. Key documents:

- **[vbms-core-auth-flow.md](vbms-core-auth-flow.md)** — End-to-end VBMS Core authentication & authorization trace: Browser → Apache/SiteMinder → Keycloak → IDP Proxy → CSS → SAML → XACML. Every redirect, cookie, token, and transformation across 5 systems and 3 protocols (765 lines).

### Daily Notes (private)

The `mcgraw/` directory holds daily notes and is `.gitignore`d. Structure:

```
mcgraw/
├── daily/          # Daily "doing it" lists
│   ├── 20250206_111354_thursday.md
│   └── ...
└── docs/           # Meeting notes, research
```

---

## Installation

```bash
git clone git@github.com:mmcgraw73/cursor-notes.git
cd cursor-notes
```

Add to your `~/.zshrc`:

```bash
source ~/Developer/CLI/cursor-notes/functions.sh
```

Install dependencies:

```bash
brew install glow bat
```

| Dependency | Purpose |
|------------|---------|
| [glow](https://github.com/charmbracelet/glow) | Rendered markdown in the terminal |
| [bat](https://github.com/sharkdp/bat) | Syntax-highlighted file viewing |
| [Cursor](https://cursor.sh/) | AI-native editor (notes auto-open here) |

---

## Usage

### Create a note

```bash
note "CSAP 403 Investigation"     # Creates timestamped .md, opens in Cursor
```

Creates `20260302_143500_csap-403-investigation.md` and opens it.

### List recent notes

```bash
notes                              # 10 most recent, with first-line preview
```

### View a note

```bash
vn auth-flow.md                    # Rendered markdown (glow)
vnr auth-flow.md                   # Syntax highlighted (bat)
vnc auth-flow.md                   # Clean text (cat)
```

The viewer searches in order: current directory → `mcgraw/daily/` → notes root.

![CleanShot 2025-02-05 at 16 36 56@2x](https://github.com/user-attachments/assets/aeb2ce59-506d-4e4b-bf0a-f17413e0b0df)

### Search notes

```bash
sn auth-flow.md "securityLevel"    # Search within a specific note
sn "" "XACML"                      # Search across all notes
```

Context defaults: 1 line before, 20 lines after. Override:

```bash
sn auth-flow.md "SAML" 3 10       # 3 before, 10 after
```

---

## File naming convention

Notes are auto-named with a timestamp prefix:

```
YYYYMMDD_HHMMSS_slug.md
```

Examples:
- `20260302_083609.md` — daily doing-it list (no slug = quick note)
- `20260226_125635.md` — session note
- `20250617_170136_local-arm-mac_updates.md` — titled investigation

---

## Templates

| Template | Path | Use |
|----------|------|-----|
| **Doing It** | `templates/doingit.md` | 5-item daily task list with timesheet |
| **Daily Dev Notes** | `templates/daily_dev_notes.md` | Focus areas, priorities, DSU prep |

### Doing It template

```markdown
# {{DAY_DATE}}

## DOING IT LIST

- [] 1  
- [] 2
- [] 3
- [] 4
- [] 5 TIMESHEET
```

---

## Directory structure

```
cursor-notes/
├── functions.sh                     # Shell functions (note, notes, vn, sn, etc.)
├── aliases.md                       # Developer command quick reference
├── terminal-notes.md                # CLI documentation
├── vbms-core-auth-flow.md           # Architecture: VBMS auth end-to-end
├── templates/
│   ├── doingit.md                   # Daily task list template
│   └── daily_dev_notes.md           # Daily dev notes template
├── mcgraw/                          # Private daily notes (.gitignored)
│   ├── daily/
│   └── docs/
├── 20260302_*.md                    # Timestamped session notes
├── 20260226_*.md
├── ...
├── LICENSE                          # GNU GPL v3
└── README.md
```

---

## Configuration

```bash
export CURSOR_NOTES_DIR="$HOME/Developer/CLI/cursor-notes"
```

Set in `~/.zshrc`. All functions reference this path for note storage and lookup.

---

## Related

- **[mcgraw-vbms-developer-guides](https://github.com/mcgraw-7/mcgraw-vbms-developer-guides/wiki)** — GitHub Wiki with polished versions of architecture docs from this repo
- **[bip-developer-guides](https://github.com/department-of-veterans-affairs/bip-developer-guides/wiki)** — Team wiki

---

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).

## Author

Michael McGraw
