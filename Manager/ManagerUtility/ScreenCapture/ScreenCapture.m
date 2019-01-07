//
//  PollingScreenshot.m
//  Manager
//
//  Created by SR_LHH_MAC on 2017. 8. 21..
//  Copyright © 2017년 tomm. All rights reserved.
//

#import <CoreMedia/CoreMedia.h>
#import <CoreMediaIO/CMIOHardware.h>
#import <CoreImage/CoreImage.h>

#import "ScreenCapture.h"
#import "Utility.h"

#import "SEEnums.h"
#import "TaskHandler.h"
#import "ControlAgent.h"



#define MAX_JPEG_PIXEL          960
#define USE_CALC_DIFFERENT_RECT

#define FIRST_SCREENSHOT        @"first.tiff"

#pragma mark -
#pragma mark - <ScreenCapture>
@interface ScreenCapture ()
// for image comparison

@property (nonatomic, assign)   BOOL                    lastFrameNeedRotate;
@property (nonatomic, assign)   UInt                    lastFrameBufferSize;
@property (nonatomic, assign)   size_t                  lastBytesPerRow;
@property (nonatomic, assign)   size_t                  lastWidth;
@property (nonatomic, assign)   size_t                  lastHeight;
@property (nonatomic, assign)   CGColorSpaceRef         lastColorSpaceRef;
@property (nonatomic, assign)   uint32_t                lastBitmapInfo;

@end


@implementation ScreenCapture
@synthesize customDelegate, myDeviceInfos;
@synthesize jpegbFixed, jpegFixedOrientation, jpegFixedLonger, jpegFixedShorter, jpegScale;
@synthesize devOrientation;
@synthesize devUdid;
@synthesize lastFrameBuffer;

+ (ScreenCapture *)createPollingScreenCapture:(ControlAgent *)controlAgent {
    PollingScreenCapture * screenCapture = [[PollingScreenCapture alloc] initWithControlAgent:controlAgent];
    return screenCapture;
}

+ (ScreenCapture *)createQuickTimeScreenCapture {
    QuickTimeScreenCapture * screenCapture = [[QuickTimeScreenCapture alloc] init];
    return screenCapture;
}

- (id) init {
    self = [super init];
    if( self ) {
        lastFrameBuffer = NULL;
        _lastFrameBufferSize = 0;
    }
    
    return self;
}

- (CGFloat) getScale: (int)imgWidth imgHeight:(int)imgHeight
{
    int nMax = MAX_JPEG_PIXEL;
    if( jpegbFixed && jpegFixedLonger < MAX_JPEG_PIXEL)
    {
        nMax = jpegFixedLonger;
    }
    
    int nLonger = MAX( imgWidth, imgHeight );
    float nTarget;
    if( nLonger > nMax ) {
        nTarget = (float)(nMax * jpegScale) / 100.0f;
    } else {
        nTarget = (float)(nLonger * jpegScale) / 100.0f;
    }
    
    CGFloat outScale = (float)nTarget / (float)nLonger;
    
    return outScale;
}

- (BOOL) needRotate: (int)imgWidth imgHeight:(int)imgHeight
{
    int needRotate = 0;
    int devOutOrientation = devOrientation;
    
    if( jpegbFixed ) {
        devOutOrientation = jpegFixedOrientation;
    }
    
    if( imgWidth > imgHeight) {     // image landscape
        if( devOutOrientation == 1)       //   : portrait
        {
            needRotate = 1;
        }
    } else {                        // image portrait
        if( devOutOrientation == 1)       //   : portrait
        {
            
        } else {                    //   :landscape
            
            needRotate = 1;
        }
    }
    return (needRotate != 0);
}

