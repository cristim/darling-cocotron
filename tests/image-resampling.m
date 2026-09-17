#import <AppKit/AppKit.h>
#import <Onyx2D/O2argb8u.h>
#include <stdio.h>
#include <string.h>
static int mathTest(void) {
    unsigned failures=0,checks=0;
    for (unsigned l=0;l<256;l++) for(unsigned r=0;r<256;r++) for(unsigned f=0;f<=256;f++) {
        O2argb8u a={0},b={0};a.r=l;a.g=255-l;a.b=l/2;a.a=255;
        b.r=r;b.g=255-r;b.b=r/2;b.a=255;
        O2argb8u c=O2argb8uMultiplyByCoverageAdd(a,256-f,b,f);
        unsigned er=(l*(256-f)+r*f)/256,eg=((255-l)*(256-f)+(255-r)*f)/256,eb=((l/2)*(256-f)+(r/2)*f)/256;
        failures+=(c.r!=er || c.g!=eg || c.b!=eb || c.a!=255);checks++;
    }
    printf("coverage checks=%u failures=%u\n",checks,failures);return failures!=0;
}
static int rasterTest(void) {
    NSBitmapImageRep *rep=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:32 pixelsHigh:24 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bitmapFormat:0 bytesPerRow:128 bitsPerPixel:32];
    unsigned char *data=[rep bitmapData];
    for(int i=0;i<32*24;i++){data[i*4]=255;data[i*4+1]=0;data[i*4+2]=255;data[i*4+3]=255;}
    NSImage *image=[[NSImage alloc] initWithSize:NSMakeSize(32,24)];[image addRepresentation:rep];
    int failures=0;
    for(int scale=1;scale<=3;scale++) {
        CGColorSpaceRef cs=CGColorSpaceCreateDeviceRGB();
        CGContextRef c=CGBitmapContextCreate(NULL,32*scale,24*scale,8,0,cs,kCGImageAlphaPremultipliedFirst|kCGBitmapByteOrder32Little);CGColorSpaceRelease(cs);
        [NSGraphicsContext saveGraphicsState];[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:c flipped:NO]];
        CGContextScaleCTM(c,scale,scale);[image drawInRect:NSMakeRect(0,0,32,24) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];[NSGraphicsContext restoreGraphicsState];
        unsigned char *b=CGBitmapContextGetData(c);size_t stride=CGBitmapContextGetBytesPerRow(c);int bad=0;
        for(int y=2;y<24*scale-2;y++)for(int x=2;x<32*scale-2;x++) {unsigned char *v=b+y*stride+x*4;bad+=(v[0]!=255||v[1]!=0||v[2]!=255||v[3]!=255);}
        unsigned char *v=b+5*stride+5*4;printf("raster scale=%d pixel=%u,%u,%u,%u bad=%d\n",scale,v[0],v[1],v[2],v[3],bad);failures+=bad!=0;CGContextRelease(c);
    }
    [image release];[rep release];return failures!=0;
}
int main(int argc,char **argv){@autoreleasepool{return argc>1&&strcmp(argv[1],"math")==0?mathTest():rasterTest();}}
