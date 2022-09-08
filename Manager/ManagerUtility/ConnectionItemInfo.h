//
//  ConnectionItemInfo.h
//  Manager
//
//  Created by User on 6/30/15.
//  Copyright (c) 2015 tomm. All rights reserved.
//

#import <Foundation/Foundation.h>

/*======== 디바이스별 비율 정보 =========
 iPhone4,5,6 = 2.0
 iPhone6+ = 3.0
 iPad1,2, mini = 1.0
 iPad Air, mini레티나 = 2.0
 */

@class SERemoteWebDriver;
@class SETouchAction;
@class DeviceLog;
@class DeviceInfos;

@protocol ConnectionItemInfoDelegate;

@interface ConnectionItemInfo : NSObject
{
    __weak id<ConnectionItemInfoDelegate> customDelegate;
    
    NSDictionary * dicKorTokens;
}

@property (nonatomic, weak) id<ConnectionItemInfoDelegate> customDelegate;
@property (nonatomic, strong) DeviceInfos   * deviceInfos;

@property (nonatomic, readonly, assign) int           connectType; // 0 : disconnect, 1 : manual connection, 2 : automation connct
@property (nonatomic, assign) BOOL          bInstalling;

@property (nonatomic, strong) DeviceLog     * myDeviceLog;
@property (nonatomic, strong) NSDictionary  * dicKorTokens;
//@property (nonatomic, strong) NSDictionary  * dicAgentInfos;
@property (nonatomic, strong) NSString  * agentBuild;

//LOG
@property (nonatomic, strong) NSTask *logTask;
@property (nonatomic, strong) id    pipe;
@property (nonatomic, strong) id    pipeNotiObserver;
//



//==== Start/Stop Appium
- (void)startAgentManual:(BOOL)isManual;
- (void)stopAgent;

//==== Manage Touch Event
- (void)doTouchStartAtX:(int)argX andY:(int)argY;
- (void)doTouchMoveAtX:(int)argX andY:(int)argY;
- (void)doTouchEndAtX:(int)argX andY:(int)argY;

- (void) doMultiTouchStartAtPoint1:(NSPoint)point1 andPoint2:(NSPoint)point2;
- (void) doMultiTouchMoveAtPoint1:(NSPoint)point1 andPoint2:(NSPoint)point2;
- (void) doMultiTouchEndAtPoint1:(NSPoint)point2 andPoint2:(NSPoint)point2;

- (void)doTapAtX:(float)argX andY:(float)argY;
- (void)doSwipeAtX1:(int)argX1 andY1:(int)argY1 andX2:(int)argX2 andY2:(int)argY2;
//==== Log
- (void)startLogSearch:(NSString *)search identifier:(NSString* )identifier level: (char)level;
- (void)stopLog;
//====
- (void)hardKeyEvent:(int)nKey longpress:(int)nType andReturn:(BOOL)bResponse;
//=====
- (void)uploadDumpFile:(NSString*)url;
//=====
- (void)autoInputText:(NSData *)data;
- (void)automationSearch:(NSData *)data andSelect:(BOOL)bSelect;
- (void)likeSearch:(NSData *)data andSelect:(BOOL)bSelect;

- (void)autoOrientation:(BOOL)bLand;
- (void)autoRunApp:(NSString *)bundleId;
- (void)inputTextByString:(NSString *)string;
- (void)inputRemoteKeyboardByKey:(NSData *)key;
//====
- (void)installApplication:(NSString*)path;
- (void)registerFileNotificationWithSuccess:(NSString *)sucName andFailed:(NSString *)failName;

- (void) lockSetting:(NSData *)packet;

//==== 연결상태 확인
- (BOOL)deviceGetStatus;

//===== 초기화
- (BOOL)removeApp:(NSString *)appId; //mg//20180509//uninstall
- (BOOL)removeInstalledApp:(BOOL)CMDCLEAR;
- (void) clearProcess:(NSString*)udid andLog:(BOOL)bLogClear;
- (void)resetDevice;

- (BOOL)terminateActiveApp;

- (void)terminateApp;

/// @brief  앱리스트 정보를 구성한다.
- (NSString *)getMyAppListForStart;

- (id)getAppListForDevice:(BOOL)remove;
//- (NSString*)getAppInstallListForDevice:(BOOL)remove;

//=====x
- (void) initUSBConnect;
- (void) initDeviceLog;
- (void) startIProxy;
- (void) initialize;

//== 웹 호출
- (void)sendOpenURL:(NSString *)url;

//mg//- (void) sendResourceMornitorCommand:(NSString *)cmd;
- (void) sendResourceMornitorCommand:(NSString *)cmd autoConnect:(BOOL)connect;//mg//재연결 옵션 추가//

//== App Name 호출
-(NSString *)getInstallAppName;
-(NSString *)getAppName;
-(NSString *)getLaunchBundleId;


- (void) startDetachTimer ;
- (void) stopDetachTimer ;

//- (NSString *)getPageSouece ;

-(void)launchResource;

@end

@protocol ConnectionItemInfoDelegate <NSObject>
@required
- (void) didCompletedGetDeviceInfos:(NSString *)udid;
- (void) didCompletedDetachDevice:(NSNumber *)usbNumber;
@end





