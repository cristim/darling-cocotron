#!/bin/bash
# usage: drive.sh <ctl|new> ; compile (arm64e) and relink AppKit, CoreText, QuartzCore from the variant worktree. Scratch only.
v=$1; R=/home/cristi/tmp-opencode/cocotron-kept/arm64e/$v; WT=/home/cristi/tmp-opencode/cocotron-kept-wt/$v
cd $R
python3 -B $R/bin/mkfwinc.py $WT
A=src_external_cocotron_AppKit_AppKit; C=src_external_cocotron_CoreText_CoreText; Q=src_external_cocotron_QuartzCore_QuartzCore
while [ "$(awk '/MemAvailable/{print int($2/1024/1024)}' /proc/meminfo)" -lt 4 ]; do sleep 30; done
flock -w 7200 /tmp/agent-locks/darling-heavy-build.lock systemd-run --user --scope --quiet -p MemoryMax=5G python3 -B $R/bin/compile_nl9.py $WT $A $C $Q > $R/compile.log 2>&1
echo "COMPILE-RC=$?" >> $R/compile.log
for i in $A:NSFontCollection.m.o $C: $Q:; do
  img=${i%%:*}; ex=${i#*:}
  flock -w 7200 /tmp/agent-locks/darling-heavy-build.lock systemd-run --user --scope --quiet -p MemoryMax=4G python3 -B $R/bin/relink_nl9b.py $img $ex > $R/relink-$img.log 2>&1
  echo "RELINK-$img-RC=$?" >> $R/relink-$img.log
done
echo done > $R/DONE
