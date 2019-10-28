//
//  CommunicatorWithIProxy.h
//  Manager
//
//  Created by SR_LHH_MAC on 2017. 6. 4..
//  Copyright © 2017년 tomm. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CommunicatorWithIProxyDelegate;

@interface CommunicatorWithIProxy : NSObject {
    __weak id<CommunicatorWithIProxyDelegate> customDelegate;
}

@property (nonatomic, weak)   id<CommunicatorWithIProxyDelegate> customDelegate;
@property (nonatomic, assign) int       deviceNo;
@property (nonatomic, strong) NSString  * udid;

- (void) startIProxyTask;
- (void) stopIProxyTask;

- (BOOL)checkConnected;
- (void)connectResourceMornitor;
- (void)closeIProxy;
- (BOOL)sendCommand:(NSString *)cmd autoConnect:(BOOL)connect;

@end


@protocol CommunicatorWithIProxyDelegate <NSObject>
@required
- (void) didConnectedToResourceApp;
- (void) didDisconnectedFromResourceApp;
@end
