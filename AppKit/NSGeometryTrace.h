/* Opt-in runtime geometry diagnostics; never log view text or client data. */
#ifndef DARLING_NS_GEOMETRY_TRACE_H
#define DARLING_NS_GEOMETRY_TRACE_H
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

static inline void DarlingGeometryTrace(const char *format, ...) {
    if (!getenv("DARLING_UI_GEOMETRY_TRACE"))
        return;
    va_list args, copy;
    va_start(args, format);
    va_copy(copy, args);
    vfprintf(stderr, format, args);
    va_end(args);
    /* Clients may redirect stderr to a non-log descriptor. Keep a copy in
     * the guest's temporary directory so their resize events remain visible. */
    FILE *file = fopen("/tmp/darling-ui-geometry.log", "a");
    if (file) {
        vfprintf(file, format, copy);
        fclose(file);
    }
    va_end(copy);
}
#endif
