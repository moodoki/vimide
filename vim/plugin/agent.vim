" agent.vim -- hand context to a coding agent running in another tmux pane.
"
" The agent (Claude Code and friends) reads the files itself, so what it wants
" from the editor is not the code but a *pointer* to it: which file, which
" lines, which error. These mappings build that pointer and paste it into the
" agent's pane, leaving the cursor there so you can type the actual request.
"
" Nothing is ever submitted for you -- add :AgentEnter, or the g:agent_enter
" option, if you disagree.
"
"   <leader>af   this file          -> @path/to/file.py
"   <leader>al   this line          -> @path/to/file.py#L42
"   <leader>al   (visual) selection -> @path/to/file.py#L42-58
"   <leader>as   symbol under cursor and where it is
"   <leader>ay   {motion} as a fenced code block (e.g. <leader>ayip, <leader>ayaf)
"   <leader>ay   (visual) the selection, likewise
"   <leader>ae   this buffer's diagnostics (LSP under nvim, otherwise ALE)
"   <leader>ao   open or focus the agent pane
"   <leader>ar   re-read every buffer changed on disk
"
" All of it degrades outside tmux: the same text goes to the clipboard instead.

if exists('g:loaded_vimide_agent') || &compatible
    finish
endif
let g:loaded_vimide_agent = 1

" ~/bin/agent-pane is where createLinks.sh puts it; PATH wins if it is there.
let g:agent_cmd = get(g:, 'agent_cmd',
    \ exepath('agent-pane') !=# '' ? 'agent-pane' : expand('~/bin/agent-pane'))

" Follow the context over to the agent pane, since the next thing you do is
" almost always type at it. Set to 0 to keep the cursor in vim.
let g:agent_focus = get(g:, 'agent_focus', 1)

" Press Enter after pasting, i.e. submit whatever was sent on its own. Off:
" a bare file reference is not a request, it is the start of one.
let g:agent_enter = get(g:, 'agent_enter', 0)

" ---------------------------------------------------------------- plumbing ---

" The project root, so references are relative to what the agent sees as cwd.
function! s:Root() abort
    let l:dir = expand('%:p:h')
    if l:dir ==# '' | let l:dir = getcwd() | endif
    let l:git = finddir('.git', l:dir . ';')
    if l:git !=# ''
        return fnamemodify(l:git, ':p:h:h')
    endif
    return getcwd()
endfunction

" A path the agent can resolve: relative to the project root when the file is
" inside it, absolute when it is not (a header from /usr/include, say).
function! s:Path() abort
    let l:file = expand('%:p')
    if l:file ==# ''
        return ''
    endif
    let l:root = s:Root() . '/'
    if strpart(l:file, 0, len(l:root)) ==# l:root
        return strpart(l:file, len(l:root))
    endif
    return l:file
endfunction

function! s:Ref(...) abort
    let l:path = s:Path()
    if l:path ==# ''
        return ''
    endif
    if a:0 == 0
        return '@' . l:path
    elseif a:0 == 1 || a:1 == a:2
        return '@' . l:path . '#L' . a:1
    endif
    return '@' . l:path . '#L' . a:1 . '-' . a:2
endfunction

" Send text to the agent. opts: fenced, lang, header, enter, focus.
function! s:Send(text, ...) abort
    let l:opts = a:0 ? a:1 : {}
    if a:text ==# ''
        echohl WarningMsg | echo 'agent: nothing to send' | echohl None
        return
    endif

    let l:body = a:text
    if get(l:opts, 'fenced', 0)
        let l:body = '```' . get(l:opts, 'lang', &filetype) . "\n" . l:body . "\n```"
    endif
    if has_key(l:opts, 'header')
        let l:body = l:opts.header . "\n" . l:body
    endif

    " Outside tmux there is no pane to paste into; the clipboard is the next
    " best handoff, and works over ssh from a local terminal just as well.
    if empty($TMUX)
        let @+ = l:body
        let @" = l:body
        echo 'agent: not in tmux, copied to clipboard'
        return
    endif

    let l:cmd = [g:agent_cmd, 'send']
    if get(l:opts, 'focus', g:agent_focus) | call add(l:cmd, '--focus') | endif
    if get(l:opts, 'enter', g:agent_enter) | call add(l:cmd, '--enter') | endif
    call add(l:cmd, '-')

    " Text goes over stdin: no quoting, no length limit, no shell involved in
    " what could be an entire function body.
    let l:out = system(join(map(l:cmd, 'shellescape(v:val)'), ' '), l:body)
    if v:shell_error
        echohl ErrorMsg | echo substitute(l:out, '\n\+$', '', '') | echohl None
    else
        echo 'agent: sent ' . len(split(l:body, "\n", 1)) . ' line(s)'
    endif
endfunction

" Yank the text a motion or a visual selection covers, without disturbing the
" registers or the marks the user is actually using.
function! s:Grab(type) abort
    let l:saved = [getreg('"'), getregtype('"')]
    if a:type ==# 'v' || a:type ==# 'V' || a:type ==# "\<C-v>"
        silent normal! `<v`>y
    elseif a:type ==# 'line'
        silent normal! '[V']y
    elseif a:type ==# 'char' || a:type ==# 'block'
        silent normal! `[v`]y
    else
        return ''
    endif
    let l:text = @"
    call setreg('"', l:saved[0], l:saved[1])
    return l:text
