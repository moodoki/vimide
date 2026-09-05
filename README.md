Vimide
======

Personal dotfiles: Vim/Neovim, tmux, bash aliases and a few helper scripts.
Originally derived from haridas/Dotfiles.

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

**The ctags trap.** macOS ships a BSD `ctags` at `/usr/bin/ctags`. It is not
Exuberant/Universal Ctags, tagbar refuses to use it, and because the binary
*exists* nothing obviously fails -- tagbar just never works. Install
`universal-ctags` from Homebrew; `/opt/homebrew/bin` precedes `/usr/bin` on a
default Homebrew PATH, so it shadows Apple's automatically. Verify with:

```sh
ctags --version   # must say "Universal Ctags"
```

Do **not** use the older `ctags` formula (Exuberant 5.8, unmaintained since
2009); it conflicts with `universal-ctags` and both install a `ctags` binary.

**Clipboard.** `tmux.conf` picks a copy backend at load time via `if-shell`
(`pbcopy`, `wl-copy`, or `xclip`) and both copy bindings use it through
`copy-command`, so nothing extra is needed on either platform.
`reattach-to-user-namespace` is *not* required -- it has been unnecessary
since macOS 10.12 / tmux 2.6. Note that tmux runs these through a
non-interactive `sh -c`, so the `pbcopy`/`pbpaste` aliases in `bash_aliases`
are not visible to it; the backend has to be a real executable. On Ubuntu
24.04 (Wayland by default) that means `wl-clipboard`, with `xclip` as the X11
fallback:

```sh
sudo apt install wl-clipboard    # or xclip on an X11 session
```

Check which backend was chosen with:

```sh
tmux show-options -sv copy-command
```

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
| python3-venv | Python virtualenvs |
| python3-venv | Ubuntu ships `venv` separately; `scripts/newMLenv.sh` needs it |

### Older Ubuntu (22.04, 20.04)

Two things the installer carries so old boxes work without extra packages:

- **terminfo.** `tmux.conf` sets `default-terminal "tmux-256color"`. If that
  entry is missing tmux refuses to start at all, so `res/tmux-256color.terminfo`
  is compiled into `~/.terminfo` (per-user, no root) only when `infocmp` cannot
  already find it. On anything current the step reports `ok` and does nothing.
- **Colourscheme.** `zaibatsu` only ships with Vim 8.2+, and 20.04 is on 8.1,
  so `vim/colors/` carries a copy. `~/.vim` precedes `$VIMRUNTIME`, so that copy
  is what loads everywhere -- identical colours on every machine.

Still outstanding on **20.04** specifically (tmux 3.0a):
`set -sa terminal-features` and `set -s copy-command` both need tmux 3.2+, so
copy-mode yanks fall back to the tmux buffer instead of the system clipboard,
and truecolor is not advertised. 22.04 ships tmux 3.2a and is unaffected.

### Optional, per project

ALE runs whichever of these it finds on `PATH`, so install them per project
(in the venv) rather than globally:

```sh
pip install ruff mypy flake8 pylint     # linters
npm install -g pyright                   # language server
```

Plugins
-------

Vim plugins are git submodules under `vim/bundle/`, loaded by
[pathogen](https://github.com/tpope/vim-pathogen) (`vim/autoload/pathogen.vim`).

| Plugin | Purpose |
| --- | --- |
| [ale](https://github.com/dense-analysis/ale) | Async lint / fix / LSP client |
| [nerdtree](https://github.com/preservim/nerdtree) | File tree (`<C-n>`) |
| [nerdcommenter](https://github.com/preservim/nerdcommenter) | Comment toggling |
| [tagbar](https://github.com/preservim/tagbar) | Tag outline (`<leader>l`) — needs universal-ctags |
| [vim-fugitive](https://github.com/tpope/vim-fugitive) | Git |
| [vim-surround](https://github.com/tpope/vim-surround) | Surround text objects |
| [vim-dispatch](https://github.com/tpope/vim-dispatch) | Async `:Make` (`<leader>m`) |
| [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator) | Pane/split navigation |
| [minibufexpl](https://github.com/fholgado/minibufexpl.vim) | Buffer list |
| [rust.vim](https://github.com/rust-lang/rust.vim) | Rust ftplugin |
| [tlib_vim](https://github.com/tomtom/tlib_vim), [vim-addon-mw-utils](https://github.com/MarcWeber/vim-addon-mw-utils) | snipmate dependencies |

`nvim_config/init.vim` simply sources `~/.vimrc`, so Neovim runs the same
plugin set as Vim. There is no Lua/LSP/treesitter config yet.

Updating submodules:

```sh
git submodule sync --recursive     # after any URL change in .gitmodules
git submodule update --init --recursive --remote
```

Help tags for bundled plugins are not generated automatically. Run pathogen's
`:Helptags` once after installing or updating submodules.

Known rough edges
-----------------

- snipmate itself is not installed, only its two dependency bundles.
- `minibufexpl` is unmaintained upstream.
- Session save/restore (`SaveSess`/`RestoreSess` in `vimrc`) writes
  `.session.vim` into the working directory and hard-depends on NERDTree and
  minibufexpl being loaded.
- `scripts/newMLenv.sh` installs unpinned latest versions by design; pin per
  project with a `requirements.txt` or `pyproject.toml` if you need
  reproducibility.
