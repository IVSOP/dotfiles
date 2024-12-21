# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export EDITOR="nvim"

export HISTSIZE=1000
export HISTFILESIZE=2000

zstyle ':omz:update' mode disabled
zstyle ':completion:' use-cache on
ENABLE_CORRECTION="false"

# ZSH_THEME="robbyrussell"

plugins=(z copypath colored-man-pages) # git

source $ZSH/oh-my-zsh.sh
source $HOME/.bash_aliases
source $HOME/.bash_funcs

export LANGUAGE=en_US.UTF-8
export _JAVA_OPTIONS='-Dawt.useSystemAAFontSettings=on'
export EDITOR=nvim

# print return code in red if it is an error code
function statstring {
    RC=$?
    if [ "0" != $RC ]; then
        printf "[$RC] "
    fi
}

PROMPT='%B%F{red}$(statstring)%f%F{green}%n@%m%f %F{blue}%~%f $%b '

# source cargo/env???
