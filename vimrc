" ========== Vim Basic Settings ============="

syntax on
set shm=

" Pathogen settings.
filetype off
call pathogen#infect()
filetype plugin indent on

" Make vim incompatbile to vi.
set nocompatible
set modelines=0

"TAB settings.
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab

" More Common Settings.
set encoding=utf-8
set scrolloff=3
set autoindent
set showmode
set showcmd
set hidden
set wildmenu
set wildmode=list:longest
set visualbell
set clipboard+=unnamed "Yanks gos to clipboard"

"set cursorline
set ttyfast
set ruler
set backspace=indent,eol,start
set laststatus=2

"set relativenumber
set number
silent! set norelativenumber

"set undofile
set shell=bash
set lazyredraw
set matchtime=3

" How long to wait for a multi-key mapping to complete. Affects the leader
" sequences, the jjj/kkk escapes, and how quickly a bare "," falls through to
" its built-in find-repeat. 500ms is still comfortable for deliberate
" sequences while halving both of those waits.
set timeoutlen=500

" Key codes get their own, much shorter timeout. Without this Vim leaves
" 'ttimeout' off and 'ttimeoutlen' at -1, so the value above also decides how
" long a bare <Esc> waits to prove it is not the start of an escape sequence
" (<Esc>[A from an arrow key, say) -- which is what makes <Esc> feel sluggish.
" Neovim already defaults to these; setting them keeps the two consistent.
" Pairs with `escape-time 10` in tmux.conf, which fixes the same latency one
" layer down.
set ttimeout
set ttimeoutlen=50

"Changing Leader Key
let mapleader = ","

" Set title to window
set title

" Dictionary path, from which the words are being looked up.
set dictionary=/usr/share/dict/words

" Make pasting done without any indentation break."
" This option is not required in neovim
if !has('nvim')
    set pastetoggle=<F3>
endif


" Yank to a file, for copy/paste between vim sessions. Kept deliberately even
" though 'clipboard' is set: on a machine with no system clipboard (a plain
" ssh session, a headless box) this is the only thing that works.
vnoremap <C-y> :w! ~/.vimbuffer<CR>
nnoremap <C-y> :.w! ~/.vimbuffer<CR>
noremap <C-p> :r ~/.vimbuffer<CR>

