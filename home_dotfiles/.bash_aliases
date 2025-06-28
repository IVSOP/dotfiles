#eval $(thefuck --alias)
alias open="xdg-open . & disown"
alias browser="w3m google.com"
# alias list="sudo ls -a1X --color=always"

# editors
alias snano="sudo nano --rcfile /home/ivsopi3/.nanorc"
alias codekitty="setup_code"
alias ck="setup_code"
alias nv="nvim"
alias code='code --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform-hint=auto'

alias alc='alacritty --working-directory "$(pwd)" > /dev/null 2>&1 & disown'

# dev
alias npi="npm install"
alias nr="npm run"
alias nrb="npm run build"
alias nrd="npm run dev"
alias cr="cargo run"

# files and file browsers
alias files="nemo . &> /dev/null & disown"
alias size="du -hcs"
alias games="sudo mount UUID=560800025D1A30F9 /media/$LOGNAME/games"
alias ugames="sudo umount /media/$LOGNAME/games"
alias windows="sudo mount UUID=B272D69C72D6651F /media/$LOGNAME/windows"
alias uwindows="sudo umount /media/$LOGNAME/windows"
alias rs="rsync -ah --info=progress2" # --update

# bluetooth
alias blue="sudo systemctl start bluetooth.service && bluetoothctl"

