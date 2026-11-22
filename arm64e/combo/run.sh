#!/bin/bash
# usage: run.sh <variant ctl|new|orig> <label> : one Notes boot, own sway (stopped after), heavy lock around the guest run only
B=/home/cristi/tmp-opencode/darling-guest-build
C=/home/cristi/tmp-opencode/cocotron-kept/arm64e/combo
v=$1; label=$2
avail=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo); [ "$avail" -ge 4096 ] || { echo "MemAvailable $avail MB"; exit 75; }
f=$C/runs/$label.out; full=$C/runs/$label.full
export DARLING_INSTALL_PREFIX=$B/prefix DPREFIX=$B/dprefix
flock -w 7200 /tmp/agent-locks/darling-heavy-build.lock bash -c '
bash '$C'/sway-start.sh > /dev/null 2>&1
unset WAYLAND_DISPLAY DISPLAY I3SOCK HYPRLAND_INSTANCE_SIGNATURE
systemd-run --user --scope --quiet -p MemoryMax=2G -p MemorySwapMax=0 timeout 120 '$B'/prefix/bin/darling shell /bin/bash /Volumes/SystemRoot'$C'/guest.sh '$v' /Volumes/SystemRoot'$full' > '$f' 2>&1
echo "RUN-'$label'-RC=$?" >> '$f'
timeout 60 '$B'/prefix/bin/darling shutdown >> '$f' 2>&1
echo "SHUTDOWN-RC=$?" >> '$f'
kill $(cat '$C'/sway.pid) 2>/dev/null; sleep 1
pgrep -f "sway -c '$C'/sway.conf" >/dev/null && echo "SWAY STILL RUNNING" >> '$f'
'
grep -E 'TOKEN=|KEY=|SECRET=' $f $full | sed 's/=.*/=<REDACT-CHECK>/' | head -3
echo lines: $(wc -l < $f) full: $(wc -l < $full)
