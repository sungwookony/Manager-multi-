//
//  CommunicatorWithVPS.h
//  Manager
//
//  Created by SR_LHH_MAC on 2017. 8. 23..
//  Copyright © 2017년 tomm. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ControlAgent;
@class DeviceInfos;

@interface CommunicatorWithVPS : NSObject

@property (nonatomic, strong) DeviceInfos       * myDeviceInfos;

- (id) initWithCaptureMode:(NSString *)captureMode withDeviceInfos:(DeviceInfos *)deviceInfo withControlAgent:(ControlAgent *)controlAgent;

- (void) startVPSSocketServer;

@end