- (void) setQuality: (int) quality
{
    jpegQuality = quality;
    
    float q = (float)jpegQuality/100.0f;
    
    DDLogInfo(@"change jpeg compression quality:%.2f", q);
    
    if( qualityDic != nil)
    {
        CFRelease(qualityDic);
        CFRelease(qualityValues[0]);
    }
    qualityKeys[0] = kCGImageDestinationLossyCompressionQuality;
    qualityValues[0] = CFNumberCreate(NULL, kCFNumberFloatType, &q);
    qualityDic = CFDictionaryCreate( NULL, (const void **)qualityKeys, (const void **)qualityValues, 1,
                                    &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
}

- (CGFloat) getQuality
{
    CGFloat q = (float)jpegQuality/100.0f;
    return q;
}

- (CGRect) getDiffRegion:(CGImageRef)imageRef originRect:(CGRect)originRect bNeedRotate:(BOOL)bNeedRotate;
{
    if( imageRef == nil) return originRect;
    
    CGRect diffRect;
    
    diffRect = originRect;
    
    // for image comparison
    const unsigned char *pixelData = NULL;
    
    _lastColorSpaceRef = CGImageGetColorSpace(imageRef);
    _lastBitmapInfo = CGImageGetBitmapInfo(imageRef);
    
    
    CGDataProviderRef imageDataProvider = CGImageGetDataProvider(imageRef);
    CFDataRef imageData = CGDataProviderCopyData(imageDataProvider);
    CFIndex imageLen = CFDataGetLength(imageData);
    
    pixelData = CFDataGetBytePtr(imageData);
    int bpp = (int)CGImageGetBitsPerPixel(imageRef) / 8;
    int bpr = (int)CGImageGetBytesPerRow(imageRef);
    _lastBytesPerRow = bpr;
    //--- do compare
    const unsigned char * oldPixelData = lastFrameBuffer;
    
    //int ox = originRect.origin.x;
    //int oy = originRect.origin.y;
    int width = originRect.size.width;
    int height = originRect.size.height;
    _lastWidth = width;
    _lastHeight = height;
    if( oldPixelData != nil && imageLen <= _lastFrameBufferSize ) {
        
        int diffY1 = 0;
        int diffY2 = height;
        int diffX1 = 0;
        int diffX2 = width;
        for(int y1 = 0; y1 < height; y1++)
        {
            if( memcmp(oldPixelData + y1 * bpr, pixelData + y1 * bpr, bpr) != 0 )
            {
                break;
            } else {
                diffY1 = y1;
            }
        }
        
        for(int y2 = height-1; y2 >=  diffY1; y2--)
        {
            if( memcmp(oldPixelData + y2 * bpr, pixelData + y2 * bpr, bpr) != 0 )
            {
                break;
            } else {
                diffY2 = y2+1;
            }
        }
        
        int widthX = width;
        for( int y3 = diffY1; y3 < diffY2; y3++)
        {
            for(int x1 = 0; x1 < widthX; x1++)
            {
                if( memcmp(oldPixelData + y3 * bpr + x1 * bpp,
                           pixelData + y3 * bpr + x1 * bpp,
                           bpp) != 0)
                {
                    break;
                } else {
                    diffX1 = x1;
                }
            }
            widthX = diffX1;
        }
        
        widthX = diffX1;
        for( int y4 = diffY1; y4 < diffY2; y4++)
        {
            for(int x2 = width-1; x2 >= widthX; x2--)
            {
                if( memcmp(oldPixelData + y4 * bpr + x2*bpp,
                           pixelData + y4 * bpr + x2*bpp,
                           bpp) != 0)
                {
                    break;
                } else {
                    diffX2 = x2+1;
                }
            }
            widthX = diffX2;
        }
        
        diffRect = CGRectMake(diffX1, diffY1, (diffX2-diffX1), diffY2 - diffY1);
    }
    
//    DDLogInfo(@"diffRect:%.0f,%.0f,%.0f,%.0f", diffRect.origin.x, diffRect.origin.y, diffRect.size.width, diffRect.size.height);
    
    
    //--- save frame for next compare
    if( imageLen > _lastFrameBufferSize)
    {
        _lastFrameBufferSize = (UInt)imageLen;
        if( lastFrameBuffer != nil)
            free(lastFrameBuffer);
        lastFrameBuffer = (UInt8*)malloc(_lastFrameBufferSize);
    }
    CFDataGetBytes(imageData, CFRangeMake(0,imageLen), lastFrameBuffer);
    _lastFrameNeedRotate = bNeedRotate;;
    
    CFRelease(imageData);
    
    return diffRect;
}



@end


#pragma mark - 
#pragma mark - <PollingScreenCapture>

@interface PollingScreenCapture ()

@property (nonatomic, strong) ControlAgent      * myControlAgnet;
@property (nonatomic, strong) NSData            * dtFirstImage;
@property (nonatomic, strong) NSTimer           * firstImageTimer;
@property (nonatomic, strong) NSTimer           * pollingTimer;

@property (nonatomic, strong) NSTask            * myFirstSnapshotTask;
@property (nonatomic, assign) BOOL              bOldNeedRotate;
@property (nonatomic, assign) CGSize            imageSize;
@end

@implementation PollingScreenCapture

- (id) initWithControlAgent:(ControlAgent *)controlAgent {
    self = [super init];
    if( self ) {
        _myControlAgnet = controlAgent;
        
        _dtFirstImage = nil;
        _firstImageTimer = nil;
        _pollingTimer = nil;
        
        _imageSize = CGSizeZero;
        
        devOrientation = -1;
        
//        [self initPolling];
    }
    
    return self;
}


#pragma mark - <Timer>
- (void) firstScreenShotTimer:(NSTimer *)theTimer {
    if( _dtFirstImage ) {
        [_firstImageTimer invalidate];
        _firstImageTimer = nil;
        return ;
    }
    
    [self performSelectorInBackground:@selector(getFristScreenShotImage) withObject:nil];
}

- (void) pollingScreenCaptureTimer:(NSTimer *)theTimer {
    
    if( -1 == devOrientation ) {
        int orientation = [_myControlAgnet orientation];
        
        if( SELENIUM_SCREEN_ORIENTATION_PORTRAIT == orientation ) {
            devOrientation = 1;
        } else if ( SELENIUM_SCREEN_ORIENTATION_LANDSCAPE == orientation ) {
            devOrientation = 0;
        }
    }
    
    NSData * imageData = nil;
    if( _myControlAgnet )
        imageData = [_myControlAgnet getScreenShot];
    
    if( imageData )
        [self performSelectorInBackground:@selector(processCaptureOutput:) withObject:imageData];
}

#pragma mark - <Interface Functions>

- (void) startScreenCapture {
    DDLogInfo(@"%s", __FUNCTION__);
    jpegbFixed = 0;
    jpegFixedOrientation = 1;       // 0 - landscape, 1 - portrait
    jpegFixedLonger = 568;
    jpegFixedShorter = 320;
    jpegScale = 100;              // 10 ~ 100 : 10 means 10%
    [self setQuality:70];
    
    _bOldNeedRotate = FALSE;
    
    if( _dtFirstImage ) {
        [self processCaptureOutput:_dtFirstImage];
    }
    
    [self startPolling];
}

- (void) stopScreenCapture {
    
    devOrientation = -1;
    if( _pollingTimer ) {
        [_pollingTimer invalidate];
        _pollingTimer = nil;
    }
    
//    [self removeFirstScreenShot];
}


#pragma mark - <User Functions>
- (void)initPolling {
    if( [NSThread isMainThread] ) {
        _firstImageTimer = [NSTimer scheduledTimerWithTimeInterval:5.0f target:self selector:@selector(firstScreenShotTimer:) userInfo:nil repeats:YES];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            _firstImageTimer = [NSTimer scheduledTimerWithTimeInterval:5.0f target:self selector:@selector(firstScreenShotTimer:) userInfo:nil repeats:YES];
        });
    }
}

