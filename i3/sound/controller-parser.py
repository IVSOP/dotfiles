#!/usr/bin/env python3
from sys import stdin

i = 0
desc = []
for line in stdin:
    #print(line, end='') # to avoid repeating newline
    if (line.startswith("    index") or line.startswith("  *")):
        for c in line:
            if c.isdigit():
                desc.append([c,""]) # missing name or description
                i += 1

print(desc)