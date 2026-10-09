#!/usr/bin/env bash
# Run a guest AppKit test against a host-side Xlib helper on a private Xvfb.
#   tests/x11-guest-helper.sh HELPER.c GUEST_BINARY
# GUEST_BINARY is a Mach-O built inside the Darling prefix (see the test's .md). It prints a
# line starting with READY once its windows are mapped; the helper is started after that.
# DARLING selects the launcher (default: darling). Exit status is 0 only if both succeed.
set -euo pipefail
helper_src=$1
guest=$2
scratch=${TMPDIR:-$HOME/.local/share/agent-tmp}/x11-guest-helper
mkdir -p "$scratch"
work=$(mktemp -d "$scratch/run.XXXXXX")
trap 'rm -rf "$work"' EXIT
cc -Wall -Werror "$helper_src" -lX11 -o "$work/helper"
xvfb-run -a -s '-screen 0 800x600x24' bash -c '
    set -u
    work=$1; guest=$2; darling=$3
    "$darling" shell env DARLING_APPKIT_BACKEND=x11 DISPLAY="$DISPLAY" "$guest" \
        >"$work/guest.log" 2>&1 &
    guest_pid=$!
    for _ in $(seq 120); do
        grep -q "^READY" "$work/guest.log" && break
        kill -0 "$guest_pid" 2>/dev/null || break
        sleep 0.5
    done
    if ! grep -q "^READY" "$work/guest.log"; then
        echo "guest never reported READY" >&2
        cat "$work/guest.log" >&2
        exit 1
    fi
    helper_status=0
    timeout 90 "$work/helper" || helper_status=$?
    guest_status=0
    wait "$guest_pid" || guest_status=$?
    cat "$work/guest.log"
    echo "helper=$helper_status guest=$guest_status"
    [ "$helper_status" -eq 0 ] && [ "$guest_status" -eq 0 ]
' bash "$work" "$guest" "${DARLING:-darling}"
