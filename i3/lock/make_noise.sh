#!/bin/bash
convert -size 192x108 xc: +noise random noise_red.png
#mask
convert noise_red.png -virtual-pixel tile -blur 0x1 -fx intensity -normalize noise_red.png
#2 differente shades of red noise
convert -size 192x108 xc:white -fill '#cc0000' -opaque white red1.png
convert -size 192x108 xc:white -fill '#bb0000' -opaque white red2.png
#blend
convert red1.png red2.png noise_red.png -composite noise_red.png
#blur
convert noise_red.png -scale 1000% noise_red.png
