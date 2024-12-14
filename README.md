Clone this recursively: git clone --recurse-submodules <url>

How I deal with themes:

For example, polybar themes are in polybar/themes. The actual configuration file is just a symlink to one of the themed files.
To setup these symlinks, I use [https://github.com/IVSOP/Rofi-Themer](https://github.com/IVSOP/Rofi-Themer)
The script that does this (in this example) is polybar/get-theme.sh

