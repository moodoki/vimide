Vimide
======

Personal dotfiles: Vim/Neovim, tmux, bash aliases and a few helper scripts.
Originally derived from haridas/Dotfiles.

This file covers installation and what is in the box. The two reference docs
have the keys, the settings and the reasoning:

- **[docs/vim.md](docs/vim.md)** -- mappings, plugins, sessions, ALE, and the
  editor half of the agent workflow.
- **[docs/tmux.md](docs/tmux.md)** -- keys, copy mode and the clipboard,
  terminfo, and the `agent-pane` helper.

Install
-------

```sh
git clone --recurse-submodules <this repo>
cd vimide
./createLinks.sh --dry-run    # see what it would do
./createLinks.sh              # do it
```

Supported on macOS and Linux (primary Linux target: Ubuntu 24.04).

The installer is idempotent -- re-run it any time to repair or update links.
It never deletes anything: a real file or directory in the way is moved to a
timestamped `*.bak-YYYYmmddHHMMSS` beside it, and a symlink already pointing
at this repo is left alone (compared by inode, so an equivalent path such as
`~/code` -> `/Volumes/code` still counts as correct).

| Flag | Effect |
| --- | --- |
| `-n`, `--dry-run` | Print what would change; touch nothing |
| `--no-submodules` | Skip `git submodule sync/update` |
| `--no-fonts` | Skip font installation |
| `--no-deps` | Skip the dependency check |
| `-h`, `--help` | Usage |

What it links:

| Target | Link |
| --- | --- |
| `vim/` | `~/.vim` |
| `vimrc` | `~/.vimrc` |
| `nvim_config/` | `$XDG_CONFIG_HOME/nvim` (default `~/.config/nvim`) |
| `bash_aliases` | `~/.bash_aliases` |
| `tmux.conf` | `~/.tmux.conf` |
| `scripts/*` | `~/bin/*` (extension stripped) |

Fonts differ by platform, because the two font systems do:

- **macOS** -- each `.ttf` is linked individually into `~/Library/Fonts`.
  CoreText does not recurse into subdirectories, so a single directory link
  would be silently ignored.
- **Linux** -- one directory link into `$XDG_DATA_HOME/fonts` (or `~/.fonts`
  if that already exists), then `fc-cache -f`. fontconfig does recurse.

The dependency check reports only and installs nothing, printing the right
`brew install` or `sudo apt install` hint per platform. Note that macOS ships
a BSD `ctags` in `/usr/bin` that tagbar cannot use -- the check flags it and
points at `universal-ctags`.

Requirements
------------

`./createLinks.sh` checks all of these and tells you what is missing; it never
installs anything itself. Nothing here is needed merely to open a file -- this
list is what makes every feature in this repo actually work.

### macOS

```sh
brew install universal-ctags neovim tmux uv
```

| Package | Why | Notes |
| --- | --- | --- |
| **universal-ctags** | tagbar (`<leader>l`), and `set tags=./tags;/` | **Required.** See the warning below |
| neovim | `nvim` | Optional; Vim alone is fine |
| tmux | `tmux.conf` | Optional |
| uv | `scripts/newMLenv.sh` | Optional; required by that script |
| git | submodules | Ships with the Xcode command line tools |
| vim | the editor | Apple's `/usr/bin/vim` (9.1) is sufficient |

