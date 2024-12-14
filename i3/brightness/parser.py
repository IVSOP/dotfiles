#!/usr/bin/env python3
txt = (input().split(","))[3]
#60% = full brightness in the bar so we multiply by 100/60
res = (float(txt[:(len(txt)-1)])*100)/60
print(int(res))
