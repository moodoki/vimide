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

if [ -e ~/.gdbinit ]
then
    echo Backing up ~/.gdbinit to ~/.gdbinit.bak
    mv ~/.gdbinit ~/.gdbinit.bak
fi

git submodule init
git submodule update

ln -s $(pwd)/vim ~/.vim
ln -s $(pwd)/vimrc ~/.vimrc
ln -s $(pwd)/gdbinit88888888 ~/.gdbinit