- (void) startPolling {
    if( [NSThread isMainThread] ) {
        _pollingTimer = [NSTimer scheduledTimerWithTimeInterval:2.0f target:self selector:@selector(pollingScreenCaptureTimer:) userInfo:nil repeats:YES];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            _pollingTimer = [NSTimer scheduledTimerWithTimeInterval:2.0f target:self selector:@selector(pollingScreenCaptureTimer:) userInfo:nil repeats:YES];
        });
    }
}

- (void) removeFirstScreenShot {
    NSString * managerDirectory = [Utility managerDirectory];
    NSString * firstImageFullPath = [NSString stringWithFormat:@"%@/%@_%@",managerDirectory, devUdid, FIRST_SCREENSHOT];
    
    NSFileManager* fileMgr = [NSFileManager defaultManager];
    [fileMgr removeItemAtPath:firstImageFullPath error:nil];
}

- (void) getFristScreenShotImage {
    
    NSString * managerDirectory = [Utility managerDirectory];
    NSString * firstImageFullPath = [NSString stringWithFormat:@"%@/%@_%@",managerDirectory, devUdid, FIRST_SCREENSHOT];
    
    _myFirstSnapshotTask = [[NSTask alloc] init];
    _myFirstSnapshotTask.launchPath = @"/bin/bash";
    NSString* commandString = [NSString stringWithFormat:@"idevicescreenshot -u %@ %@", devUdid, firstImageFullPath];
    _myFirstSnapshotTask.arguments  = @[@"-l", @"-c", commandString];
    
    NSPipe *pipe= [NSPipe pipe];
    [_myFirstSnapshotTask setStandardOutput: pipe];
    
    NSPipe * errorPipe = [NSPipe pipe];
    [_myFirstSnapshotTask setStandardError:errorPipe];
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        [_myFirstSnapshotTask launch];
    });
    
    NSFileHandle * errorFile = [errorPipe fileHandleForReading];
    
    NSData * errorData = [errorFile readDataToEndOfFile];
    NSString * errorOutput = [[NSString alloc] initWithData:errorData encoding: NSUTF8StringEncoding];
    [errorFile closeFile];
    
    if( [errorOutput containsString:@"No device found"] ) {     //  실패
        return ;
    }
    
    NSImage * firstScreenShot = [[NSImage alloc] initWithContentsOfFile:firstImageFullPath];
