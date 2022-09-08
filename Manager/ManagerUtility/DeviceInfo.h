//
//  DeviceInfo.h
//  Manager
//
//  Created by SR_LHH_MAC on 2016. 9. 9..
//  Copyright © 2016년 tomm. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DeviceInfosDelegate;

@interface DeviceInfos : NSObject {
    __weak id<DeviceInfosDelegate>  customDelegate;
}

@property (nonatomic, weak) id<DeviceInfosDelegate> customDelegate;
@property (nonatomic, retain) NSMutableArray* arrayDeivce;

@property (nonatomic, assign) int           deviceNo;           // DeviceNo
@property (nonatomic, assign) int           appiumPort;
@property (nonatomic, assign) int           appiumProxyPort;
@property (nonatomic, assign) int           mirrorPort;
@property (nonatomic, assign) int           controlPort;

@property (nonatomic, strong) NSNumber      * usbNumber;
@property (nonatomic, strong) NSString      * udid;
@property (nonatomic, strong) NSString      * deviceClass;      //
@property (nonatomic, strong) NSString      * deviceName;
@property (nonatomic, strong) NSString      * productName;
@property (nonatomic, strong) NSString      * productType;      // 처음에 한번은 값을 가져옴..
@property (nonatomic, strong) NSString      * productVersion;
//@property (nonatomic, strong) NSNumber      * mirrorPort;
//@property (nonatomic, strong) NSNumber      * controlPort;
@property (nonatomic, strong) NSString      * xctestrun;

@property (nonatomic, assign, readonly) CGSize resolution;
@property (nonatomic, assign) CGFloat ratio;
@property (nonatomic, strong) NSString      * buildVersion;

- (void) getDeviceInfo ;
- (void) clearDeviceInfos ;
-(NSString *) buildWDAResult:(NSString* )udid;
+ (DeviceInfos *)shareDeviceInfos;
@end


@protocol DeviceInfosDelegate <NSObject>
@required
- (void) didCompletedGetDeviceInfos;
@end

