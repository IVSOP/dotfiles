#!/bin/bash
convert -size 192x108 xc: +noise random noise_blue.png
#mask
convert noise_blue.png -virtual-pixel tile -blur 0x1 -fx intensity -normalize noise_blue.png
#2 differente shades of blue noise
convert -size 192x108 xc:white -fill '#0000cc' -opaque white blue1.png
convert -size 192x108 xc:white -fill '#0000bb' -opaque white blue2.png
#blend
convert blue1.png blue2.png noise_blue.png -composite noise_blue.png
#blur
convert noise_blue.png -scale 1000% noise_blue.png
