# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export EDITOR="nvim"
export LESS='-R --mouse'

export HISTSIZE=1000
export HISTFILESIZE=2000

export DISABLE_AUTO_UPDATE=true
export ZSH_DISABLE_COMPFIX=true
plugins=(z copypath colored-man-pages fzf-tab)
source $ZSH/oh-my-zsh.sh
source $HOME/.bash_aliases
source $HOME/.bash_funcs

zstyle ':omz:update' mode disabled
zstyle ':completion:*' use-cache on
# Share filename colors with ls/eza, including executable files.
# SSH sessions may not inherit LS_COLORS from the local desktop.
if [[ -z $LS_COLORS ]] && (( $+commands[dircolors] )); then
    if [[ -r $HOME/.dircolors ]]; then
        eval "$(dircolors -b "$HOME/.dircolors")"
    else
        eval "$(dircolors -b)"
    fi
fi
# Keep basic file colors even without dircolors or a recognized terminal.
export LS_COLORS="${LS_COLORS:-di=01;34:ln=01;36:ex=01;32:so=01;35:pi=33:bd=01;33:cd=01;33:or=01;31}"
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' matcher-list '' # keep completion case-sensitive
# Include hidden files and all file types in fzf-tab's completion candidates.
_comp_options+=(globdots)
zstyle ':completion:*' file-patterns '*:all-files'
# Exclude . and .. while keeping hidden files visible.
zstyle ':completion:*' special-dirs false
fignore=()
# unsetopt nocaseglob
# autoload -Uz compinit && compinit
ENABLE_CORRECTION="false"

# ZSH_THEME="robbyrussell"

export LANGUAGE=en_US.UTF-8
export _JAVA_OPTIONS='-Dawt.useSystemAAFontSettings=on'
export EDITOR=nvim

# Print nonzero return codes in red on their own line above the prompt.
PROMPT=$'%B%(?..%F{red}[%?]%f\n)%F{green}%n@%m%f %F{blue}%~%f $%b '

export ANDROID_HOME=/opt/android-sdk
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/platform-tools


export NVM_DIR="$HOME/.nvm"

# Lazy-load nvm only when it is first needed.
_lazy_load_nvm() {
    unset -f _lazy_load_nvm nvm node npm npx
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}

nvm() {
    _lazy_load_nvm
    nvm "$@"
}

node() {
    _lazy_load_nvm
    command node "$@"
}

npm() {
    _lazy_load_nvm
    command npm "$@"
}

npx() {
    _lazy_load_nvm
    command npx "$@"
}
