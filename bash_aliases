#Python envsj
if [ -x ~/py3env ]; then
    alias py3='source ~/py3env/bin/activate'
fi
if [ -x ~/p3env ]; then
    alias p3='source ~/p3env/bin/activate'
fi
if [ -x ~/py2env ]; then
    alias p2='source ~/py2env/bin/activate'
fi

function activate(){
    source ~/.venvs/$1/bin/activate
}

_list_venvs(){
    local cur _venvs
    cur="${COMP_WORDS[COMP_CWORD]}"
    _venvs=$(ls ~/.venvs/)
    COMPREPLY=( $(compgen -W "${_venvs}" -- ${cur}) )
}

complete -F _list_venvs activate

alias xo='xdg-open'

alias ipnb='jupyter notebook --no-browser --ip="*"'
alias ta='tmux attach || tmux new'

alias pbcopy='xsel --clipboard --input'
alias pbpaste='xsel --clipboard --output'

ssh_portforward(){
    ssh $1 -L $2:localhost:$2
}

alias s='ssh_portforward'

alias df='df -x squashfs'
