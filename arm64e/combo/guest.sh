# usage (guest): bash guest.sh <variant> <outfile>; never prints the environment; cores off
H=/Volumes/SystemRoot/home/cristi
N=$H/tmp-opencode/notes-l9
C=$H/tmp-opencode/cocotron-kept/arm64e/combo
v=$1; out=$2
ulimit -c 0
APP=$N/app/Notes.app/Contents/MacOS/Notes
echo RUN
env -u DISPLAY DYLD_PRINT_OBJC_NOTIFICATIONS=1 DYLD_LIBRARY_PATH=$C/side-$v/lib DYLD_FRAMEWORK_PATH=$C/side-$v/Frameworks DYLD_PRINT_CACHE_POLICY=1 \
  DYLD_SHARED_CACHE_SPLIT_DIR=$H/tmp-opencode/tsd-guest-cache DYLD_SHARED_CACHE_SPLIT_POLICY=$N/policy-nl9a.txt \
  DARLING_APPKIT_BACKEND=wayland XDG_RUNTIME_DIR=$C/xdg WAYLAND_DISPLAY=$(cat $C/wl.name) "$APP" > $out 2>&1
echo app-rc=$?
