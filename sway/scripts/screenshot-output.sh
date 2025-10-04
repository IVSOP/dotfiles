#!/bin/sh

pkill slurp || hyprshot -m output \
    --filename "Screenshots/$(date +%Y_%m_%d-%H%M%S).png" \
    --notif-timeout 5000

