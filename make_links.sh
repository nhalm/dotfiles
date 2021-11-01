#!/usr/bin/env bash

echo "making the necesary symlinks"

echo
if [ ! -r ${HOME}/.bash_profile ]; then
	echo "making .bash_profile symlink"
	ln -s $(pwd)/bash_profile $HOME/.bash_profile
fi

echo
echo "making the neovim symlinks"
mkdir -p $HOME/.config/nvim
if [ -e $HOME/.config/nvim/init.lua ] || [ -L $HOME/.config/nvim/init.lua ]; then
	echo "removing existing .config/nvim/init.lua symlink"
	rm $HOME/.config/nvim/init.lua
fi
echo "creating existing .config/nvim/init.lua symlink"
ln -s $(pwd)/nvim/init.lua $HOME/.config/nvim/init.lua

if [ -L $HOME/.config/nvim/lua ]; then
	echo "removing existing .config/nvim/lua symlink"
	rm $HOME/.config/nvim/lua
fi
echo "creating existing .config/nvim/lua symlink"
ln -s $(pwd)/nvim/lua $HOME/.config/nvim/lua

echo
echo "making .tmux.conf symlink"
if [ -e $HOME/.tmux.conf ] || [ -L $HOME/.tmux.conf ]; then
	echo "removing existing .tmux.conf symlink"
	rm $HOME/.tmux.conf
fi
echo "creating existing .tmux.conf symlink"
ln -s $(pwd)/tmux.conf $HOME/.tmux.conf

echo 
echo "adding bashrc"
if [ -e $HOME/.bashrc ] || [ -L $HOME/.bashrc ]; then
	echo "removing existing .bashrc symlink"
	rm $HOME/.bashrc
fi
echo "creating existing .bashrc symlink"
ln -s $(pwd)/bashrc $HOME/.bashrc

echo 
echo "making .gitconfig symlink"
if [ -e $HOME/.gitconfig ] || [ -L $HOME/.gitconfig ]; then
	echo "removing existing .gitconfig symlink"
	rm $HOME/.gitconfig
fi
echo "creating existing .gitconfig symlink"
ln -s $(pwd)/gitconfig $HOME/.gitconfig

echo 
echo "making .psqlrc symlink"
if [ -e $HOME/.psqlrc ] || [ -L $HOME/.psqlrc ]; then
	echo "removing existing .psqlrc symlink"
	rm $HOME/.psqlrc
fi
echo "creating existing .psqlrc symlink"
ln -s $(pwd)/psqlrc $HOME/.psqlrc

echo 
echo "adding bash functions and aliases"
if [ -e $HOME/.bash_aliases ] || [ -L $HOME/.bash_aliases ]; then
	echo "removing existing .bash_aliases symlink"
	rm $HOME/.bash_aliases
fi
echo "creating existing .bash_aliases symlink"
ln -s $(pwd)/bash_aliases $HOME/.bash_aliases

echo
echo "making .tmux symlink"
if [ -d $HOME/.tmux ] || [ -L $HOME/.tmux ]; then
	echo "removing existing .tmux/ symlink"
	rm -rf $HOME/.tmux
fi
echo "creating existing .tmux/ symlink"
ln -s $(pwd)/tmux $HOME/.tmux

