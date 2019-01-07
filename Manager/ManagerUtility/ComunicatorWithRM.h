//
//  ComunicatorWithRM.h
//  ResourceMornitor
//
//  Created by SR_LHH_MAC on 2016. 5. 3..
//  Copyright © 2016년 onycom1. All rights reserved.
//

@class ViewController;
@protocol ResourceMornitorDelegate;

@interface CommunicatorWithRM : NSObject {
    
    __weak id<ResourceMornitorDelegate> customDelegate;
    ViewController * mainViewCtrl;
}

@property (nonatomic, strong) ViewController * mainViewCtrl;
@property (nonatomic, weak) id<ResourceMornitorDelegate> customDelegate;

+ (CommunicatorWithRM *)sharedRMInterface;
- (void)startInterfaceWithRM;
- (BOOL)sendCommand:(const NSString *)cmd withDeviceID:(int)deviceID;

@end

@protocol ResourceMornitorDelegate <NSObject>
@required
- (void) recvdResourcePacket:(NSData *)packet andDeviceNo:(int)deviceNo;
@end
