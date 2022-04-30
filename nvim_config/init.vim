set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc

imap <silent><script><expr> <C-i> copilot#Accept("\<CR>")
let g:copilot_no_tab_map = v:true

