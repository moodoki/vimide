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

alias xo='xdg-open'

alias ta='tmux attach || tmux new'

alias pbcopy='xsel --clipboard --input'
alias pbpaste='xsel --clipboard --output'

ssh_portforward(){
    ssh $1 -L $2:localhost:$2
}

alias s='ssh_portforward'
