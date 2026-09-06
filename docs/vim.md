Vim and Neovim
==============

What `vimrc`, `vim/` and `nvim_config/` actually set up, and how to use it.
See [tmux.md](tmux.md) for the pane side, and the [README](../README.md) for
installation.

Layout
------

| Path | What it is |
| --- | --- |
| `vimrc` | everything: settings, mappings, session save/restore. Linked to `~/.vimrc` |
| `vim/` | the runtime directory, linked to `~/.vim` |
| `vim/bundle/` | plugins, as git submodules, loaded by pathogen |
| `vim/autoload/pathogen.vim` | the loader itself, vendored rather than submoduled |
| `vim/plugin/` | our own plugins: `agent.vim`, `grep-operator.vim` |
| `vim/colors/` | colourschemes, including a carried copy of `zaibatsu` |
| `vim/syntax/`, `vim/indent/`, `vim/spell/` | C++11 syntax, Python indent, a personal spellfile |
| `nvim_config/` | Neovim's config, linked to `~/.config/nvim` |

`nvim_config/init.vim` puts `~/.vim` on the runtimepath and sources `~/.vimrc`,
so **Neovim runs the same config and the same plugins as Vim**. There is no
Lua, LSP or treesitter setup; ALE is the language-server client for both.
`nvim_config/ginit.vim` handles GUI fonts (`:Hdpi` / `:Ldpi`).

The leader key is `,`.

Mappings
--------

### Editing

| Key | Does |
| --- | --- |
| `jjj`, `kkk` | leave insert mode. Three repeats, because `jj` and `kk` occur in real words (`bookkeeper`) and `jjj`/`kkk` occur in none |
| `F1` | also escape, in every mode -- the help key is a trap |
| `F3` | `pastetoggle` (Vim only; Neovim does not need it) |
| `;` | `:`, so commands need no shift |
| `,W` | strip trailing whitespace from the file |
| `,q` | re-hardwrap the current paragraph |
| `,v` | reselect the text you just pasted |
| `,ft` | fold the current HTML tag |
| `j`, `k` | move by *screen* line, so wrapped lines behave |
| `<Tab>` | expand the snippet under the cursor, or jump to the next placeholder. Falls through to a real Tab when there is neither (insert and select mode only) |
| `<S-Tab>` | jump to the previous placeholder |

### Searching

| Key | Does |
| --- | --- |
| `/` | starts a `\v` "very magic" search, so regexes read like everywhere else |
| `,<space>` | clear the search highlight |

Search is `ignorecase` + `smartcase`: lowercase matches anything, a capital
makes it case-sensitive. `gdefault` is deliberately **not** set -- it inverts
the meaning of the `/g` flag, so every `:s` command from documentation or a
colleague would quietly do the opposite of what it says.

`,g`*motion* greps for that text (`,giw`, or over a visual selection) and opens
the quickfix list -- `vim/plugin/grep-operator.vim`.

### Windows and buffers

| Key | Does |
| --- | --- |
| `C-h/j/k/l` | move between splits **and tmux panes**, one keymap for both (vim-tmux-navigator) |
| `,mw` then `,pw` | mark a window, then swap this one with it |
| `C-n` | toggle NERDTree |
| `,l` | toggle the tagbar outline (needs universal-ctags) |
| `,ev` | open `$MYVIMRC` in a vertical split |
| `,m` | write, then `:Make` asynchronously (vim-dispatch) |
| `g;` | jump to the last change, centred |

`C-h/j/k/l` are set by the plugin, not by `vimrc` -- plugins load after it, so
mapping them there would be silently overridden. Set
`g:tmux_navigator_no_mappings = 1` to take them back.

Vim-session yank/paste through a file, for machines with no clipboard at all
(a bare ssh session): `C-y` yanks the line or selection into `~/.vimbuffer`,
`C-p` reads it back. `set clipboard+=unnamed` means ordinary yanks already go
to the system clipboard where there is one.

### Coding agent

