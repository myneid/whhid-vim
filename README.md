# whhid.vim

A Vim9script plugin for [What The Hell Have I Done](https://whatthehellhaveidone.net) — manage your boards, cards, and work logs without leaving Vim.

## Features

- Browse your WHHID board in a sidebar — lists and cards with priority indicators
- Drill into any card to see full details: description, checklists, comments, labels, assignee, due date
- Move cards between columns with a popup picker
- Copy any card as a ready-to-paste AI prompt (works with GitHub Copilot, Claude, ChatGPT, or anything else)
- Board link is per working directory — different projects use different boards
- Token stored once in `~/.vim/whhid.json`, prompted on first use

## Requirements

- Vim 9.0+
- `curl` on your `$PATH`
- A [WHHID](https://whatthehellhaveidone.net) account and API token

## Installation

**vim-plug:**
```vim
Plug 'myneid/whhid-vim'
```

**lazy.vim / packer / any plugin manager:** point it at `myneid/whhid-vim`.

**Vanilla:**
```vim
" in ~/.vimrc
set rtp+=~/.vim/pack/plugins/start/whhid-vim
```
then clone into that path:
```bash
git clone https://github.com/myneid/whhid-vim ~/.vim/pack/plugins/start/whhid-vim
```

## Setup

Run any WHHID command and you'll be prompted for your API token automatically. Or set it explicitly in your `vimrc`:

```vim
let g:whhid_token = 'your-token-here'
```

Get your token from **whhid.com → Settings → API Tokens**.

## Usage

| Command | Description |
|---|---|
| `:WhhidLink` | Link a board to the current working directory |
| `:WhhidOpen` | Open the board sidebar |
| `:WhhidUnlink` | Remove the board link for the current directory |

### Board sidebar keys

| Key | Action |
|---|---|
| `<CR>` | Open card detail popup |
| `m` | Move card to another column |
| `a` | Copy card as AI prompt |
| `r` | Refresh board |
| `q` | Close sidebar |

### Card detail popup keys

| Key | Action |
|---|---|
| `m` | Move card to another column |
| `a` | Copy card as AI prompt |
| `j` / `k` | Scroll |
| `q` / `<Esc>` | Close |

## Configuration

```vim
" API token (prompted on first use if not set)
let g:whhid_token = 'your-token-here'

" MCP server URL (default: https://whatthehellhaveidone.net/mcp/whhid)
let g:whhid_mcp_url = 'https://whatthehellhaveidone.net/mcp/whhid'
```

## License

WTFPL — do what the fuck you want to.
