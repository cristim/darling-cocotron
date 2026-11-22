#ifndef __CGBase_H__
#define __CGBase_H__

#include <float.h>

// Moved over from our CoreFoundation

#ifdef __LP64__
typedef double CGFloat;
#define CGFLOAT_MIN DBL_MIN
#define CGFLOAT_MAX DBL_MAX
#define CGFLOAT_SCAN "%lg"
#define CGFLOAT_IS_DOUBLE 1
#else
typedef float CGFloat;
#define CGFLOAT_MIN FLT_MIN
#define CGFLOAT_MAX FLT_MAX
#define CGFLOAT_SCAN "%g"
#define CGFLOAT_IS_DOUBLE 0
#endif

#define CGFLOAT_DEFINED 1

// Headers written against a recent macOS SDK annotate CoreGraphics pointer parameters with
// cg_nullable. Without it they do not parse. The qualifier goes after the '*'
// (float * cg_nullable p); before it, clang rejects it as applying to the pointee.
#if __has_feature(nullability)
#define cg_nullable __nullable
#else
#define cg_nullable
#endif

#endif
