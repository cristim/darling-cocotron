// Host-side XDND source for x11-xdnd-foreign-source.m. Build: cc x11-xdnd-foreign-source-helper.c -lX11
// Behaves only as the public XDND specification says a source does, the way a file manager
// does: no XdndSelection or per-action window properties (those are this backend's private
// convention), the types in XdndTypeList (XdndEnter bit 0 set), the requested action as an
// atom in XdndPosition data.l[4], the data served through ownership of the XdndSelection
// selection. Sends XdndEnter, XdndPosition (XdndActionMove), waits for an accepting
// XdndStatus naming XdndActionCopy (the receiver only copies, and a target may answer with
// a different action than the requested one), sends XdndDrop and waits for XdndFinished.
// Exit codes: 0 pass, 2 no display, 3 target not found, 4 target lacks XdndAware,
// 5 no XdndStatus accepting the drag, 8 XdndStatus action is not copy,
// 9 no XdndFinished, 10 XdndFinished reports the drop was not performed.
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/select.h>
#include <unistd.h>

static const char URIS[] = "file:///xdnd-probe/a%20b.txt\r\nfile://localhost/xdnd-probe/two.txt\r\n";

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

static void serve(Display *d, XSelectionRequestEvent *r, Atom targets, Atom uriList) {
    XEvent reply = {0};
    reply.xselection.type = SelectionNotify;
    reply.xselection.requestor = r->requestor;
    reply.xselection.selection = r->selection;
    reply.xselection.target = r->target;
    reply.xselection.time = r->time;
    reply.xselection.property = None;
    if (r->target == targets) {
        unsigned long list[] = {uriList, targets};
        XChangeProperty(d, r->requestor, r->property, XA_ATOM, 32, PropModeReplace,
                        (unsigned char *)list, 2);
        reply.xselection.property = r->property;
    } else if (r->target == uriList) {
        XChangeProperty(d, r->requestor, r->property, uriList, 8, PropModeReplace,
                        (const unsigned char *)URIS, sizeof(URIS) - 1);
        reply.xselection.property = r->property;
    }
    XSendEvent(d, r->requestor, False, NoEventMask, &reply);
    XFlush(d);
}

static void xsend(Display *d, Window target, Atom type, long a, long b, long c, long e, long f) {
    XEvent ev = {0};
    ev.xclient.type = ClientMessage;
    ev.xclient.window = target;
    ev.xclient.message_type = type;
    ev.xclient.format = 32;
    ev.xclient.data.l[0] = a;
    ev.xclient.data.l[1] = b;
    ev.xclient.data.l[2] = c;
    ev.xclient.data.l[3] = e;
    ev.xclient.data.l[4] = f;
    XSendEvent(d, target, False, NoEventMask, &ev);
    XFlush(d);
}

// Pump events, serving selection requests, until a ClientMessage of `want` arrives.
static int wait_for(Display *d, Atom want, int seconds, Atom targets, Atom uriList, long *l1, Atom *action) {
    for (int waited = 0; waited < seconds * 10;) {
        while (XPending(d)) {
            XEvent ev;
            XNextEvent(d, &ev);
            if (ev.type == SelectionRequest)
                serve(d, &ev.xselectionrequest, targets, uriList);
            else if (ev.type == ClientMessage && ev.xclient.message_type == want) {
                *l1 = ev.xclient.data.l[1];
                *action = (Atom)ev.xclient.data.l[4];
                return 1;
            }
        }
        fd_set fds;
        FD_ZERO(&fds);
        FD_SET(ConnectionNumber(d), &fds);
        struct timeval tv = {0, 100000};
        if (select(ConnectionNumber(d) + 1, &fds, NULL, NULL, &tv) == 0)
            waited++;
    }
    return 0;
}

int main(void) {
    Display *d = XOpenDisplay(NULL);
    if (!d)
        return 2;
    Window target = None;
    for (int i = 0; i < 100 && target == None; i++) {
        target = find(d, DefaultRootWindow(d), "xdnd-target");
        if (target == None)
            usleep(100000);
    }
    if (target == None)
        return 3;

    Atom aware = XInternAtom(d, "XdndAware", False), selection = XInternAtom(d, "XdndSelection", False);
    Atom enter = XInternAtom(d, "XdndEnter", False), position = XInternAtom(d, "XdndPosition", False);
    Atom status = XInternAtom(d, "XdndStatus", False), drop = XInternAtom(d, "XdndDrop", False);
    Atom finished = XInternAtom(d, "XdndFinished", False), typeList = XInternAtom(d, "XdndTypeList", False);
    Atom move = XInternAtom(d, "XdndActionMove", False), copy = XInternAtom(d, "XdndActionCopy", False);
    Atom uriList = XInternAtom(d, "text/uri-list", False), targets = XInternAtom(d, "TARGETS", False);
    Atom plain = XInternAtom(d, "text/plain", False), html = XInternAtom(d, "text/html", False);
    Atom utf8 = XInternAtom(d, "UTF8_STRING", False);

    Atom type;
    int format;
    unsigned long count, remaining;
    unsigned char *data = NULL;
    int hasAware = XGetWindowProperty(d, target, aware, 0, 1, False, XA_ATOM, &type, &format,
                                      &count, &remaining, &data) == Success && type == XA_ATOM;
    if (data)
        XFree(data);
    if (!hasAware)
        return 4;

    Window source = XCreateSimpleWindow(d, DefaultRootWindow(d), 0, 0, 1, 1, 0, 0, 0);
    unsigned long version = 5;
    XChangeProperty(d, source, aware, XA_ATOM, 32, PropModeReplace, (unsigned char *)&version, 1);
    // More than three types, so XdndEnter carries them in XdndTypeList; the one that matters is last.
    Atom offered[] = {plain, html, utf8, uriList};
    XChangeProperty(d, source, typeList, XA_ATOM, 32, PropModeReplace, (unsigned char *)offered, 4);
    XSetSelectionOwner(d, selection, source, CurrentTime);
    XFlush(d);

    // Aim at the middle of the 300x200 content view, in root coordinates.
    int rx, ry;
    Window child;
    XTranslateCoordinates(d, target, DefaultRootWindow(d), 150, 100, &rx, &ry, &child);
    long l1;
    Atom action = None;

    xsend(d, target, enter, source, (long)((version << 24) | 1), None, None, None);
    xsend(d, target, position, source, 0, ((long)rx << 16) | ry, CurrentTime, move);
    if (!wait_for(d, status, 10, targets, uriList, &l1, &action) || !(l1 & 1))
        return 5;
    if (action != copy)
        return 8;
    xsend(d, target, drop, source, 0, CurrentTime, 0, 0);
    if (!wait_for(d, finished, 10, targets, uriList, &l1, &action))
        return 9;
    if (!(l1 & 1))
        return 10;
    printf("PASS: standard-protocol drop was performed\n");
    return 0;
}