**The ctags trap.** macOS ships a BSD `ctags` at `/usr/bin/ctags` that tagbar
cannot use, and because the binary *exists* nothing obviously fails -- tagbar
just never works. `ctags --version` must say "Universal Ctags". Full story, and
which Homebrew formula not to install, in
[docs/vim.md](docs/vim.md#the-ctags-trap).

**Clipboard.** Nothing extra is needed on macOS: `tmux.conf` finds `pbcopy` on
its own, and `reattach-to-user-namespace` has been unnecessary since macOS
10.12. On Linux install `wl-clipboard` (Wayland) or `xclip` (X11). See
[docs/tmux.md](docs/tmux.md#clipboard).

Apple's bundled Vim is built `+clipboard +terminal +textprop +popupwin` and
`-python3 -lua`. Nothing here needs the last two, so there is no reason to
`brew install vim` unless you want a newer patch level.

### Ubuntu 24.04

```sh
sudo apt install git vim neovim tmux universal-ctags fontconfig python3-venv wl-clipboard
curl -LsSf https://astral.sh/uv/install.sh | sh   # uv is not in the 24.04 archive
```

| Package | Why |
| --- | --- |
| vim | install the full `vim`, not `vim-tiny`, which the base image ships |
| universal-ctags | tagbar and tag files |
| fontconfig | `fc-cache`, used by the installer to register the bundled fonts |
| wl-clipboard | tmux copy-mode yanks on a Wayland session; use `xclip` on X11 |
| python3-venv | Ubuntu ships `venv` separately from python3; `scripts/newMLenv.sh` needs it |

### Older Ubuntu (22.04, 20.04)

Two things the installer carries so old boxes work without extra packages:
`res/tmux-256color.terminfo`, compiled into `~/.terminfo` when the system has
no such entry (without it tmux refuses to start at all), and a copy of the
`zaibatsu` colourscheme, which only ships with Vim 8.2+ while 20.04 is on 8.1.
Both are no-ops on a current machine.

What is still degraded on **20.04** (tmux 3.0a) is listed in
[docs/tmux.md](docs/tmux.md#terminal-and-colour): no truecolor advertisement,
and copy-mode yanks land in the tmux buffer rather than the system clipboard.
22.04 ships tmux 3.2a and is unaffected.

### Optional, per project

ALE runs whichever linters and language servers it finds on `PATH` -- install
them in the project's venv rather than globally; see
[docs/vim.md](docs/vim.md#ale).

What is configured
------------------

**Vim and Neovim** -- `,` is the leader. Escapes are `jjj`/`kkk`, `;` is `:`,
searches are very-magic, `C-h/j/k/l` crosses vim splits and tmux panes alike.
Twelve plugins live in `vim/bundle/` as submodules, loaded by pathogen: ALE,
NERDTree, tagbar, fugitive, surround, dispatch, vsnip for snippets (`<Tab>`),
and friends. `nvim_config/`
sources `~/.vimrc`, so **Neovim runs the same config and the same plugins**;
there is no Lua/LSP/treesitter setup. Sessions are opt-in per directory
(`:SaveSess`). All of it, key by key, in **[docs/vim.md](docs/vim.md)**.

**tmux** -- prefix is `C-a`, panes and windows number from 1, mouse on,
vi copy mode with the system clipboard wired up per platform, and pane
navigation shared with vim. **[docs/tmux.md](docs/tmux.md)**.

**A coding agent in another pane** -- vim in one pane, Claude Code (or
whatever you run) in another, on the same working tree. The editor keeps itself
in sync with what the agent writes, and `,af` / `,al` / `,ay` / `,ae` hand it
file, line, code and diagnostic references; `prefix a` / `A` / `P` and `Y` in
copy mode do the same from tmux, and `scripts/agent-pane.sh` does it from a
shell pipeline. Split across
[docs/vim.md](docs/vim.md#coding-agent) and
[docs/tmux.md](docs/tmux.md#coding-agent-in-another-pane).

**Scripts** -- `scripts/*` is linked into `~/bin` with the extension stripped.
`newMLenv` builds a uv-based Python venv with a PyTorch and scientific stack
(`newMLenv --help`); `agent-pane` is the agent helper above. `bash_aliases`
adds venv activation with completion (`activate`), `ta` to attach to tmux,
`s`/`sa` ssh helpers, and a `pbcopy`/`pbpaste` shim on Linux.

Updating submodules:

```sh
git submodule sync --recursive     # after any URL change in .gitmodules
git submodule update --init --recursive --remote
```

Help tags for bundled plugins are not generated automatically. Run pathogen's
`:Helptags` once after installing or updating submodules.

Known rough edges
-----------------

- `minibufexpl` is unmaintained upstream.
- Session save/restore (`SaveSess`/`RestoreSess` in `vimrc`) writes
  `.session.vim` into the working directory and hard-depends on NERDTree and
  minibufexpl being loaded.
- `scripts/newMLenv.sh` installs unpinned latest versions by design; pin per
  project with a `requirements.txt` or `pyproject.toml` if you need
  reproducibility.
- `agent-pane` builds file references relative to the git root, so they only
  resolve if the agent's own working directory is that root. Start it from
  there (`prefix a` inherits the calling pane's directory).
- `updatetime=1000` is what makes `:checktime` fire while you sit still; it
  also means a swapfile write at that rate on an idle buffer.
- The tmux bindings call `~/bin/agent-pane` by path, so they do nothing until
  `./createLinks.sh` has linked it.
