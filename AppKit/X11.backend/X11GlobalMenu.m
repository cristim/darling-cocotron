#import "X11GlobalMenu.h"
#import "X11Display.h"
#import "X11Window.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSMenuItem.h>
#import <AppKit/NSPanel.h>
#import <AppKit/NSWindow.h>
#import <CoreFoundation/CoreFoundation.h>
#include <dbus/dbus.h>
#include <X11/Xatom.h>

static X11GlobalMenu *g_sharedGlobalMenu = nil;

@interface X11GlobalMenu ()
- (void) processPendingDBusEvents;
- (DBusHandlerResult) handleDBusMessage: (DBusMessage *) message onConnection: (DBusConnection *) connection;
@end

static void dbusSocketCallback(CFSocketRef s, CFSocketCallBackType type,
                               CFDataRef address, const void *data, void *info) {
    X11GlobalMenu *self = (X11GlobalMenu *)info;
    [self processPendingDBusEvents];
}

static DBusHandlerResult dbusFilterCallback(DBusConnection *connection,
                                            DBusMessage *message,
                                            void *user_data) {
    X11GlobalMenu *self = (X11GlobalMenu *)user_data;
    return [self handleDBusMessage: message onConnection: connection];
}

@implementation X11GlobalMenu

+ (instancetype) sharedGlobalMenu {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_sharedGlobalMenu = [[X11GlobalMenu alloc] init];
    });
    return g_sharedGlobalMenu;
}

- (instancetype) init {
    self = [super init];
    if (self) {
        _itemsByID = [NSMutableDictionary new];
        _idByItem = [NSMutableDictionary new];
        _nextID = 1;
        _revision = 1;
        _available = NO;

        const char *dbusAddr = getenv("DBUS_SESSION_BUS_ADDRESS");
        if (!dbusAddr || !*dbusAddr) {
            return self;
        }

        DBusError error;
        dbus_error_init(&error);
        _connection = dbus_bus_get(DBUS_BUS_SESSION, &error);
        if (dbus_error_is_set(&error) || !_connection) {
            dbus_error_free(&error);
            return self;
        }

        // Check if registrar exists
        dbus_bool_t hasRegistrar = dbus_bus_name_has_owner(_connection, "com.canonical.AppMenu.Registrar", &error);
        if (dbus_error_is_set(&error) || !hasRegistrar) {
            dbus_error_free(&error);
            // Even if registrar isn't explicit, KDE Plasma's gmenudbusmenuproxy accepts X11 window properties!
        }

        int fd = -1;
        if (dbus_connection_get_unix_fd(_connection, &fd) && fd >= 0) {
            CFSocketContext context = {
                .version = 0,
                .info = (void *)[self retain],
                .retain = (const void *(*)(const void *))CFRetain,
                .release = (void (*)(const void *))CFRelease,
                .copyDescription = NULL
            };
            _cfSocket = CFSocketCreateWithNative(kCFAllocatorDefault, fd,
                                                 kCFSocketReadCallBack,
                                                 dbusSocketCallback, &context);
            if (_cfSocket) {
                _runLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _cfSocket, 0);
                CFRunLoopAddSource(CFRunLoopGetMain(), _runLoopSource, kCFRunLoopCommonModes);
            }
        }

        static const DBusObjectPathVTable vtable = {
            .message_function = dbusFilterCallback
        };
        dbus_connection_try_register_object_path(_connection, "/MenuBar", &vtable, (void *)self, &error);

        dbus_connection_add_filter(_connection, dbusFilterCallback, (void *)self, NULL);
        _available = YES;
    }
    return self;
}

- (BOOL) isAvailable {
    return _available;
}

- (BOOL) isEngaged {
    return _globalMenuEngaged;
}

- (void) processPendingDBusEvents {
    if (!_connection)
        return;
    dbus_connection_read_write(_connection, 0);
    while (dbus_connection_dispatch(_connection) == DBUS_DISPATCH_DATA_REMAINS) {
    }
}