endfunction

" ------------------------------------------------------------------ pieces ---

function! s:SendFile() abort
    call s:Send(s:Ref() . ' ')
endfunction

function! s:SendLines(first, last) abort
    call s:Send(s:Ref(a:first, a:last) . ' ')
endfunction

function! s:SendSymbol() abort
    let l:word = expand('<cword>')
    if l:word ==# ''
        echohl WarningMsg | echo 'agent: no symbol under the cursor' | echohl None
        return
    endif
    call s:Send(printf('`%s` in %s ', l:word, s:Ref(line('.'), line('.'))))
endfunction

" The code itself, fenced, with the reference above it -- for the times the
" agent should look at exactly this and nothing else.
function! s:SendCode(type) abort
    let l:text = s:Grab(a:type)
    if l:text ==# '' | return | endif
    let l:first = line("'[")
    let l:last  = line("']")
    if a:type ==# 'v' || a:type ==# 'V' || a:type ==# "\<C-v>"
        let l:first = line("'<")
        let l:last  = line("'>")
    endif
    call s:Send(substitute(l:text, '\n\+$', '', ''),
        \ {'fenced': 1, 'header': s:Ref(l:first, l:last)})
endfunction

function! s:SendCodeVisual() abort
    call s:SendCode(visualmode())
endfunction

" Diagnostics for this buffer, as the linter or language server states them:
" the agent gets the real message and location rather than your retelling.
function! s:Diagnostics() abort
    let l:lines = []

    if has('nvim') && luaeval('vim.diagnostic ~= nil')
        for l:d in luaeval('vim.diagnostic.get(0)')
            call add(l:lines, printf('%s:%d:%d: %s%s',
                \ s:Path(), l:d.lnum + 1, l:d.col + 1,
                \ has_key(l:d, 'source') && l:d.source !=# '' ? l:d.source . ': ' : '',
                \ substitute(l:d.message, '\n', ' ', 'g')))
        endfor
    endif

    if empty(l:lines) && exists('*ale#engine#GetLoclist')
        for l:d in ale#engine#GetLoclist(bufnr('%'))
            call add(l:lines, printf('%s:%d:%d: %s: %s %s',
                \ s:Path(), l:d.lnum, get(l:d, 'col', 0),
                \ get(l:d, 'type', 'E') ==# 'E' ? 'error' : 'warning',
                \ get(l:d, 'linter_name', ''),
                \ substitute(l:d.text, '\n', ' ', 'g')))
        endfor
    endif

    if empty(l:lines)
        echo 'agent: no diagnostics in this buffer'
        return
    endif

    call s:Send(join(l:lines, "\n"),
        \ {'fenced': 1, 'lang': '', 'header': 'Diagnostics in ' . s:Ref() . ':'})
endfunction

" An agent editing files under you is the normal case here, not an accident,
" so make catching up explicit and cheap. 'autoread' and the checktime
" autocmds in vimrc do this on their own; this is the "right now" version, and
" the one to reach for after the agent reports it has finished a batch.
function! s:Reload() abort
    silent! checktime          " no argument: every buffer, not just this one
    echo 'agent: re-read buffers changed on disk'
endfunction

function! s:Open() abort
    if empty($TMUX)
        echohl WarningMsg | echo 'agent: not inside tmux' | echohl None
        return
    endif
    let l:out = system(shellescape(g:agent_cmd) . ' focus')
    if v:shell_error
        echohl ErrorMsg | echo substitute(l:out, '\n\+$', '', '') | echohl None
    endif
endfunction

" ---------------------------------------------------------------- commands ---

command!       -nargs=1          AgentSend  call s:Send(<q-args>)
command!                         AgentFile  call s:SendFile()
command! -range -bar             AgentLines call s:SendLines(<line1>, <line2>)
command!        -bar             AgentDiag  call s:Diagnostics()
command!        -bar             AgentOpen  call s:Open()
command!        -bar             AgentReload call s:Reload()

" ---------------------------------------------------------------- mappings ---

if !get(g:, 'agent_no_mappings', 0)
    nnoremap <silent> <leader>af :call <SID>SendFile()<CR>
    nnoremap <silent> <leader>al :call <SID>SendLines(line('.'), line('.'))<CR>
    xnoremap <silent> <leader>al :<C-u>call <SID>SendLines(line("'<"), line("'>"))<CR>
    nnoremap <silent> <leader>as :call <SID>SendSymbol()<CR>
    nnoremap <silent> <leader>ay :set operatorfunc=<SID>SendCode<CR>g@
    xnoremap <silent> <leader>ay :<C-u>call <SID>SendCodeVisual()<CR>
    nnoremap <silent> <leader>ae :call <SID>Diagnostics()<CR>
    nnoremap <silent> <leader>ao :call <SID>Open()<CR>
    nnoremap <silent> <leader>ar :call <SID>Reload()<CR>
endif
