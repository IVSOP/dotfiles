#!/usr/bin/env python3

txt = (input().split("/"))[1]
txt = txt[2:len(txt)-2]
# for some reason at 0% it gets an extra space (" 0%" != "0%")
if txt[0] == " ":
    print(txt[1:])
else:
    print(txt)