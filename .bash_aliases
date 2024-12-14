#eval $(thefuck --alias)
RED='\033[0;31m'
NC='\033[0m' # No Color
CYAN='\033[0;36m'
alias files="sudo du -sh --si --time --threshold=-250M * | sort -h; echo -e \"${RED}Over 250M:${NC}\"; du -sh --si --time --threshold=250M * | sort -h; echo -e \"${CYAN}Total:${NC}\"; du -sh ."
alias filesize="du -sh --si --time * | sort -rh"
alias open="xdg-open . & disown"
alias browser="w3m google.com"
alias list="sudo ls -a1X --color=always"
#alias nuke="sudo rm -Irv"
alias snano="sudo nano --rcfile /home/ivsopi3/.nanorc"
alias sshkitty="kitty +kitten ssh"
alias codekitty="setup_code"
alias customfind="cat ~/customfindshort.sh"

