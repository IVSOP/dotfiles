#! /bin/bash

# this is extemely hackish https://askubuntu.com/questions/1266769/find-device-description-of-default-sink-from-pulseaudio
# it lists most recent as it assumes that is the first entry (???)
# pacmd list-sinks | grep -Pzo "\* index(.*\n)*" | sed \$d | grep -e "device.description" | cut -f2 -d\"

# with pipewire, this no longer worked
# idk, it works
wpctl status | grep "*" | head -1 | cut -f2 -d. | cut -f1 -d[ | cut -c 2-
# sed????
