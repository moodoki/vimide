" Disable the python3 remote-plugin provider.
" Neovim probes for a pynvim host the first time a python file is opened,
" which costs ~130ms of startup. pynvim is not installed, so the probe fails
" anyway and has('python3') is 0 either way -- this just skips the search.
" Remove this if you ever `pip install pynvim` and want :python3 plugins
" (vim-virtualenv is the only bundled plugin that uses it).
let g:loaded_python3_provider = 0

set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc
