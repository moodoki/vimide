#Python envsj
if [ -x ~/py3env ]; then
    alias p3='source ~/py3env/bin/activate'
fi
if [ -x ~/py2env ]; then
    alias p2='source ~/py2env/bin/activate'
fi

alias xo='xdg-open'

alias ta='tmux attach'


ssh_portforward(){
    ssh $1 -L $2:localhost:$2
}

alias s='ssh_portforward'
