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
- `scripts/newMLenv.sh` pins nothing and still references `tensorflow-addons`
  (EOL) and the removed `jupyter labextension install` workflow.