The other half of this is in tmux; see
[tmux.md § Coding agent in another pane](tmux.md#coding-agent-in-another-pane)
for the pane keys, the `agent-pane` command and how the target pane is chosen.

The idea: the agent reads files itself, so what it wants from the editor is a
*pointer* -- which file, which lines, which error -- not a wall of pasted code.
These build that pointer, paste it into the agent's pane, and move the cursor
there so you can type the request. Nothing is submitted for you.

| Key | Sends |
| --- | --- |
| `,af` | `@src/foo.py` -- this file |
| `,al` | `@src/foo.py#L42` -- this line. Over a visual selection, `#L42-58` |
| `,as` | `` `symbol` in @src/foo.py#L42 `` -- the identifier under the cursor |
| `,ay`*motion* | that text as a fenced code block with the reference above it (`,ayip`, `,ayaf`, or over a visual selection) |
| `,ae` | this buffer's diagnostics, as the linter states them |
| `,ao` | open the agent pane, or jump to it |
| `,ar` | re-read every buffer that changed on disk |

Commands: `:AgentFile`, `:AgentLines` (takes a range, so `:'<,'>AgentLines` or
`:10,20AgentLines`), `:AgentDiag`, `:AgentOpen`, `:AgentReload`,
`:AgentSend {text}`.

Paths are relative to the git root, so they resolve only if the agent's working
directory is that root. `,ae` uses Neovim's `vim.diagnostic` when there is
something there, otherwise ALE's list.

Options. Plugins load after `vimrc`, so setting these anywhere in `vimrc`
works; the plugin only fills in a default where you have not:

| Variable | Default | Effect |
| --- | --- | --- |
| `g:agent_focus` | `1` | follow the context over to the agent pane |
| `g:agent_enter` | `0` | press Enter after pasting, i.e. actually submit |
| `g:agent_cmd` | `agent-pane` on `PATH`, else `~/bin/agent-pane` | the helper to call |
| `g:agent_no_mappings` | `0` | define the commands but none of the `,a` keys |

Outside tmux there is no pane to paste into, so everything falls back to the
clipboard.

Staying in sync with an agent
-----------------------------

An agent editing the files you have open is the normal case here, so:

- `autoread`, plus `:checktime` on `FocusGained`, `BufEnter` and `CursorHold`
  -- what the agent writes appears in the buffer when you come back to the
  pane, or shortly after your next keystroke. `,ar` forces it.
- `updatetime=1000` is what makes the `CursorHold` half fire while you sit
  still. The cost is a swapfile write at that rate on an idle buffer.
- `au FocusLost * silent! wall` -- what you were typing is on disk before the
  agent reads it, even if you were mid-insert when you switched panes.
- Change the same file in both places and Vim asks rather than picking a
  winner (`:help W11`).

**The part that is easy to miss.** All of the focus half needs Vim to actually
ask the terminal to report focus, and Vim only asks when it believes the
terminal supports it -- which it does not believe of `term=tmux-256color`.
`t_fe` and `t_fd` come out empty, no request is sent, and
`FocusLost`/`FocusGained` never fire no matter what tmux is willing to send.
The vimrc sets those two termcap entries by hand under a `tmux`/`screen` TERM.
tmux's side of the deal is `focus-events on`. Neovim asks for itself and needs
none of this.

To check it is working: `:au FocusGained` should list the `checktime`
autocommand, and

```vim
:echo strtrans(&t_fe)
```

should print `^[[?1004h`, not nothing.

Settings worth knowing
----------------------

| Setting | Why |
| --- | --- |
| `timeoutlen=500` | how long a leader sequence waits. Halves the pause after a bare `,` |
| `ttimeout` + `ttimeoutlen=50` | key *codes* get their own, much shorter timeout. Without this, `timeoutlen` also decides how long a bare `<Esc>` waits to prove it is not an arrow key -- the usual cause of "Esc feels laggy". Pairs with `escape-time 10` in tmux |
| `textwidth=99`, `colorcolumn=79,99` | wrap at 99, with both the old and the new limit marked |
| `clipboard+=unnamed` | yanks go to the system clipboard |
| `hidden` | switch away from a modified buffer without writing it |
| `tags=./tags;/` | pick up a `tags` file from the file's directory upwards |
| `sessionoptions` | see below |
| `colorscheme zaibatsu` | carried in `vim/colors/` because it only ships with Vim 8.2+, and Ubuntu 20.04 is on 8.1. `~/.vim` precedes `$VIMRUNTIME`, so the carried copy is what loads everywhere -- identical colours on every machine |

Plugins
-------

Git submodules under `vim/bundle/`, loaded by
[pathogen](https://github.com/tpope/vim-pathogen).

| Plugin | Purpose |
| --- | --- |
| [ale](https://github.com/dense-analysis/ale) | async lint / fix / LSP client |
| [nerdtree](https://github.com/preservim/nerdtree) | file tree (`C-n`) |
| [nerdcommenter](https://github.com/preservim/nerdcommenter) | comment toggling |
| [tagbar](https://github.com/preservim/tagbar) | tag outline (`,l`) -- needs universal-ctags |
| [vim-fugitive](https://github.com/tpope/vim-fugitive) | git |
| [vim-surround](https://github.com/tpope/vim-surround) | surround text objects |
| [vim-dispatch](https://github.com/tpope/vim-dispatch) | async `:Make` (`,m`) |
| [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator) | pane/split navigation |
| [minibufexpl](https://github.com/fholgado/minibufexpl.vim) | buffer list |
| [rust.vim](https://github.com/rust-lang/rust.vim) | Rust ftplugin |
| [vim-vsnip](https://github.com/hrsh7th/vim-vsnip) | snippet engine (`<Tab>`) -- see below |
| [friendly-snippets](https://github.com/rafamadriz/friendly-snippets) | the snippet library vsnip reads |

Updating them:

```sh
git submodule sync --recursive     # after any URL change in .gitmodules
git submodule update --init --recursive --remote
```

Help tags are not generated automatically -- run pathogen's `:Helptags` once
after installing or updating.

### ALE

`g:ale_python_auto_virtualenv` is on, so pyright/pylsp/jedi get `PATH` and
`VIRTUAL_ENV` from a project-local venv found by walking up from the buffer
(`.venv`, `env`, `ve`, `venv`, `virtualenv`, `.env`). A centrally-managed venv
under `~/.venvs` is **not** found that way -- activate it in the shell before
launching vim, as the `activate` alias does.

Linters are whatever is on `PATH`, so install them per project rather than
globally:

```sh
pip install ruff mypy flake8 pylint     # linters
npm install -g pyright                   # language server
```

Snippets
--------

[vim-vsnip](https://github.com/hrsh7th/vim-vsnip) is the engine and
[friendly-snippets](https://github.com/rafamadriz/friendly-snippets) is the
library. Type a prefix and press `<Tab>`:

```
def<Tab>    ->    def fname():
                      pass
```

`<Tab>` then jumps forward through the placeholders and `<S-Tab>` back.
`<Tab>` falls through to a real tab when there is nothing to expand or jump to,
so it costs you nothing when you are not using it. Normal-mode `<Tab>` is
deliberately untouched -- in a terminal it is the same keycode as `<C-i>`, and
mapping it would silently cost you the jumplist.

friendly-snippets needs no configuration: vsnip scans the runtimepath for a
`package.json` declaring `contributes.snippets`, and pathogen has already put
`vim/bundle/friendly-snippets` there.

### Your own snippets

They live in **`vim/vsnip/`** in this repo, because `~/.vim` *is* that
directory -- so they are versioned along with everything else instead of being
stranded in `~/.vsnip` on one machine.

| Command | Does |
| --- | --- |
| `:VsnipOpen` | edit the snippet file for this buffer's filetype (creates it on first use) |
| `:VsnipOpenEdit`, `:VsnipOpenSplit` | the same, in this window or a horizontal split |
| `:VsnipYank` | yank the selected lines as a ready-made snippet definition, to paste into that file |

The format is VSCode/LSP JSON (`python.json`, `rust.json`, ...). vsnip also
reads SnipMate-format `.snippets` files in the same directory, so old snippets
are not wasted, though compatibility is not complete.

### What it does not do

vsnip's companion, `vim-vsnip-integ`, wires snippet expansion into a
completion engine or LSP client, and **ALE is not on its supported list**. So
snippets expand from a prefix you type, not from accepting an ALE completion
item that happens to be a snippet. Nothing is broken by this; it is simply a
seam between the two plugins. `set complete+=Fvsnip#completefunc` puts snippets
into built-in `<C-n>` completion if you want them there, but the `F` flag needs
Vim 8.2, so it is not set here -- 20.04 is on 8.1.

### Why vsnip, and not the others

Checked 2026-09-06; maintenance status ages, so re-check before revisiting.

| Candidate | Last commit | Verdict |
| --- | --- | --- |
| [UltiSnips](https://github.com/SirVer/ultisnips) | 2026-07-04 | the most actively maintained, and **rejected**: it needs `+python3` |
| [LuaSnip](https://github.com/L3MON4D3/LuaSnip) | 2026-05-19 | actively maintained, Neovim-only |
| **[vim-vsnip](https://github.com/hrsh7th/vim-vsnip)** | 2025-10-05 | **chosen** |
| [vim-snipmate](https://github.com/garbas/vim-snipmate) | 2025-05-14 | works, but see below |

The constraint that decides it is `+python3`, which is not evenly available:

| | `+python3`? |
| --- | --- |
| macOS `/usr/bin/vim` (Apple's, 9.1) | no |
| Ubuntu 24.04 `vim` package | yes (links `libpython3.12t64`) |
| Ubuntu 22.04 `vim` package | yes (links `libpython3.10`) |
| Ubuntu 20.04 `vim` package | no |

UltiSnips would therefore work on the current Ubuntu boxes and fail on a Mac
and on 20.04. Adopting it means `brew install vim` stops being optional and
becomes a hard requirement on every Mac -- which contradicts the README's
position that Apple's bundled Vim is sufficient. LuaSnip would mean Neovim and
Vim no longer share a config, which is the one thing `nvim_config/init.vim`
exists to prevent.

That leaves vsnip and snipmate, both pure VimScript. vsnip wins on format: it
speaks the VSCode/LSP snippet dialect, which is what every modern engine and
every language server emits, so the snippets you write stay portable if this
ever moves to LuaSnip or a native LSP setup. SnipMate's format is used by
SnipMate. vsnip also reads that format anyway.

The price, stated plainly: vsnip is **stable rather than actively developed**
-- eleven months since its last commit at time of writing, its author having
moved to the nvim-cmp ecosystem. On the evidence above there is no candidate
that is both actively developed and compatible with this repo's constraints,
and staleness in a pure-VimScript plugin that already works is the cheaper of
the two failure modes.

`tlib_vim` and `vim-addon-mw-utils`, which were here as SnipMate's dependency
bundles without SnipMate itself, were dropped at the same time -- nothing uses
them now.

Sessions
--------

Opt-in per directory. A directory gets a session only once you run `:SaveSess`
there; after that, starting vim in it with no file arguments restores the
session and quitting re-saves it.

| Command | Does |
| --- | --- |
| `:SaveSess` | turn auto-saving on and write `.session.vim` now |
| `:NoSaveSess` | stop auto-saving. Delete `.session.vim` to stop restoring too |

`sessionoptions` deliberately drops `options` -- the default bakes every option
and mapping into the session file, which is the usual reason a restored session
behaves unlike a fresh vim. `terminal` is dropped for the same sort of reason.
NERDTree and minibufexpl are closed before saving and reopened after restoring,
so the session file holds real windows only. A file argument, piped input or
diff mode all suppress the restore.

The ctags trap
--------------

macOS ships a BSD `ctags` at `/usr/bin/ctags`. It is not Exuberant/Universal
Ctags, tagbar refuses to use it, and because the binary *exists* nothing
obviously fails -- tagbar just never works.

```sh
brew install universal-ctags
ctags --version    # must say "Universal Ctags"
```

`/opt/homebrew/bin` precedes `/usr/bin` on a default Homebrew `PATH`, so it
shadows Apple's automatically. Do **not** use the older `ctags` formula
(Exuberant 5.8, unmaintained since 2009); it conflicts with `universal-ctags`
and both install a `ctags` binary. `createLinks.sh` flags all of this.

Troubleshooting
---------------

| Symptom | Cause |
| --- | --- |
| `,l` does nothing | BSD ctags -- see above |
| Buffers do not reload when you come back to the pane | focus reporting; check `:echo strtrans(&t_fe)` and `tmux show -g focus-events` |
| `<Esc>` feels sluggish | `ttimeoutlen` or tmux's `escape-time`, not `timeoutlen` |
| `E117: Unknown function: pathogen#infect` | vim started with `-u vimrc` without `~/.vim` on the runtimepath. Run plain `vim`, or add `--cmd 'set rtp^=~/.vim'` |
| `,a` keys do nothing but the commands work | `g:agent_no_mappings`, or another plugin claimed `,a` |
| `agent: not in tmux, copied to clipboard` | working as intended -- there is no pane to paste into |