//    _imageSize = firstScreenShot.size;
    if( firstScreenShot ) {
//        NSData * imgData = [firstScreenShot TIFFRepresentation];
//        NSBitmapImageRep* bitmap = [NSBitmapImageRep imageRepWithData: imgData];
//        _dtFirstImage = [bitmap representationUsingType:NSPNGFileType properties:nil];
        
        _dtFirstImage = [firstScreenShot TIFFRepresentation];
    }
}

- (void) processCaptureOutput:(NSData *)imageData {
    
    // png 저장 성공..
//    static int nCount = 0;
//    NSString * managerDirectory = [Utility managerDirectory];
//    NSString * firstImageFullPath = [NSString stringWithFormat:@"%@/%d_%@",managerDirectory, nCount, @"test.png"];
//    [imageData writeToFile:firstImageFullPath atomically:YES];
    
    BOOL bIsKeyFrame = YES;
    NSBitmapImageRep* bitmap = [NSBitmapImageRep imageRepWithData:imageData];
//    NSData * captureData = [bitmap representationUsingType:NSJPEGFileType properties:nil];
    
    CGImageRef resizeImageRef = bitmap.CGImage;
    _imageSize = bitmap.size;
    if( 0 == _imageSize.width ) {
        DDLogInfo(@"Device Resolution( %d x %d )", (int)_imageSize.width, (int)_imageSize.height);
    }
    
    CIImage* ciImage = [CIImage imageWithCGImage:resizeImageRef];
    if( ciImage == nil || qualityDic == nil) {
        DDLogError(@"Image Processing Error... ciImage is null");
        return; //continue;
    }
    
    // (2) --- resize and rotation
    CGFloat rotate = -90.0f; // counterclockwise rotation
    CGFloat scale = [self getScale:(int)_imageSize.width imgHeight:(int)_imageSize.height];
    BOOL bNeedRotate = [self needRotate:(int)_imageSize.width imgHeight:(int)_imageSize.height];
    
    
//    DDLogInfo(@"[#### Info ####] Screen Image -- width : %d, height : %d, scale : %f, needRotate : %@", (int)_imageSize.width, (int)_imageSize.height, scale, (bNeedRotate == 1)? @"YES":@"NO" );
    
    if( bNeedRotate != _bOldNeedRotate) {
        bIsKeyFrame = YES;
        _bOldNeedRotate = bNeedRotate;
    }

    CIImage* resizeImage;
    
    NSAffineTransform* transform    = [NSAffineTransform transform];
    
    [transform scaleBy: scale];
    if( bNeedRotate) {
        [transform rotateByDegrees:rotate];
        [transform translateXBy:(-1 * (int)_imageSize.width) yBy:0];
    }
    
    
    CIFilter * filter               = [CIFilter filterWithName:@"CIAffineTransform"];
    [filter setDefaults];
    [filter setValue: ciImage   forKey: @"inputImage"];
    [filter setValue: transform forKey: @"inputTransform"];
    
    resizeImage = [filter valueForKey: @"outputImage"];
    resizeImageRef = nil;
    CIContext *myContext = [CIContext contextWithOptions:nil];
    resizeImageRef = [myContext createCGImage:resizeImage fromRect:[resizeImage extent]];
    
    
    // (3) -- calc different region and get image
    CGRect originRect = [resizeImage extent];
    CGRect diffRect = originRect;
    CGImageRef diffImageRef = nil;
    
    
    // calc diff rect
#ifdef USE_CALC_DIFFERENT_RECT
    if( bIsKeyFrame == FALSE || lastFrameBuffer == nil) {
        diffRect = [self getDiffRegion:resizeImageRef originRect:originRect bNeedRotate:bNeedRotate];
    }
    
    if( bIsKeyFrame == FALSE &&
       (
        originRect.origin.x != diffRect.origin.x ||
        originRect.origin.y != diffRect.origin.y ||
        originRect.size.width != diffRect.size.width ||
        originRect.size.height != diffRect.size.height))
    {
        if( diffRect.size.width != 0 && diffRect.size.height != 0)
        {
            CGFloat y = diffRect.origin.y;
            
            diffRect.origin.y = originRect.size.height - diffRect.origin.y - diffRect.size.height;
            
            CIContext *diffContext = [CIContext contextWithOptions:nil];
            
            diffImageRef = [diffContext createCGImage:resizeImage fromRect:diffRect];
            
            diffRect.origin.y = y;
        }
        CGImageRelease(resizeImageRef);
        
    } else
#endif
    {
        diffImageRef = resizeImageRef;
    }
    
    
    // (4) --- make jpeg image
    if( diffImageRef != nil) {
        CFMutableDataRef cfdata = CFDataCreateMutable(nil,0);
        CGImageDestinationRef dest = CGImageDestinationCreateWithData(cfdata, kUTTypeJPEG, 1, NULL);
        CGImageDestinationAddImage(dest, diffImageRef, qualityDic);
        if(!CGImageDestinationFinalize(dest))
        {
            CGImageRelease(diffImageRef);
            CFRelease(dest);
            CFRelease(cfdata);
            DDLogError(@"Image Processing Error...transform failed");
            return; //continue; // error
        }
        CFRelease(dest);
        
        CFIndex len = CFDataGetLength(cfdata);
        //copy data
        unsigned char* m_image = malloc(len);
        CFDataGetBytes (cfdata, CFRangeMake(0,len), m_image);
        
        CFRelease(cfdata);
        cfdata = nil;
        
        
        // (5) --- Process output data (send or preview)
        NSData *output = [NSData dataWithBytes:m_image length:len];
//        {
//            static int nCount = 0;
//            NSString * managerDirectory = [Utility managerDirectory];
//            NSString * firstImageFullPath = [NSString stringWithFormat:@"%@/%d_%@",managerDirectory, ++nCount, @"test.jpg"];
//            [output writeToFile:firstImageFullPath atomically:YES];
//        }
        
        if( [self.customDelegate respondsToSelector:@selector(processCapturedImage:rect:bRotate:isKeyFrame:)] ) {
            [self.customDelegate processCapturedImage:output rect:diffRect bRotate:bNeedRotate isKeyFrame:bIsKeyFrame];
        }
        
        free(m_image);
    } else {
        DDLogInfo(@"Skip same image");
//        [self calcFPS];
    }
}


@end


#pragma mark -
#pragma mark - <QuickTimeScreenCapture>
@implementation QuickTimeScreenCapture

@end














