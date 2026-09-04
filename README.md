Vimide
======

Personal dotfiles: Vim/Neovim, tmux, bash aliases and a few helper scripts.
Originally derived from haridas/Dotfiles.

Install
-------

```sh
git clone --recurse-submodules <this repo>
cd vimide
./createLinks.sh
```

`createLinks.sh` backs up any existing `~/.vimrc`, `~/.vim`, `~/.bash_aliases`
and `~/.gdbinit` to `*.bak`, then symlinks:

| Target | Link |
| --- | --- |
| `vim/` | `~/.vim` |
| `vimrc` | `~/.vimrc` |
| `nvim_config/` | `~/.config/nvim` |
| `bash_aliases` | `~/.bash_aliases` |
| `tmux.conf` | `~/.tmux.conf` |
| `fonts/` | `~/.fonts/vimide_fonts` |
| `scripts/*` | `~/bin/*` |

It is **not** idempotent — re-running it over an existing install will nest
symlinks. Remove the links first if you need to re-run it.

Note: the font step targets `~/.fonts` (fontconfig), which is Linux-only.
On macOS, copy `fonts/**/*.ttf` into `~/Library/Fonts` instead.

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
| [vim-virtualenv](https://github.com/plytophogy/vim-virtualenv) | Python virtualenv switching |
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
- `minibufexpl` and `vim-virtualenv` are both unmaintained upstream.
- Session save/restore (`SaveSess`/`RestoreSess` in `vimrc`) writes
  `.session.vim` into the working directory and hard-depends on NERDTree and
  minibufexpl being loaded.
- `scripts/newMLenv.sh` pins nothing and still references `tensorflow-addons`
  (EOL) and the removed `jupyter labextension install` workflow.