- (int32_t) idForMenuItem: (NSMenuItem *) item {
    NSValue *key = [NSValue valueWithNonretainedObject: item];
    NSNumber *num = [_idByItem objectForKey: key];
    if (!num) {
        int32_t assigned = _nextID++;
        num = @(assigned);
        [_idByItem setObject: num forKey: key];
        [_itemsByID setObject: item forKey: num];
    }
    return [num intValue];
}

- (void) appendPropertiesForItem: (NSMenuItem *) item
                        toIter: (DBusMessageIter *) dictIter {
    DBusMessageIter entryIter, variantIter;

    // label
    const char *keyLabel = "label";
    NSString *rawTitle = [item title];
    if (!rawTitle) rawTitle = @"";
    const char *labelVal = [rawTitle UTF8String];
    // -[NSString UTF8String] returns NULL when the string has no UTF-8
    // representation. The nil check above guards the NSString, not this, and
    // dbus_message_iter_append_basic asserts on a NULL value.
    if (!labelVal) labelVal = "";

    dbus_message_iter_open_container(dictIter, DBUS_TYPE_DICT_ENTRY, NULL, &entryIter);
    dbus_message_iter_append_basic(&entryIter, DBUS_TYPE_STRING, &keyLabel);
    dbus_message_iter_open_container(&entryIter, DBUS_TYPE_VARIANT, "s", &variantIter);
    dbus_message_iter_append_basic(&variantIter, DBUS_TYPE_STRING, &labelVal);
    dbus_message_iter_close_container(&entryIter, &variantIter);
    dbus_message_iter_close_container(dictIter, &entryIter);

    // enabled
    const char *keyEnabled = "enabled";
    dbus_bool_t enabledVal = [item isEnabled] ? TRUE : FALSE;
    dbus_message_iter_open_container(dictIter, DBUS_TYPE_DICT_ENTRY, NULL, &entryIter);
    dbus_message_iter_append_basic(&entryIter, DBUS_TYPE_STRING, &keyEnabled);
    dbus_message_iter_open_container(&entryIter, DBUS_TYPE_VARIANT, "b", &variantIter);
    dbus_message_iter_append_basic(&variantIter, DBUS_TYPE_BOOLEAN, &enabledVal);
    dbus_message_iter_close_container(&entryIter, &variantIter);
    dbus_message_iter_close_container(dictIter, &entryIter);

    // visible
    const char *keyVisible = "visible";
    dbus_bool_t visibleVal = ![item isHidden] ? TRUE : FALSE;
    dbus_message_iter_open_container(dictIter, DBUS_TYPE_DICT_ENTRY, NULL, &entryIter);
    dbus_message_iter_append_basic(&entryIter, DBUS_TYPE_STRING, &keyVisible);
    dbus_message_iter_open_container(&entryIter, DBUS_TYPE_VARIANT, "b", &variantIter);
    dbus_message_iter_append_basic(&variantIter, DBUS_TYPE_BOOLEAN, &visibleVal);
    dbus_message_iter_close_container(&entryIter, &variantIter);
    dbus_message_iter_close_container(dictIter, &entryIter);

    // type
    if ([item isSeparatorItem]) {
        const char *keyType = "type";
        const char *typeVal = "separator";
        dbus_message_iter_open_container(dictIter, DBUS_TYPE_DICT_ENTRY, NULL, &entryIter);
        dbus_message_iter_append_basic(&entryIter, DBUS_TYPE_STRING, &keyType);
        dbus_message_iter_open_container(&entryIter, DBUS_TYPE_VARIANT, "s", &variantIter);
        dbus_message_iter_append_basic(&variantIter, DBUS_TYPE_STRING, &typeVal);
        dbus_message_iter_close_container(&entryIter, &variantIter);
        dbus_message_iter_close_container(dictIter, &entryIter);
    }

    // children-display
    if ([item hasSubmenu] && [[[item submenu] itemArray] count] > 0) {
        const char *keyChildrenDisplay = "children-display";
        const char *displayVal = "submenu";
        dbus_message_iter_open_container(dictIter, DBUS_TYPE_DICT_ENTRY, NULL, &entryIter);
        dbus_message_iter_append_basic(&entryIter, DBUS_TYPE_STRING, &keyChildrenDisplay);
        dbus_message_iter_open_container(&entryIter, DBUS_TYPE_VARIANT, "s", &variantIter);
        dbus_message_iter_append_basic(&variantIter, DBUS_TYPE_STRING, &displayVal);
        dbus_message_iter_close_container(&entryIter, &variantIter);
        dbus_message_iter_close_container(dictIter, &entryIter);
    }
}

