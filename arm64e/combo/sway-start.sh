#!/bin/bash
C=/home/cristi/tmp-opencode/cocotron-kept/arm64e/combo
unset WAYLAND_DISPLAY DISPLAY SWAYSOCK I3SOCK HYPRLAND_INSTANCE_SIGNATURE
export XDG_RUNTIME_DIR=$C/xdg WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1
: > $C/sway.conf
nohup sway -c $C/sway.conf > $C/sway.log 2>&1 &
echo $! > $C/sway.pid
sleep 3
ls $C/xdg
ls $C/xdg | grep -E "^wayland-[0-9]+$" | head -1 > $C/wl.name
cat $C/wl.name
