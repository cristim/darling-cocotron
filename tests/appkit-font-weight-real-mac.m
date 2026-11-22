// The nine NSFontWeight constants hold single-precision values widened to double: the exact 64-bit patterns a real Mac holds
// (mac-probe darling_probe_a1.txt, macOS 26.1). They were once assigned from integer literals of these patterns, which gave
// numbers near 1e19 instead of -0.8 ... 0.62.
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void)
{
    static const struct { const char *name; uint64_t bits; } expected[] = {
        { "NSFontWeightBlack", 0x3fe3d70a40000000ULL },
        { "NSFontWeightBold", 0x3fd99999a0000000ULL },
        { "NSFontWeightHeavy", 0x3fe1eb8520000000ULL },
        { "NSFontWeightLight", 0xbfd99999a0000000ULL },
        { "NSFontWeightMedium", 0x3fcd70a3e0000000ULL },
        { "NSFontWeightRegular", 0x0000000000000000ULL },
        { "NSFontWeightSemibold", 0x3fd3333340000000ULL },
        { "NSFontWeightThin", 0xbfe3333340000000ULL },
        { "NSFontWeightUltraLight", 0xbfe99999a0000000ULL },
    };
    for (unsigned i = 0; i < sizeof expected / sizeof *expected; i++)
    {
        const double *symbol = (const double *)dlsym(RTLD_DEFAULT, expected[i].name);
        if (symbol == NULL)
        {
            fprintf(stderr, "FAIL: %s is not exported\n", expected[i].name);
            return 1;
        }
        uint64_t bits;
        memcpy(&bits, symbol, sizeof bits);
        if (bits != expected[i].bits)
        {
            fprintf(stderr, "FAIL: %s holds %.17g (0x%016llx), expected 0x%016llx\n", expected[i].name, *symbol,
                    (unsigned long long)bits, (unsigned long long)expected[i].bits);
            return 1;
        }
    }
    printf("appkit-font-weight-real-mac: ok\n");
    return 0;
}