- (void) appendMenu: (NSMenu *) menu
             asNode: (int32_t) nodeId
             toIter: (DBusMessageIter *) parentIter
              depth: (int32_t) depth {
    DBusMessageIter structIter, dictIter, childrenArrayIter;

    dbus_message_iter_open_container(parentIter, DBUS_TYPE_STRUCT, NULL, &structIter);
    dbus_message_iter_append_basic(&structIter, DBUS_TYPE_INT32, &nodeId);

    // Properties dict
    dbus_message_iter_open_container(&structIter, DBUS_TYPE_ARRAY, "{sv}", &dictIter);
    if (nodeId == 0) {
        // Root properties
        const char *keyDisplay = "children-display";
        const char *valDisplay = "submenu";
        DBusMessageIter eIter, vIter;
        dbus_message_iter_open_container(&dictIter, DBUS_TYPE_DICT_ENTRY, NULL, &eIter);
        dbus_message_iter_append_basic(&eIter, DBUS_TYPE_STRING, &keyDisplay);
        dbus_message_iter_open_container(&eIter, DBUS_TYPE_VARIANT, "s", &vIter);
        dbus_message_iter_append_basic(&vIter, DBUS_TYPE_STRING, &valDisplay);
        dbus_message_iter_close_container(&eIter, &vIter);
        dbus_message_iter_close_container(&dictIter, &eIter);
    } else {
        NSMenuItem *item = [_itemsByID objectForKey: @(nodeId)];
        if (item) {
            [self appendPropertiesForItem: item toIter: &dictIter];
        }
    }
    dbus_message_iter_close_container(&structIter, &dictIter);

    // Children array
    dbus_message_iter_open_container(&structIter, DBUS_TYPE_ARRAY, "v", &childrenArrayIter);
    if (depth != 0 && menu != nil) {
        for (NSMenuItem *child in [menu itemArray]) {
            int32_t childID = [self idForMenuItem: child];
            DBusMessageIter variantChild;
            dbus_message_iter_open_container(&childrenArrayIter, DBUS_TYPE_VARIANT, "(ia{sv}av)", &variantChild);
            NSMenu *childSub = [child hasSubmenu] ? [child submenu] : nil;
            [self appendMenu: childSub asNode: childID toIter: &variantChild depth: (depth > 0 ? depth - 1 : depth)];
            dbus_message_iter_close_container(&childrenArrayIter, &variantChild);
        }
    }
    dbus_message_iter_close_container(&structIter, &childrenArrayIter);

    dbus_message_iter_close_container(parentIter, &structIter);
}

