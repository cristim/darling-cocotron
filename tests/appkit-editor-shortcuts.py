#!/usr/bin/env python3
"""Drive the shortcut probe on a dedicated X11 or Wayland test display.

Usage: appkit-editor-shortcuts.py x11|wayland /path/to/probe.log
The probe must already be running and focused. Never use a live desktop.
"""
import pathlib
import re
import subprocess
import sys
import time

backend, logfile = sys.argv[1:]
assert backend in ('x11', 'wayland')
log = pathlib.Path(logfile)


def key(shortcut):
    if backend == 'x11':
        subprocess.run(['xdotool', 'key', '--clearmodifiers', shortcut], check=True)
    else:
        parts = shortcut.split('+')
        modifiers = {'ctrl': ('Control_L', 'ctrl'), 'shift': ('Shift_L', 'shift'),
                     'super': ('Super_L', 'logo'), 'alt': ('Alt_L', 'alt')}
        args = ['wtype', '-s', '300']
        for modifier in parts[:-1]:
            physical, mask = modifiers[modifier]
            args += ['-P', physical, '-M', mask]
        args += ['-s', '100', '-k', parts[-1], '-s', '150']
        for modifier in reversed(parts[:-1]):
            physical, mask = modifiers[modifier]
            args += ['-m', mask, '-p', physical]
        subprocess.run(args + ['-s', '150'], check=True)
    time.sleep(.6)


def type_text(value):
    if backend == 'x11':
        args = ['xdotool', 'type', '--clearmodifiers', '--delay', '60', value]
    else:
        args = ['wtype', '-s', '300', value, '-s', '200']
    subprocess.run(args, check=True)
    time.sleep(.8)


def expect(label, text, selection=None, clipboard=None):
    deadline = time.monotonic() + 3
    while True:
        states = re.findall(r'^STATE range=(\d+),(\d+) text=(.*?) clipboard=(.*)$',
                            log.read_text(errors='replace'), re.MULTILINE)
        assert states, 'No probe state received'
        location, length, actual, copied = states[-1]
        matches = actual == text.replace('\n', '\\n')
        if selection is not None:
            matches &= (int(location), int(length)) == selection
        if clipboard is not None:
            matches &= copied == clipboard.replace('\n', '\\n')
        if matches:
            break
        if time.monotonic() >= deadline:
            raise AssertionError((label, states[-1], text, selection, clipboard))
        time.sleep(.05)
    print('PASS', label, flush=True)


key('ctrl+a')
type_text('one two three')
expect('typing', 'one two three', (13, 0))
for shortcut, text, selection, clipboard in [
    ('ctrl+Left', 'one two three', (8, 0), None),
    ('ctrl+Right', 'one two three', (13, 0), None),
    ('ctrl+shift+Left', 'one two three', (8, 5), None),
    ('ctrl+shift+Right', 'one two three', (13, 0), None),
    ('ctrl+Left', 'one two three', (8, 0), None),
    ('ctrl+shift+Left', 'one two three', (4, 4), None),
    ('ctrl+c', 'one two three', (4, 4), 'two '),
    ('Right', 'one two three', (8, 0), None),
    ('ctrl+v', 'one two two three', (12, 0), None),
    ('ctrl+z', 'one two three', None, None),
    ('ctrl+shift+z', 'one two two three', None, None),
    ('ctrl+a', 'one two two three', (0, 17), None),
    ('Left', 'one two two three', (0, 0), None),
    ('shift+Right', 'one two two three', (0, 1), None),
    ('shift+Left', 'one two two three', (0, 0), None),
    ('End', 'one two two three', (17, 0), None),
    ('shift+Home', 'one two two three', (0, 17), None),
    ('ctrl+x', '', (0, 0), 'one two two three'),
    ('ctrl+v', 'one two two three', (17, 0), None),
    ('ctrl+z', '', None, None),
    ('ctrl+y', 'one two two three', None, None),
]:
    key(shortcut)
    expect(shortcut, text, selection, clipboard)

key('ctrl+a')
type_text('abc\ndef\nghi')
expect('multiline typing', 'abc\ndef\nghi', (11, 0))
for shortcut, selection in [
    ('Up', (7, 0)), ('Down', (11, 0)), ('Home', (8, 0)),
    ('shift+Up', (4, 4)), ('shift+Down', (8, 0)), ('shift+Down', (8, 3)),
    ('Left', (8, 0)), ('ctrl+Up', (8, 0)), ('ctrl+Down', (11, 0)),
    ('ctrl+shift+Up', (8, 3)), ('ctrl+shift+Down', (11, 0)),
    ('ctrl+Home', (11, 0)), ('ctrl+End', (11, 0)),
    ('super+Home', (0, 0)), ('super+shift+End', (0, 11)),
    ('super+shift+Home', (0, 0)), ('super+End', (11, 0)),
    ('alt+Left', (8, 0)), ('alt+shift+Right', (8, 3)),
]:
    key(shortcut)
    expect(shortcut, 'abc\ndef\nghi', selection)