" Make Vim able to edit corntab fiels again.
set backupskip=/tmp/*,/private/tmp/*

" Enable Mouse
set mouse=a
set mousehide

"Settings for Searching and Moving
nnoremap / /\v
vnoremap / /\v
set ignorecase
set smartcase
" No 'gdefault': it inverts the meaning of the /g flag, so every :s command
" from documentation, a colleague or a plugin does the opposite of what it says.
set incsearch
set showmatch
set hlsearch
nnoremap <leader><space> :noh<cr>
" <Tab> is not mapped to %: in a terminal <Tab> and <C-i> are the same keycode,
" so mapping it silently disables <C-i> (jump forward in the jumplist), leaving
" <C-o> working and no way back. % is already one keystroke.


" Make Vim to handle long lines nicely.
set wrap
set textwidth=99
set formatoptions=qrn1
silent! set colorcolumn=79,99
" zaibatsu only ships with Vim 8.2 and later, so vim/colors/ carries a copy for
" older boxes (Ubuntu 20.04 is on 8.1). ~/.vim precedes $VIMRUNTIME on the
" runtimepath, so that copy is the one used everywhere -- same colours on every
" machine. silent! so a missing scheme leaves the default rather than erroring.
silent! colorscheme zaibatsu
highlight ColorColumn ctermbg=darkgrey guibg=darkgrey
set linebreak

" To  show special characters in Vim
"set list
set listchars=tab:▸\ ,eol:¬

" Naviagations using keys up/down/left/right
" Disabling default keys to learn the hjkl
"nnoremap <up> <nop>
"nnoremap <down> <nop>
"nnoremap <left> <nop>
"nnoremap <right> <nop>
"inoremap <up> <nop>
"inoremap <down> <nop>
"inoremap <left> <nop>
"inoremap <right> <nop>
nnoremap j gj
nnoremap k gk

" Right-hand-only escape from insert mode. Three repeats rather than two:
" "jj" and "kk" both occur in real words (kk in 73 of /usr/share/dict/words,
" "bookkeeper" among them), while "jjj" and "kkk" occur in none. Plain <Esc>,
" with no trailing motion -- the old mappings also moved the cursor a line.
inoremap jjj <Esc>
inoremap kkk <Esc>

" Get Rid of stupid Goddamned help keys
inoremap <F1> <ESC>
nnoremap <F1> <ESC>
vnoremap <F1> <ESC>

" Map : to ; also in command mode.
nnoremap ; :

" Set vim to save the file on focus out.
au FocusLost * :wa

" Adding More Shorcuts keys using leader key.
" Leader Key provide separate namespace for specific commands.
",W Command to remove white space from a file.
nnoremap <leader>W :%s/\s\+$//<cr>:let @/=''<CR>

" ,ft Fold tag, helpful for HTML editing.
nnoremap <leader>ft vatzf

" ,q Re-hardwrap Paragraph
nnoremap <leader>q gqip

" ,v Select just pasted text.
nnoremap <leader>v V`]

" ,ev Shortcut to edit .vimrc file on the fly on a vertical window.
nnoremap <leader>ev <C-w><C-v><C-l>:e $MYVIMRC<cr>

" ,mm to run Make
nnoremap <leader>m :w<cr>:Make<cr>


" Working with split screen nicely
" Resize Split When the window is resized"
au VimResized * :wincmd =


" Wildmenu completion "
set wildmenu
set wildmode=list:longest
set wildignore+=.hg,.git,.svn " Version Controls"
set wildignore+=*.aux,*.out,*.toc "Latex Indermediate files"
set wildignore+=*.jpg,*.bmp,*.gif,*.png,*.jpeg "Binary Imgs"
set wildignore+=*.o,*.obj,*.exe,*.dll,*.manifest "Compiled Object files"
set wildignore+=*.spl "Compiled speolling world list"
set wildignore+=*.sw? "Vim swap files"
set wildignore+=*.DS_Store "OSX SHIT"
set wildignore+=*.luac "Lua byte code"
set wildignore+=migrations "Django migrations"
set wildignore+=*.pyc "Python Object codes"
set wildignore+=*.orig "Merge resolution files"

" Make Sure that Vim returns to the same line when we reopen a file"
augroup line_return
    au!
    au BufReadPost *
        \ if line("'\"") > 0 && line("'\"") <= line("$") |
        \ execute 'normal! g`"zvzz' |
        \ endif
augroup END

nnoremap g; g;zz

" Movement between windows is provided by vim-tmux-navigator, which maps
" <C-h/j/k/l> to :TmuxNavigate* and crosses seamlessly into tmux panes.
" Plugins load after this file, so plain `nnoremap <c-j> <c-w>j` here would be
" silently overridden -- set g:tmux_navigator_no_mappings=1 to take them back.

" =========== END Basic Vim Settings ===========
"
" =========== Custom Functions ==========

" Buffer Swapping

function! MarkWindowSwap()
    let g:markedWinNum = winnr()
endfunction

function! DoWindowSwap()
    "Mark destination
    let curNum = winnr()
    let curBuf = bufnr( "%" )
    exe g:markedWinNum . "wincmd w"
    "Switch to source and shuffle dest->source
    let markedBuf = bufnr( "%" )
    "Hide and open so that we aren't prompted and keep history
    exe 'hide buf' curBuf
    "Switch to dest and shuffle source->dest
    exe curNum . "wincmd w"
    "Hide and open so that we aren't prompted and keep history
    exe 'hide buf' markedBuf 
endfunction

nmap <silent> <leader>mw :call MarkWindowSwap()<CR>
nmap <silent> <leader>pw :call DoWindowSwap()<CR>

" End buffer swapping 


" =========== Gvim Settings =============

" Removing scrollbars
if has("gui_running")
    set guitablabel=%-0.12t%M
    set guioptions-=T
    set guioptions-=r
    set guioptions-=L
    set guioptions+=a
    set guioptions+=m
    colo badwolf
    set listchars=tab:▸\ ,eol:¬         " Invisibles using the Textmate style
endif

" Source the vimrc file after saving it
"autocmd bufwritepost .vimrc source ~/.vimrc

" ========== END Gvim Settings ==========


" ========== Plugin Settings =========="
"
" Mapping to NERDTree
nnoremap <C-n> :NERDTreeToggle<cr>

" Mini Buffer some settigns."
let g:miniBufExplMapWindowNavVim = 1
let g:miniBufExplMapWindowNavArrows = 1
let g:miniBufExplMapCTabSwitchBufs = 1
let g:miniBufExplModSelTarget = 1

" Tagbar key bindings."
nmap <leader>l <ESC>:TagbarToggle<cr>
imap <leader>l <ESC>:TagbarToggle<cr>i

" ALE settings
" Prefix pyright/pylsp/jedils with PATH and VIRTUAL_ENV from a project-local
" venv, found by walking up from the buffer for a directory named one of
" g:ale_virtualenv_dir_names (.venv, env, ve, venv, virtualenv, .env).
" Centrally-managed venvs under ~/.venvs are not found this way -- activate
" those in the shell before launching, as the `activate` alias does.
let g:ale_python_auto_virtualenv = v:true


" vim-latex settings
let g:tex_flavor='latex'


" =========== END Plugin Settings =========="
"
" =========== Other Settings ==============="

" Lilypond formats
if isdirectory("/usr/share/lilypond/2.14.2/vim")
    filetype off
    set runtimepath+=/usr/share/lilypond/2.14.2/vim
    filetype on
endif

" Auto load ctags if present
set tags=./tags;/

" ---- Session save / restore ----------------------------------------------
" Opt-in per directory: a directory only gets a session once you run :SaveSess
" there. After that, starting vim in it with no file arguments restores the
" session, and quitting re-saves it.

let g:savesession = get(g:, 'savesession', 0)

" The default includes 'options', which bakes every option and mapping into
" the session file -- the usual reason a restored session behaves unlike a
" fresh vim. 'terminal' is dropped too; restoring terminal buffers is rarely
" what you want.
set sessionoptions=buffers,curdir,folds,help,tabpages,winsize

" Fixed at startup so VimLeave still writes to the directory vim was launched
" in, even if the session or an autocmd changed the working directory.
let s:session_file = getcwd() . '/.session.vim'

" Sidebars are excluded from the session and reopened afterwards, so the
" session stores real windows only. Guarded: the config still loads if the
" plugins are absent.
function! s:CloseSidebars() abort
    " Note: `silent!` swallows a following bar, so these cannot be written as
    " one-line `if ... | silent! Cmd | endif` -- that raises E171.
    if exists(':NERDTreeClose') == 2
        silent! NERDTreeClose
    endif
    if exists(':MBECloseAll') == 2
        silent! MBECloseAll
    endif
endfunction

function! s:OpenSidebars() abort
    if exists(':MBEOpen') == 2
        silent! MBEOpen
    endif
    if exists(':NERDTree') == 2
        silent! NERDTree
    endif
endfunction

function! SaveSess() abort
    if !g:savesession | return | endif
    call s:CloseSidebars()
    execute 'mksession! ' . fnameescape(s:session_file)
endfunction

function! RestoreSess() abort
    if !filereadable(s:session_file) | return | endif
    execute 'source ' . fnameescape(s:session_file)
    let g:savesession = 1
    call s:OpenSidebars()
endfunction

" A file argument, piped input, or diff mode all mean the user asked for
" something specific -- restoring over it would discard what they asked for.
" Global, and taking the timer id, so it can be handed to timer_start() as a
" plain Funcref. A {-> s:Fn()} lambda does not resolve its script-local
" reference from inside an autocmd, and fails silently in the timer.
function! MaybeRestoreSess(...) abort
    if argc() != 0 || exists('s:read_stdin') || &diff
        return
    endif
    call RestoreSess()
endfunction

augroup vimide_session
    autocmd!
    autocmd StdinReadPre * let s:read_stdin = 1
    " Deferred by a zero-delay timer so it runs after every plugin's own
    " VimEnter handler. NERDTree's netrw hijack rearranges windows at VimEnter
    " and, running after ours, used to silently undo the whole restore.
    autocmd VimEnter * ++nested call timer_start(0, function('MaybeRestoreSess'))
    autocmd VimLeave * call SaveSess()
augroup END

function! s:EnableAndSave() abort
    let g:savesession = 1
    call SaveSess()
endfunction

" :SaveSess turns auto-saving on and writes the session immediately.
" :NoSaveSess stops auto-saving; delete .session.vim to stop restoring.
command! SaveSess   call s:EnableAndSave()
command! NoSaveSess let g:savesession = 0

