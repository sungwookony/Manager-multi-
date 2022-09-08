//
//  CommProcessorWDC.h
//  Manager
//
//  Created by User on 6/29/15.
//  Copyright (c) 2015 tomm. All rights reserved.
//

#import <Foundation/Foundation.h>



@class DeviceInfos;
@class MainViewController;

@interface CommunicatorWithDC : NSObject
@property (nonatomic, weak)     MainViewController *mainController;

@property (nonatomic, assign) NSString* devUdid;

+ (CommunicatorWithDC *)sharedDCInterface;
- (BOOL)startInterfaceWithDC;
- (BOOL)disconnectSocket;
- (void)connectSocket:(int)nNumber andPort:(int)nValue;

//- (void)sendLogData:(NSData *)argLogPacket;
- (void)sendLogData:(NSData *)argLogPacket deviceNo:(int)argDeviceNo ;
- (void)commonResponse:(BOOL)bSueccss deviceNo:(int)argDeviceNo;
- (void)commonResponse:(BOOL)bSueccss reqCmd:(int)cmd msg:(NSString *)msg deviceNo:(int)argDeviceNo;
- (void)commonResponseClassIndex:(BOOL)bSueccss elemLabel:(NSString*)label deviceNo:(int)argDeviceNo;
- (void)commonResponseClear:(BOOL)bSuccss msg:(NSString *)argMsg deviceNo:(int)argDeviceNo;
- (void)commonResponseForInstall:(BOOL)bSueccss appId:(NSString*)bundleId deviceNo:(int)argDeviceNo;
- (void)responseDeviceDisconnected:(int)argDeviceNo;
- (void)sendResponse:(BOOL)bSueccss message:(NSString*)msg deviceNo:(int)no;//mg//


- (NSString *)udidByDeviceNo:(int)argDeviceNo;
- (dispatch_queue_t)getDispatchQueue:(int)deviceNo;
- (dispatch_semaphore_t)getSemaphore:(int)deviceNo; // add by leehh

- (void) recvdResourcePacket:(NSData *)packet andDeviceNo:(int)deviceNo;
- (void) sendDeviceChange:(int)type withInfo:(DeviceInfos *)deviceInfo andDeviceNo:(int)argDeviceNo;

-(void)restartCheck;
-(void)dcDisconnect;

@end
