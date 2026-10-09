// Host-side key injector for x11-modifier-defaults.m. Build: cc x11-modifier-defaults-helper.c -lX11
// Sends four synthetic KeyPress events for the x key to the window titled "mod-probe",
// with X states ControlMask, ControlMask|ShiftMask, Mod4Mask and ShiftMask.
// Exit codes: 0 sent, 2 no display, 3 window not found, 4 no keycode for x.
#include <X11/Xlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static Window find(Display *d, Window w, const char *name) {
    char *title = NULL;
    if (XFetchName(d, w, &title) && title) {
        int match = strcmp(title, name) == 0;
        XFree(title);
        if (match)
            return w;
    }
    Window root, parent, *children = NULL;
    unsigned int count = 0;
    Window found = None;
    if (XQueryTree(d, w, &root, &parent, &children, &count)) {
        for (unsigned int i = 0; i < count && found == None; i++)
            found = find(d, children[i], name);
        if (children)
            XFree(children);
    }
    return found;
}

int main(void) {
    Display *d = XOpenDisplay(NULL);
    if (!d)
        return 2;
    Window w = None;
    for (int i = 0; i < 100 && w == None; i++) {
        w = find(d, DefaultRootWindow(d), "mod-probe");
        if (w == None)
            usleep(100000);
    }
    if (w == None)
        return 3;
    KeyCode x = XKeysymToKeycode(d, XStringToKeysym("x"));
    if (!x)
        return 4;
    unsigned states[] = {ControlMask, ControlMask | ShiftMask, Mod4Mask, ShiftMask};
    for (int i = 0; i < 4; i++) {
        XKeyEvent ev;
        memset(&ev, 0, sizeof ev);
        ev.type = KeyPress;
        ev.display = d;
        ev.window = w;
        ev.root = DefaultRootWindow(d);
        ev.same_screen = True;
        ev.keycode = x;
        ev.state = states[i];
        XSendEvent(d, w, False, KeyPressMask, (XEvent *)&ev);
        XFlush(d);
        usleep(300000); // let the guest handle one event before the next
    }
    return 0;
}
