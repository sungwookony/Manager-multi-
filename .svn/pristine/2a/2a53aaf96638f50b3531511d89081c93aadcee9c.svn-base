//
//  PollingScreenshot.h
//  Manager
//
//  Created by SR_LHH_MAC on 2017. 8. 21..
//  Copyright © 2017년 tomm. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ControlAgent;
@class DeviceInfos;
@protocol ScreenCaptureDelegate;


#pragma mark - <ScreenCapture>

@interface ScreenCapture : NSObject {
    __weak id<ScreenCaptureDelegate> customDelegate;
    
    int                 jpegbFixed;
    int                 jpegFixedOrientation;
    int                 jpegFixedLonger;
    int                 jpegFixedShorter;
    int                 jpegScale;
    int                 jpegQuality;        // 1 ~ 100 (default : 70)
    CFDictionaryRef     qualityDic;
    CFStringRef         qualityKeys[1];
    CFTypeRef           qualityValues[1];
    
    int                 devOrientation;
    
    NSString            * devUdid;
    
    unsigned char           * lastFrameBuffer;
}

@property (nonatomic, weak) id<ScreenCaptureDelegate> customDelegate;

@property (nonatomic, strong) DeviceInfos       * myDeviceInfos;

@property (nonatomic, assign) int               jpegbFixed;
@property (nonatomic, assign) int               jpegFixedOrientation;
@property (nonatomic, assign) int               jpegFixedLonger;
@property (nonatomic, assign) int               jpegFixedShorter;
@property (nonatomic, assign) int               jpegScale;


@property (nonatomic, strong) NSString          * devUdid;
@property (nonatomic, assign) CGSize            deviceMaxSize;
@property (nonatomic, assign) int               devOrientation;

@property (nonatomic, assign)   unsigned char           * lastFrameBuffer;

+ (ScreenCapture *) createPollingScreenCapture:(ControlAgent *)controlAget;
+ (ScreenCapture *) createQuickTimeScreenCapture;

- (void) startScreenCapture;
- (void) stopScreenCapture;
- (void) reqKeyFrame;
- (void) setQuality:(int)quality;

@end

@protocol ScreenCaptureDelegate <NSObject>
@required
- (void) processCapturedImage:(NSData *)data rect:(CGRect)rect bRotate:(BOOL)bNedRotate isKeyFrame:(BOOL)isKeyFrame;
@end


#pragma mark - <PollingScreenCapture>
@interface PollingScreenCapture : ScreenCapture

- (id) initWithControlAgent:(ControlAgent *)controlAgent;

@end


#pragma mark - <QuickTimeScreenCapture> 
@interface QuickTimeScreenCapture : ScreenCapture

@end
