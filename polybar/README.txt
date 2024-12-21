WIFI_IF
ETHERNET_IF
THERMAL_ZONE
CPU_TEMP

all need to be defined. currently I define them in env.sh right here (the file gets called by launch.sh)
example:
export WIFI_IF=wlp15s0

for interfaces use `ip a`

for thermal zone run
THIS IS PROB DEPRECATED, just set it to 0
`for i in /sys/class/thermal/thermal_zone*; do echo "$i: $(<$i/type)"; done`

and for cpu temp
`for i in /sys/class/hwmon/hwmon*/temp*_input; do echo "$(<$(dirname $i)/name): $(cat ${i%_*}_label 2>/dev/null || echo $(basename ${i%_*})) $(readlink -f $i)"; done`

