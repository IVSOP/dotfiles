# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export EDITOR="nvim"

export HISTSIZE=1000
export HISTFILESIZE=2000

plugins=(z copypath colored-man-pages) # git
source $ZSH/oh-my-zsh.sh
source $HOME/.bash_aliases
source $HOME/.bash_funcs

zstyle ':omz:update' mode disabled
zstyle ':completion:' use-cache on
zstyle ':completion:*' matcher-list '' # so that egg. D matches Downloads but not dotfiles
# unsetopt nocaseglob
# autoload -Uz compinit && compinit
ENABLE_CORRECTION="false"

# ZSH_THEME="robbyrussell"

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

# ssh agent
# could also use systemd, whatever
if ! pgrep -u "$USER" ssh-agent > /dev/null; then
    ssh-agent -t 3h > "$XDG_RUNTIME_DIR/ssh-agent.env"
fi
if [ ! -f "$SSH_AUTH_SOCK" ]; then
    source "$XDG_RUNTIME_DIR/ssh-agent.env" >/dev/null
fi

