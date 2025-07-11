#eval $(thefuck --alias)
alias open="xdg-open . & disown"
alias browser="w3m google.com"

# editors
alias snano="sudo nano --rcfile /home/ivsopi3/.nanorc"
alias codekitty="setup_code"
alias ck="setup_code"
alias nv="nvim"
alias code='code --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform-hint=auto'

alias alc='alacritty --working-directory "$(pwd)" > /dev/null 2>&1 & disown'

# dev
alias npi="npm install"
alias npr="npm run"
alias npb="npm run build"
alias npd="npm run dev"
alias cr="cargo run"
alias crr="cargo run release"
alias yayf="yay -Slq | fzf --multi --preview 'yay -Sii {1}' --preview-window=down:75% | xargs -ro yay -S"

# files and file browsers
# alias files="nemo . &> /dev/null & disown" # function instead, so I can pass an arg to it
alias size="du -hcs"
alias games="sudo mount UUID=560800025D1A30F9 /media/$LOGNAME/games"
alias ugames="sudo umount /media/$LOGNAME/games"
alias windows="sudo mount UUID=B272D69C72D6651F /media/$LOGNAME/windows"
alias uwindows="sudo umount /media/$LOGNAME/windows"
alias rs="rsync -ah --info=progress2" # --update
alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
alias ls="eza -lh --group-directories-first --icons=auto"
alias lt="eza --tree --level=2 --long --icons --git"

# bluetooth
alias blue="sudo systemctl start bluetooth.service && bluetoothctl"

