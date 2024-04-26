#!/bin/bash

if [ -z "$CODESPACES" ]; then
  git config --global url."git@github.com".insteadOf "https://github.com"
fi


__DOTFILE_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
__DOTFILE_KEY="spg-dotfile"
if ! grep $__DOTFILE_KEY ~/.bashrc >/dev/null; 
then 
    echo "# $__DOTFILE_KEY" >>~/.bashrc
    echo "PATH=${__DOTFILE_DIR}/bin:\$PATH" >>~/.bashrc
    echo "export PATH" >>~/.bashrc
    echo $0: .bashrc update
fi

unset __DOTFILE_DIR
unset __DOTFILE_KEY