- (DBusHandlerResult) handleDBusMessage: (DBusMessage *) message
                           onConnection: (DBusConnection *) connection {
    const char *member = dbus_message_get_member(message);
    const char *path = dbus_message_get_path(message);
    const char *interface = dbus_message_get_interface(message);

    if (!member) return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

    if (strcmp(member, "Introspect") == 0) {
        static const char *kIntrospectXML =
            "<!DOCTYPE node PUBLIC \"-//freedesktop//DTD D-BUS Object Introspection 1.0//EN\"\n"
            "\"http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd\">\n"
            "<node>\n"
            "  <interface name=\"org.freedesktop.DBus.Introspectable\">\n"
            "    <method name=\"Introspect\">\n"
            "      <arg name=\"xml_data\" type=\"s\" direction=\"out\"/>\n"
            "    </method>\n"
            "  </interface>\n"
            "  <interface name=\"org.freedesktop.DBus.Properties\">\n"
            "    <method name=\"Get\">\n"
            "      <arg name=\"interface_name\" type=\"s\" direction=\"in\"/>\n"
            "      <arg name=\"property_name\" type=\"s\" direction=\"in\"/>\n"
            "      <arg name=\"value\" type=\"v\" direction=\"out\"/>\n"
            "    </method>\n"
            "    <method name=\"GetAll\">\n"
            "      <arg name=\"interface_name\" type=\"s\" direction=\"in\"/>\n"
            "      <arg name=\"properties\" type=\"a{sv}\" direction=\"out\"/>\n"
            "    </method>\n"
            "  </interface>\n"
            "  <interface name=\"com.canonical.dbusmenu\">\n"
            "    <property name=\"Version\" type=\"u\" access=\"read\"/>\n"
            "    <property name=\"Status\" type=\"s\" access=\"read\"/>\n"
            "    <method name=\"GetLayout\">\n"
            "      <arg type=\"i\" name=\"parentId\" direction=\"in\"/>\n"
            "      <arg type=\"i\" name=\"recursionDepth\" direction=\"in\"/>\n"
            "      <arg type=\"as\" name=\"propertyNames\" direction=\"in\"/>\n"
            "      <arg type=\"u\" name=\"revision\" direction=\"out\"/>\n"
            "      <arg type=\"(ia{sv}av)\" name=\"layout\" direction=\"out\"/>\n"
            "    </method>\n"
            "    <method name=\"Event\">\n"
            "      <arg type=\"i\" name=\"id\" direction=\"in\"/>\n"
            "      <arg type=\"s\" name=\"eventId\" direction=\"in\"/>\n"
            "      <arg type=\"v\" name=\"data\" direction=\"in\"/>\n"
            "      <arg type=\"u\" name=\"timestamp\" direction=\"in\"/>\n"
            "    </method>\n"
            "    <method name=\"AboutToShow\">\n"
            "      <arg type=\"i\" name=\"id\" direction=\"in\"/>\n"
            "      <arg type=\"b\" name=\"needUpdate\" direction=\"out\"/>\n"
            "    </method>\n"
            "    <signal name=\"LayoutUpdated\">\n"
            "      <arg type=\"u\" name=\"revision\" direction=\"out\"/>\n"
            "      <arg type=\"i\" name=\"parent\" direction=\"out\"/>\n"
            "    </signal>\n"
            "  </interface>\n"
            "</node>\n";

        DBusMessage *reply = dbus_message_new_method_return(message);
        dbus_message_append_args(reply, DBUS_TYPE_STRING, &kIntrospectXML, DBUS_TYPE_INVALID);
        dbus_connection_send(connection, reply, NULL);
        dbus_message_unref(reply);
        return DBUS_HANDLER_RESULT_HANDLED;
    } else if (strcmp(member, "GetAll") == 0) {
        DBusMessage *reply = dbus_message_new_method_return(message);
        DBusMessageIter replyIter, dictIter, entryIter, varIter;
        dbus_message_iter_init_append(reply, &replyIter);
        dbus_message_iter_open_container(&replyIter, DBUS_TYPE_ARRAY, "{sv}", &dictIter);

        // Version = 3
        const char *kVer = "Version";
        uint32_t verVal = 3;
        dbus_message_iter_open_container(&dictIter, DBUS_TYPE_DICT_ENTRY, NULL, &entryIter);
        dbus_message_iter_append_basic(&entryIter, DBUS_TYPE_STRING, &kVer);
        dbus_message_iter_open_container(&entryIter, DBUS_TYPE_VARIANT, "u", &varIter);
        dbus_message_iter_append_basic(&varIter, DBUS_TYPE_UINT32, &verVal);
        dbus_message_iter_close_container(&entryIter, &varIter);
        dbus_message_iter_close_container(&dictIter, &entryIter);

        // Status = "normal"
        const char *kStat = "Status";
        const char *statVal = "normal";
        dbus_message_iter_open_container(&dictIter, DBUS_TYPE_DICT_ENTRY, NULL, &entryIter);
        dbus_message_iter_append_basic(&entryIter, DBUS_TYPE_STRING, &kStat);
        dbus_message_iter_open_container(&entryIter, DBUS_TYPE_VARIANT, "s", &varIter);
        dbus_message_iter_append_basic(&varIter, DBUS_TYPE_STRING, &statVal);
        dbus_message_iter_close_container(&entryIter, &varIter);
        dbus_message_iter_close_container(&dictIter, &entryIter);

        dbus_message_iter_close_container(&replyIter, &dictIter);
        dbus_connection_send(connection, reply, NULL);
        dbus_message_unref(reply);
        return DBUS_HANDLER_RESULT_HANDLED;
    }

    if (strcmp(member, "GetLayout") == 0) {
        if (!_globalMenuEngaged) {
            _globalMenuEngaged = YES;
            dispatch_async(dispatch_get_main_queue(), ^{
                for (NSWindow *window in [NSApp windows]) {
                    if (![window isKindOfClass: [NSPanel class]]) {
                        [window _hideMenuViewIfNeeded];
                    }
                }
            });
        }
        int32_t parentId = 0;
        int32_t recursionDepth = -1;
        DBusMessageIter argsIter;
        if (dbus_message_iter_init(message, &argsIter)) {
            if (dbus_message_iter_get_arg_type(&argsIter) == DBUS_TYPE_INT32) {
                dbus_message_iter_get_basic(&argsIter, &parentId);
                dbus_message_iter_next(&argsIter);
            }
            if (dbus_message_iter_get_arg_type(&argsIter) == DBUS_TYPE_INT32) {
                dbus_message_iter_get_basic(&argsIter, &recursionDepth);
            }
        }

        DBusMessage *reply = dbus_message_new_method_return(message);
        DBusMessageIter replyIter;
        dbus_message_iter_init_append(reply, &replyIter);

        dbus_message_iter_append_basic(&replyIter, DBUS_TYPE_UINT32, &_revision);

        NSMenu *targetMenu = _currentMenu;
        if (parentId != 0) {
            NSMenuItem *it = [_itemsByID objectForKey: @(parentId)];
            targetMenu = [it hasSubmenu] ? [it submenu] : nil;
        }

        [self appendMenu: targetMenu asNode: parentId toIter: &replyIter depth: recursionDepth];

        dbus_connection_send(connection, reply, NULL);
        dbus_message_unref(reply);
        return DBUS_HANDLER_RESULT_HANDLED;
    } else if (strcmp(member, "Event") == 0) {
        int32_t itemId = 0;
        const char *eventId = NULL;
        DBusMessageIter argsIter;
        if (dbus_message_iter_init(message, &argsIter)) {
            if (dbus_message_iter_get_arg_type(&argsIter) == DBUS_TYPE_INT32) {
                dbus_message_iter_get_basic(&argsIter, &itemId);
                dbus_message_iter_next(&argsIter);
            }
            if (dbus_message_iter_get_arg_type(&argsIter) == DBUS_TYPE_STRING) {
                dbus_message_iter_get_basic(&argsIter, &eventId);
            }
        }

        if (eventId && strcmp(eventId, "clicked") == 0) {
            NSMenuItem *clickedItem = [_itemsByID objectForKey: @(itemId)];
            if (clickedItem && [clickedItem action]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [NSApp sendAction: [clickedItem action] to: [clickedItem target] from: clickedItem];
                });
            }
        }

        DBusMessage *reply = dbus_message_new_method_return(message);
        dbus_connection_send(connection, reply, NULL);
        dbus_message_unref(reply);
        return DBUS_HANDLER_RESULT_HANDLED;
    } else if (strcmp(member, "AboutToShow") == 0) {
        DBusMessage *reply = dbus_message_new_method_return(message);
        dbus_bool_t needUpdate = FALSE;
        dbus_message_append_args(reply, DBUS_TYPE_BOOLEAN, &needUpdate, DBUS_TYPE_INVALID);
        dbus_connection_send(connection, reply, NULL);
        dbus_message_unref(reply);
        return DBUS_HANDLER_RESULT_HANDLED;
    }

    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}

