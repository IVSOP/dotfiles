#!/bin/bash
convert -size 192x108 xc: +noise random noise_purple.png
#mask
convert noise_purple.png -virtual-pixel tile -blur 0x1 -fx intensity -normalize noise_purple.png
#2 differente shades of noise
convert -size 192x108 xc:purple -fill '#bd00ff' -opaque purple purple1.png
convert -size 192x108 xc:purple -fill '#d600ff' -opaque purple purple2.png
#blend
convert purple1.png purple2.png noise_purple.png -composite noise_purple.png
#blur
convert noise_purple.png -scale 1000% noise_purple.png
