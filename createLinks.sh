#!/bin/bash

#backup originals if exists
if [ -e ~/.vimrc ]
then
    echo Backing up ~/.vimrc to ~/.vimrc.bak
    mv ~/.vimrc ~/.vimrc.bak
fi

if [ -e ~/.vim ]
then
    echo Backing up ~/.vim to ~/.vim.bak
    mv ~/.vim ~/.vim.bak
fi

if [ -e ~/.bash_aliases ]
then
    echo Backing up ~/.bash_aliases to ~/.bash_aliases.bak
    mv ~/.bash_aliases ~/.bash_aliases.bak
fi

if [ -e ~/.gdbinit ]
then
    echo Backing up ~/.gdbinit to ~/.gdbinit.bak
    mv ~/.gdbinit ~/.gdbinit.bak
fi

if [ ! -e ~/.fonts ]
then
    mkdir ~/.fonts
fi

if [ ! -e ~/.config ]
then
    mkdir ~/.config
fi

git submodule init
git submodule update

ln -s $(pwd)/vim ~/.vim
ln -s $(pwd)/vimrc ~/.vimrc
ln -s $(pwd)/bash_aliases ~/.bash_aliases
ln -s $(pwd)/tmux.conf ~/.tmux.conf
ln -s $(pwd)/fonts ~/.fonts/vimide_fonts
ln -s $(pwd)/nvim_config ~/.config/nvim
ln -s $(pwd)/conkyrc ~/.conkyrc
# ln -s $(pwd)/gdbinit8 ~/.gdbinit

fc-cache -s