- (void) dealloc {
    if (_runLoopSource) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), _runLoopSource, kCFRunLoopCommonModes);
        CFRelease(_runLoopSource);
    }
    if (_cfSocket) {
        CFSocketInvalidate(_cfSocket);
        CFRelease(_cfSocket);
    }
    if (_connection) {
        dbus_connection_unref(_connection);
    }
    [_itemsByID release];
    [_idByItem release];
    [_currentMenu release];
    [super dealloc];
}

- (void) updateMenu: (NSMenu *) menu {
    if (_currentMenu != menu) {
        [_currentMenu release];
        _currentMenu = [menu retain];
    }
    _revision++;
    if (!_connection || !_available)
        return;

    // Send LayoutUpdated signal
    DBusMessage *sig = dbus_message_new_signal("/MenuBar", "com.canonical.dbusmenu", "LayoutUpdated");
    if (sig) {
        int32_t rootId = 0;
        dbus_message_append_args(sig, DBUS_TYPE_UINT32, &_revision,
                                      DBUS_TYPE_INT32, &rootId,
                                      DBUS_TYPE_INVALID);
        dbus_connection_send(_connection, sig, NULL);
        dbus_message_unref(sig);
    }
}

- (void) registerWindow: (Window) x11Window forMenu: (NSMenu *) menu {
    if (!_available || !_connection)
        return;

    [self updateMenu: menu];

    const char *serviceName = dbus_bus_get_unique_name(_connection);
    if (!serviceName)
        return;

    Display *dpy = [(X11Display *)[NSDisplay currentDisplay] display];
    if (!dpy || !x11Window)
        return;

    Atom serviceAtom = XInternAtom(dpy, "_KDE_NET_WM_APPMENU_SERVICE_NAME", False);
    Atom pathAtom = XInternAtom(dpy, "_KDE_NET_WM_APPMENU_OBJECT_PATH", False);
    Atom utf8Atom = XInternAtom(dpy, "UTF8_STRING", False);

    const char *objPath = "/MenuBar";

    XChangeProperty(dpy, x11Window, serviceAtom, utf8Atom, 8, PropModeReplace,
                    (const unsigned char *)serviceName, strlen(serviceName));
    XChangeProperty(dpy, x11Window, pathAtom, utf8Atom, 8, PropModeReplace,
                    (const unsigned char *)objPath, strlen(objPath));

    // Also call RegisterWindow on com.canonical.AppMenu.Registrar
    DBusMessage *msg = dbus_message_new_method_call("com.canonical.AppMenu.Registrar",
                                                    "/com/canonical/AppMenu/Registrar",
                                                    "com.canonical.AppMenu.Registrar",
                                                    "RegisterWindow");
    if (msg) {
        uint32_t winId = (uint32_t)x11Window;
        dbus_message_append_args(msg, DBUS_TYPE_UINT32, &winId,
                                      DBUS_TYPE_OBJECT_PATH, &objPath,
                                      DBUS_TYPE_INVALID);
        dbus_connection_send(_connection, msg, NULL);
        dbus_message_unref(msg);
    }
}

- (void) unregisterWindow: (Window) x11Window {
    if (!_available || !_connection)
        return;

    const char *objPath = "/MenuBar";
    DBusMessage *msg = dbus_message_new_method_call("com.canonical.AppMenu.Registrar",
                                                    "/com/canonical/AppMenu/Registrar",
                                                    "com.canonical.AppMenu.Registrar",
                                                    "UnregisterWindow");
    if (msg) {
        uint32_t winId = (uint32_t)x11Window;
        dbus_message_append_args(msg, DBUS_TYPE_UINT32, &winId, DBUS_TYPE_INVALID);
        dbus_connection_send(_connection, msg, NULL);
        dbus_message_unref(msg);
    }
}

@end
