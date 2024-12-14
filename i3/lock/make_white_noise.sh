#!/bin/bash
convert -size 192x108 xc: +noise random noise_white.png
#mask
convert noise_white.png -virtual-pixel tile -blur 0x1 -fx intensity -normalize noise_white.png
#2 differente shades of blue noise
convert -size 192x108 xc:white -fill '#cccccc' -opaque white white1.png
convert -size 192x108 xc:white -fill '#bbbbbb' -opaque white white2.png
#blend
convert white1.png white2.png noise_white.png -composite noise_white.png
#blur
convert noise_white.png -scale 1000% noise_white.png
