#!/bin/bash

#either change default sink or change selected input (or all) to selected sink
#list inputs: pacmd list-sink-inputs

#pacmd list-sinks | grep -Pzo "\* index(.*\n)*" | sed \$d | grep -e "device.description" | cut -f 2 -d\"

# the input can be big, if I have performance issues will remake in C instead
list_sink_desc () {
    pacmd list-sinks | python $HOME/.config/i3/sound/controller-parser.py
}

list_sink_desc