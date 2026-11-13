#include <CoreText/CoreTextExport.h>
#include <stdio.h>
#include <stdlib.h>

// A function that a guest application imports and that no public source documents (neither its arguments
// nor what a "grade" selects), so a call prints the name and aborts instead of answering with an invented
// font.
CORETEXT_EXPORT void CTFontCreateCopyOfSystemUIFontWithGrade(void)
{
    fprintf(stderr, "CoreText: CTFontCreateCopyOfSystemUIFontWithGrade is not implemented\n");
    abort();
}
