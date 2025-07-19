# What do I use for...

## File management:
- `nemo` - GUI file manager
- `eza` - prettier `ls`
- `rsync` - `cp` with progress and remote capabilities
- `gdu` - see file sizes
- `dl` - move a file from the downloads folder

**Aliases and functions:**
- `ls` - mapped to `eza` automatically
- `files` - spawns nemo in the provided path
- `ff` - fuzzy find with preview from `bat`
- `lt` - recursive `eza` in a tree
- `size` - list file sizes using `du`

## Git:
**Aliases and functions:** (these are all prefixed like `git [...]`)
- `lg1`, `lg2`, ... `lg4` - formatted `git log`s
- `grhh` - hard reset
- `nuke` - harder reset, deleting any added files, as if you just cloned the repo
- `history` - show diffs in the different commits
- `rank` - rank number of contributions
- `review` - better git diff for current changes
- I don't use `lazygit`, but you might like it

## Terminal:
- `zsh` - shell, with oh-my-zsh for plugins
- `alacritty` - terminal, for no specific reason

**Aliases and functions:**
- `alc` - spawns a new alacritty in the given path

## Dev:
- editor: `neovim` and `vscode`

**Aliases and functions:**
- `ck` - spawns vscode in the current path, in a specific configuration by resizing the terminal. Originally I used the `kitty` terminal, this name comes from `code` and `kitty`
- `npi` - npm install
- `npr` - npm run
- `npb` - npm run build
- `npd` - npm run dev
- `cr` - cargo run
- `crr` - cargo run release
- `nv` - neovim
- `code` - this command already opened vscode, but now it passes some flags to (try to) run it in wayland

## Window managers, etc
- `sway` - window manager
- `ly` - login manager
- `dunst` - notifications
- `waybar` - bar, also contains a menu for power off/reboot, as well as network applet
- `swaybg` - background, using the path from the theme (see `.config/sway/display/set-bg.sh`)
- `flameshot` - screenshot
- `wl-clipboard` - clipboard for wayland
- `solaar` - auto launched to not allow my mouse to wake up my pc for no reason
- `swayidle` - after certain time, lock the screen or suspend (`.config/sway/lock/idle_lock.sh`)
- `swaylock` - lock, see `.config/sway/lock/lock.sh` to see how I use it
- `pipewire` - audio/media backend
- `pavucontrol` - GUI to manage audio devices
- `bluetoothctl` - manage blueetooth in the terminal
- `blueman` - GUI to manage blueetooth

## Network
- `nm-applet` - GUI applet in the bar's tray
- `somo` - see used ports
- `impala` - wifi TUI
- `nmtui` - TUI network management
- `nmcli` - for emergencies

**Aliases and functions:**
- `sc` - copy last screenshot (sometimes needed to paste into x11 apps, for wayland flameshot already copies them)
- `sd` - delete last screenshot

## AUR
- `yay` - AUR helper

**Aliases and functions:**
- `yayf` - fuzzy find packages

## Keybinds and input
- input (sensitivity, etc) and keybind configs are in `.config/sway/keybinds`
- volume keys - call a script in `.config/i3/sound`. You can also change volume through the bar or pavucontrol
- brightness keys - call scripts in `.config/i3/brightness/`
- my Super key is Windows key
- `Super + F1` - opens firefox in workspace 2
- `Super + F2` - opens discord in workspace 1 (don't ask)
- `Super + F3` - opens steam in workspace 5
- Most other keybinds are just i3's defaults

## Themes

I use [Rofi-Themer](https://github.com/IVSOP/Rofi-Themer.git) to tell my programs the correct path to their dotfiles. I can have multiple themes by having different dotfiles, and I usually just symlink to the correct path.

For example, polybar themes are in polybar/themes. The actual configuration file is just a symlink to one of the themed files.
To setup these symlinks, I use polybar/get-theme.sh.
