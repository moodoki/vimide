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

ln -s $(pwd)/vim ~/.vim
ln -s $(pwd)/vimrc ~/.vimrc

