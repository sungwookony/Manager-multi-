//
//  AppiumControlAgent.m
//  Manager
//
//  Created by SR_LHH_MAC on 2017. 7. 31..
//  Copyright © 2017년 tomm. All rights reserved.
//

#import "AppiumControlAgent.h"
#import "TaskHandler.h"
#import "Selenium.h"
#import "Utility.h"

@interface AppiumControlAgent() <SERemoteWebDriverDelegate, PipeHandlerDelegate>

@property (nonatomic, strong) NSTask        * myAppiumTask;

@property (nonatomic, strong) PipeHandler   * appiumHandler;
@property (nonatomic, strong) PipeHandler   * appiumErrorHandler;

@property (nonatomic, strong) SERemoteWebDriver * myWebDriver;
@property (atomic, strong) dispatch_queue_t  webPerformQueue;

@property (nonatomic, assign) int           nAppiumConnectCount;
@property (nonatomic, assign) int           nAppiumReConnectCount;

@property (nonatomic, assign) int           myAppiumPortNo;
@property (nonatomic, assign) int           myProxyPort;

@property (nonatomic, assign) int           remoteKeyType;
@property (nonatomic, assign) BOOL          bStartDone;


// Touch Action
@property (nonatomic, strong) SETouchAction * myMoveTouch;
@property (nonatomic, assign) int           prevX;
@property (nonatomic, assign) int           prevY;
@property (nonatomic, assign) CGFloat       preDistance;
@property (nonatomic, assign) BOOL          bMoving;
@property (nonatomic, strong) NSTimer       * movingTimer;

@end


/// @brief  Appium 을 실행하여 App 을 설치한뒤 제어한다.
@implementation AppiumControlAgent

/// @brief  초기화
- (id) init {
    
    self = [super init];
    if( self ) {
        _myWebDriver = nil;
        
        _myAppiumTask = nil;
        _appiumHandler = nil;
        _appiumErrorHandler = nil;
        
        _bMoving = NO;
        _preDistance = 0.0f;
        
        self.myAppiumPortNo = 4724;
        self.myProxyPort = 27755;
        
        _remoteKeyType = REMOTE_KEY_NONE;
        
        [self createDispatchWebPerformQueue];
    }
    
    return self;
}

- (void) dealloc {
    self.webPerformQueue = nil;
}

#pragma mark - <Timer>
- (void) onMovingTimer:(NSTimer *)theTimer {
    
    __block __typeof__(self) blockSelf = self;
    dispatch_sync(self.webPerformQueue, ^{
        blockSelf.bMoving = NO;
    });
}

#pragma mark - <PipeHnaler Delegate>
/// @brief  Task 에서 실시간으로 문자열을 읽어들여 호출되는 Delegate
/// @param readData 읽어들인 문자열
/// @param handler  문자열을 발생시킨 핸들러.. 문자열 발생 주체를 알아내기 위해 사용함.
- (void) readData:(NSData *)readData withHandler:(const PipeHandler *)handler {
    
    if( handler == _appiumHandler ) {                       // 성공...
        NSString *outStr = [[NSString alloc] initWithData:readData encoding:NSUTF8StringEncoding];
        
//        if( !self.bLaunchDone ) {
            DDLogWarn(@"AppiumLog(%d): %@", deviceInfos.deviceNo, outStr);
        
            dispatch_async(dispatch_get_main_queue(), ^{
                // code here
                [[NSNotificationCenter defaultCenter] postNotificationName:APPIUM_LOG object:outStr userInfo:nil];
            });
//        }
        
        // Appium 사용할 준비가 됐다.
        if( !self.bStartDone ) {
            NSRange the_range = [outStr rangeOfString:@"Appium REST http interface listener started " options:NSCaseInsensitiveSearch];
            if (the_range.location != NSNotFound) {
                //                    NSLog(@"AppiumLog(%d): node start done ", self.deviceNo);
                self.bStartDone = YES;
                
#ifdef DEBUG
                DDLogWarn(@"[#### Info ####] End!! Appium Connect!! -- successed !! -- device No -- %d", deviceInfos.deviceNo);        // add by leehh 확인로그
                DDLogWarn(@"###############################################################\n\n\n\n");                          // add by leehh
#endif
                if( [self.customDelegate respondsToSelector:@selector(agentCtrlLaunchSuccessed)] ) {
                    [self.customDelegate agentCtrlLaunchSuccessed];         
                }
            }
        }
    } else if( handler == _appiumErrorHandler ) {
        // 예외 발생.. 에러에 대한 예외 처리
        NSString *outStr = [[NSString alloc] initWithData:readData encoding:NSUTF8StringEncoding];
        DDLogWarn(@"AppiumLog(%d): error task - %@", deviceInfos.deviceNo, outStr);
        
        NSRange sessionFail = [outStr rangeOfString:@"Failed to start an Appium session" options:NSCaseInsensitiveSearch];
        NSRange serverFail = [outStr rangeOfString:@"Couldn't start Appium REST http interface listener" options:NSCaseInsensitiveSearch];
        
        if (serverFail.location != NSNotFound) {
            [self performSelectorInBackground:@selector(finishControlAgent) withObject:nil];
        } else if(sessionFail.location != NSNotFound) {
            
        }
        
#ifdef DEBUG
        DDLogWarn(@"[#### Info ####] End!! Appium Connect!! -- Failed !! -- device No -- %d", deviceInfos.deviceNo);           // add by leehh 확인로그
        DDLogWarn(@"###############################################################\n\n\n\n");                          // add by leehh
#endif
        
        if( [self.customDelegate respondsToSelector:@selector(agentCtrlLaunchFailed)] ) {
            [self.customDelegate agentCtrlLaunchFailed];
        }
    }
}

#pragma mark - <SERemoteWebDriverDelegate>
/// @brief  Appium 에 명령을 보냈는데 일정시간 응답이 없어 예외 처리하며, DeviceDisconnect 를 DC 로 전달하면
/// @brief  WebClient는 Popup 을 띄워 사용자에게 알려주고, DC 는 Manager에 Stop 을 보내 정리하는 과정을 거치게 된다.
- (void) onTimeOutOfExecScript {
    DDLogWarn(@"%s, %d", __FUNCTION__, deviceInfos.deviceNo);
    [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:deviceInfos.deviceNo];
}

#pragma mark - <User Functions>

- (void) createDispatchWebPerformQueue {
    if( self.webPerformQueue ) {
        self.webPerformQueue = nil;
    }
    
    self.webPerformQueue = dispatch_queue_create("WEB_PERFORM_QUEUE", NULL);
}

//Appium 서버실행이 완료된 후에 WebDriver 실행 후 인스톨 결과 전송.
//예약테스트의 경우, 인스톨 완료시 스크립트가 바로 전송되기 때문에 세션 연결 완료 후에 인스톨 결과를 전송.
/// @brief  사용하지 않음.
- (void)waitForServerStartWithAppAndResp {
    DDLogWarn(@"%s, %d", __FUNCTION__, deviceInfos.deviceNo);
    //Appium 접속 시도가 10번이 되면 취소한다.
    if(_nAppiumConnectCount == 200){
        [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:NO appId:@"Appium 접속 실패" deviceNo:deviceInfos.deviceNo];
        return;
    }
    _nAppiumConnectCount += 1;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 *NSEC_PER_SEC)), [[CommunicatorWithDC sharedDCInterface] getDispatchQueue:deviceInfos.deviceNo], ^{
        if(self.bStartDone){
            DDLogWarn(@"bStartDone for Reservation");
            [self setupWebDriverWithApp];
//            [[CommunicatorWithDC sharedDCInterface] commonResponse:YES deviceNo:self.deviceNo];
            [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:YES appId:self.launchBundleId deviceNo:deviceInfos.deviceNo];
        } else {
            DDLogWarn(@"wait for start done");
            [self waitForServerStartWithAppAndResp];
        }
    });
}

/// @brief  Appium 서버실행이 완료될때 까지 0.3초마다 재귀호출을 통해 반복하다가 완료되면 Appium 을 통해 다운로드한 App 을 iPhone 에 설치 및 실행을 한다.
/// @brief  60초가 지나면 예외 처리로 실패 처리가 된다.
- (void)waitForServerStartWithApp {
    DDLogWarn(@"%s, %d", __FUNCTION__, deviceInfos.deviceNo);
    //Appium 접속 시도가 10번이 되면 취소한다.
    if(_nAppiumConnectCount == 200){
        [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:NO appId:@"Appium 접속 실패" deviceNo:deviceInfos.deviceNo];
        return;
    }
    _nAppiumConnectCount += 1;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 *NSEC_PER_SEC)), [[CommunicatorWithDC sharedDCInterface] getDispatchQueue:deviceInfos.deviceNo], ^{
        if(self.bStartDone){
            DDLogWarn(@"bStartDone For Script");
            [self setupWebDriverWithApp];
        } else {
            DDLogWarn(@"waitForServerStartWithApp");
            [self waitForServerStartWithApp];
        }
    });
}

/// @brief Appium 서버실행이 완료될때 까지 0.3초 마다 재귀호출을 통해 반복하다가 완료되면 Appium 에 BundleID 를 넣어 iPhone 에 설치되어있는 앱을 실행하게 한다.
/// @brief 60초가 지나면 예외처리로 실패 처리가 된다.
- (void)waitForServerStartWithBundleId {
    DDLogWarn(@"%s, %d", __FUNCTION__, deviceInfos.deviceNo);
    //Appium 접속 시도가 200번이 되면 취소한다.
    if(_nAppiumConnectCount == 200){
        [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:NO appId:@"Appium 접속 실패" deviceNo:deviceInfos.deviceNo];
        return;
    }
    _nAppiumConnectCount += 1;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 *NSEC_PER_SEC)), [[CommunicatorWithDC sharedDCInterface] getDispatchQueue:deviceInfos.deviceNo], ^{
        if(self.bStartDone){
            DDLogWarn(@"bStartDone For Script");
            [self setupWebDriverWithBundleId];
        } else {
            DDLogWarn(@"waitForServerStartWithBundleId");
            [self waitForServerStartWithBundleId];
        }
    });
}

//- (void) waitForResourceMornitorLaunch {
//    DDLogInfo(@"%s -- deviceNo : %d", __FUNCTION__, deviceInfos.deviceNo);
//
//    if( nResourceMornitorConnectCount == 10 ) {             // 2초
//        DDLogInfo(@"ResourceMornitroApp 연결 실패!!");
//        return ;
//    }
//
//    if( NO == self.bConnectedResourceApp ) {
//        ++nResourceMornitorConnectCount;
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//            [_cmtIProxy connectResourceMornitor];
//            [self waitForResourceMornitorLaunch];
//        });
//    }
//}

#pragma mark -
#pragma mark Appium Start and Launch

/// @brief  Appium 을 실행하기 전에 셋팅을한다.
- (void)settingBeforeLaunch {
    // 정리하는 과정을 선 진행함.
    [self finishControlAgent:nil];
    [Utility killListenPort:self.myAppiumPortNo exceptPid:getpid()];
    [self removePipe];
    
    self.myAppiumPortNo = deviceInfos.appiumPort;
    self.myProxyPort = deviceInfos.appiumProxyPort;
}

/// @brief  Appium 서버 셋팅 및 실행한다. (appium로그를 받아오기 위해 별도 함수로 실행)
/// @see https://github.com/appium/appium/blob/master/docs/en/writing-running-appium/caps.md 을 참고하시길..
- (void)launchControlAgent {
    DDLogWarn(@"%s, %d", __FUNCTION__, deviceInfos.deviceNo);              // add by leehh
//    [self finishControlAgent];
//    [Utility killListenPort:self.myAppiumPortNo exceptPid:getpid()];
    
    int nIproxyPort = WDA_LOCAL_PORT + deviceInfos.deviceNo;
    
    NSString *thePortNo = [NSString stringWithFormat:@"%d", self.myAppiumPortNo];
    NSString * strCapabilities = [NSString stringWithFormat:@"{\"udid\":\"%@\", \"automationName\":\"XCUITest\", \"wdaLocalPort\":%d, \"fullReset\":true}", deviceInfos.udid, nIproxyPort];
    
    self.myAppiumTask = [[NSTask alloc] init];
    self.myAppiumTask.launchPath = @"/bin/bash";
    NSString* commandString = [NSString stringWithFormat:@"appium --default-capabilities '%@' --port %@ --command-timeout 0 --backend-retries 0",
                               strCapabilities,
                               thePortNo
                               ];
    
    self.myAppiumTask.arguments  = [NSArray arrayWithObjects:
                                    @"-l", @"-c",
                                    commandString,
                                    nil];
    
    DDLogInfo(@"%s, %d -- task Arguments : %@", __FUNCTION__, deviceInfos.deviceNo, self.myAppiumTask.arguments);
    
    _appiumHandler = [[PipeHandler alloc] initWithDelegate:self];
    _appiumErrorHandler = [[PipeHandler alloc] initWithDelegate:self];
    
    [_appiumHandler setReadHandlerForTask:self.myAppiumTask withKind:PIPE_OUTPUT];
    [_appiumErrorHandler setReadHandlerForTask:self.myAppiumTask withKind:PIPE_ERROR];
    
    //런치 하기 전에 Appium접속 시도 횟수를 0으로 초기화해준다.
    _nAppiumConnectCount = 0;
    [_myAppiumTask launch];
}

/// @brief BundleId 로 앱을 실행한다.
- (void) launchAppWithBundleID {
    if(self.bStartDone) {
        dispatch_async([[CommunicatorWithDC sharedDCInterface] getDispatchQueue:deviceInfos.deviceNo], ^(){
            [self setupWebDriverWithBundleId];
        });
    } else {
        [self waitForServerStartWithBundleId];
    }
}

/// @brief Mac 에 다운로드한 ipa 파일의 경로로 Appium 을 통해 iphone 에 ipa 파일을 설치한뒤 앱을 실행한다.
- (void) launchAppWithFilePath {
    if(self.bStartDone) {
        dispatch_async([[CommunicatorWithDC sharedDCInterface] getDispatchQueue:deviceInfos.deviceNo], ^(){
            [self setupWebDriverWithApp];
        });
    } else {
        [self waitForServerStartWithApp];
    }
}

/// @brief  Appium Session 을 다시 연결한다.
-(BOOL)reConnectAppiumSession:(NSString* )index
{
    DDLogWarn(@"%s index = %@",__FUNCTION__,index);
    [self clearAppiumSession];
    
    self.myWebDriver = [[SERemoteWebDriver alloc] initWithServerAddress:@"127.0.0.1" port:self.myAppiumPortNo];
    self.myWebDriver.customDelegate = self;
    
    SECapabilities *theCapabilities = [[SECapabilities alloc] init];
    
    // for Device
    [theCapabilities addCapabilityForKey:@"platformName" andValue:@"iOS"];
    [theCapabilities addCapabilityForKey:@"platformVersion" andValue:deviceInfos.productVersion];
    [theCapabilities addCapabilityForKey:@"deviceName" andValue:self.deviceInfos.deviceName];
    [theCapabilities addCapabilityForKey:@"udid" andValue:deviceInfos.udid];
    [theCapabilities addCapabilityForKey:@"app" andValue:self.installPath];
//    [theCapabilities addCapabilityForKey:@"launchTimeout" andValue:@"40000"];
//    [theCapabilities addCapabilityForKey:@"waitForAppScript" andValue:@"$.delay(3000); $.acceptAlert(); true;"];      // Appium 에서 예외를 발생시켜 시간을 지연시킴.
    [theCapabilities addCapabilityForKey:@"fullReset" andValue:[NSNumber numberWithBool:false]];
    [theCapabilities addCapabilityForKey:@"newCommandTimeout" andValue:[NSNumber numberWithInt:0]];     // Default 60 초 자동으로 끊어짐.
    
//    [self.myWebDriver setTimeout:0 forType:SELENIUM_TIMEOUT_IMPLICIT];
    [self.myWebDriver startSessionWithDesiredCapabilities:theCapabilities requiredCapabilities:nil];
    
    if ((self.myWebDriver == nil) || (self.myWebDriver.session == nil) || (self.myWebDriver.session.sessionId == nil)) {
        //        return NO;
        _nAppiumReConnectCount += 1;
        NSString* count = [NSString stringWithFormat:@"%d",_nAppiumReConnectCount];
        
        if(_nAppiumReConnectCount == 10)
        {
            _nAppiumReConnectCount = 0;
            return NO;
        }else{
            //접속 재시도 1안
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 *NSEC_PER_SEC)), [[CommunicatorWithDC sharedDCInterface] getDispatchQueue:deviceInfos.deviceNo], ^{
                DDLogWarn(@"접속시도 %@ 번째",count);
                [self reConnectAppiumSession:count];
            });
            //접속 재시도 2안
//            [self performSelector:@selector(reConnectAppiumSession:) withObject:count afterDelay:5];
        }
        return NO;
    }

    _nAppiumReConnectCount = 0;
    return YES;
}

//자동화를 위한 WebDriver 연결. - For App
/// @brief  Appium의 Desired Capabilities 를 설정한뒤 ipa 파일로 iphone 에 앱을 설치하여 실행한다.
- (BOOL)setupWebDriverWithApp {
#ifdef DEBUG
    DDLogWarn(@"#########  %s, %d", __FUNCTION__, deviceInfos.deviceNo);
#endif
    [self clearAppiumSession];
    
    self.myWebDriver = [[SERemoteWebDriver alloc] initWithServerAddress:@"127.0.0.1" port:self.myAppiumPortNo];
    self.myWebDriver.customDelegate = self;
    
    SECapabilities *theCapabilities = [[SECapabilities alloc] init];
    
    // for Device
    //    [theCapabilities addCapabilityForKey:@"automationName" andValue:@"Appium"];
    [theCapabilities addCapabilityForKey:@"automationName" andValue:@"XCUITest"];
    [theCapabilities addCapabilityForKey:@"sendKeyStrategy" andValue:@"setValue"];
    [theCapabilities addCapabilityForKey:@"platformName" andValue:@"iOS"];
    [theCapabilities addCapabilityForKey:@"platformVersion" andValue:self.deviceInfos.productVersion];
    [theCapabilities addCapabilityForKey:@"deviceName" andValue:self.deviceInfos.deviceName];
    [theCapabilities addCapabilityForKey:@"udid" andValue:self.deviceInfos.udid];
    [theCapabilities addCapabilityForKey:@"app" andValue:self.installPath];
    [theCapabilities addCapabilityForKey:@"fullReset" andValue:[NSNumber numberWithBool:false]];
    [theCapabilities addCapabilityForKey:@"useNewWDA" andValue:[NSNumber numberWithBool:YES]];
    //    [theCapabilities addCapabilityForKey:@"showXcodeLog" andValue:[NSNumber numberWithBool:true]];
    [theCapabilities addCapabilityForKey:@"newCommandTimeout" andValue:[NSNumber numberWithInt:0]];     // Default 60 초 자동으로 끊어짐.
    //    [theCapabilities addCapabilityForKey:@"launchTimeout" andValue:@50000];
    [theCapabilities addCapabilityForKey:@"wdaLocalPort" andValue:[NSNumber numberWithInt:WDA_LOCAL_PORT+deviceInfos.deviceNo]];     // UsbMuxd 에서 사용할 TCP Port 번호
    [theCapabilities addCapabilityForKey:@"iosInstallPause" andValue:@500];        // Install 후 0.5초뒤 시작.
    [theCapabilities addCapabilityForKey:@"waitForQuiescence" andValue:@NO];
    //    [theCapabilities addCapabilityForKey:@"preventWDAAttachments" andValue:@YES];
    
    [self.myWebDriver startSessionWithDesiredCapabilities:theCapabilities requiredCapabilities:nil];
    
    if ((self.myWebDriver == nil) || (self.myWebDriver.session == nil) || (self.myWebDriver.session.sessionId == nil)) {
        
        [self clearAppiumSession];
        
        if(self.myWebDriver == nil)
        {
            DDLogError(@"WebDriver 연결 실패");
        }
        else if(self.myWebDriver.session == nil)
        {
            DDLogError(@"session 연결 실패");
        }
        else if(self.myWebDriver.session.sessionId == nil)
        {
            DDLogError(@"session Id nil 값");
        }
        
        // 실패
        DDLogError(@" %s, %d -- Could not start a new session............", __FUNCTION__, deviceInfos.deviceNo);
//        self.launchBundleId = nil;
//        self.installPath = nil;
        
        if( [self.customDelegate respondsToSelector:@selector(applicationLaunchFailed:)] ) {
            // Appium 인 경우 (시작을 App 설치하면서 함) App 설치 실패시 DeviceDisconnect 를 보내줌..
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0f *NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:deviceInfos.deviceNo];
            });
            [self.customDelegate applicationLaunchFailed:@"Appium 연결 실패"];
        }
        
        return NO;
    }
    
    // 성공
    DDLogWarn(@"%s, %d   -- END !!", __FUNCTION__, deviceInfos.deviceNo);
    self.bLaunchDone = YES;
    
    if( [self.customDelegate respondsToSelector:@selector(applicationLaunchSuccessed)] ) {
        [self.customDelegate applicationLaunchSuccessed];
    }
    
    // SessionID 가 있어야 해서 WebDriver 연결 성공후 설정하도록 수정함..
    //    [self.myWebDriver setTimeout:0 forType:SELENIUM_TIMEOUT_IMPLICIT];          // Default 값이 0임..
    //    [self.myWebDriver setTimeout:8000 forType:SELENIUM_TIMEOUT_SCRIPT];         // 8초
    //    [self.myWebDriver setTimeout:8000 forType:SELENIUM_TIMEOUT_PAGELOAD];       // 8초
    return YES;
}

//자동화를 위한 WebDriver 연결.- For BundleId
/// @brief  Appium의 Desired Capabilities 를 설정한뒤 iphone 에 설치된 앱의 BundleID 로 앱을 실행한다.
- (BOOL)setupWebDriverWithBundleId {
    
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, deviceInfos.deviceNo);
#endif
    //Appium 세션 연결 종료
    [self clearAppiumSession];
    
    self.myWebDriver = [[SERemoteWebDriver alloc] initWithServerAddress:@"127.0.0.1" port:self.myAppiumPortNo];
    self.myWebDriver.customDelegate = self;
    
    SECapabilities *theCapabilities = [[SECapabilities alloc] init];
    
    DDLogWarn(@"%s, %d -- bundleId %@", __FUNCTION__, deviceInfos.deviceNo, self.launchBundleId);
    // for Device
    [theCapabilities addCapabilityForKey:@"automationName" andValue:@"XCUITest"];
    [theCapabilities addCapabilityForKey:@"platformName" andValue:@"iOS"];
    [theCapabilities addCapabilityForKey:@"platformVersion" andValue:deviceInfos.productVersion];
    [theCapabilities addCapabilityForKey:@"deviceName" andValue:self.deviceInfos.deviceName];
    [theCapabilities addCapabilityForKey:@"udid" andValue:self.deviceInfos.udid];
    [theCapabilities addCapabilityForKey:@"bundleId" andValue:self.launchBundleId];
    [theCapabilities addCapabilityForKey:@"fullReset" andValue:[NSNumber numberWithBool:false]];
    [theCapabilities addCapabilityForKey:@"useNewWDA" andValue:[NSNumber numberWithBool:YES]];
    
    [theCapabilities addCapabilityForKey:@"newCommandTimeout" andValue:[NSNumber numberWithInt:0]];     // Default 60 초 자동으로 끊어짐.
    [theCapabilities addCapabilityForKey:@"wdaLocalPort" andValue:[NSNumber numberWithInt:WDA_LOCAL_PORT+deviceInfos.deviceNo]];     // UsbMuxd 에서 사용할 TCP Port 번호
    [theCapabilities addCapabilityForKey:@"waitForQuiescence" andValue:@NO];
    
    [self.myWebDriver startSessionWithDesiredCapabilities:theCapabilities requiredCapabilities:nil];
    
    //Appium 연결 실패 ,세션연결실패
    if ((self.myWebDriver == nil) || (self.myWebDriver.session == nil) || (self.myWebDriver.session.sessionId == nil)) {
        DDLogError(@" %s, %d -- Could not start a new session............", __FUNCTION__, deviceInfos.deviceNo);
        
        if( [self.customDelegate respondsToSelector:@selector(applicationLaunchFailed:)] ) {
            [self.customDelegate applicationLaunchFailed:@"Appium 연결 실패"];
        }
        return NO;
    }
    self.bLaunchDone = YES;
    
    if( [self.customDelegate respondsToSelector:@selector(applicationLaunchSuccessed)] ) {
        [self.customDelegate applicationLaunchSuccessed];
    }
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
//    // SessionID 가 있어야 해서 WebDriver 연결 성공후 설정하도록 수정함..
//    [self.myWebDriver setTimeout:0 forType:SELENIUM_TIMEOUT_IMPLICIT];          // Default 값이 0임..
//    [self.myWebDriver setTimeout:8000 forType:SELENIUM_TIMEOUT_SCRIPT];         // 8초
//    [self.myWebDriver setTimeout:8000 forType:SELENIUM_TIMEOUT_PAGELOAD];       // 8초
    
    DDLogWarn(@"%s, %d   -- END !!", __FUNCTION__, deviceInfos.deviceNo);
    return YES;
}


//메뉴얼을 위한 WebDriver 연결. com.onycom.OnycomAgent를 기준으로 실행.
/// @brief  테스트용
- (void)setupWebDriverWithAgent
{
    
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, deviceInfos.deviceNo);
#endif
    if (self.myWebDriver) {
        [self.myWebDriver quit];
        self.myWebDriver = nil;
    }
    
    self.myWebDriver = [[SERemoteWebDriver alloc] initWithServerAddress:@"127.0.0.1" port:self.myAppiumPortNo];
    self.myWebDriver.customDelegate = self;
    
    SECapabilities *theCapabilities = [[SECapabilities alloc] init];
    
    // for Device
    [theCapabilities addCapabilityForKey:@"platformName" andValue:@"iOS"];
    [theCapabilities addCapabilityForKey:@"platformVersion" andValue:self.deviceInfos.productVersion];
//    [theCapabilities addCapabilityForKey:@"app" andValue:@"/Users/onycom1/Project/UIKitCatalog.ipa"];
    [theCapabilities addCapabilityForKey:@"app" andValue:@"/Users/mac0516/Desktop/UIKitCatalog.ipa"];
    
//    [theCapabilities addCapabilityForKey:@"automationName" andValue:@"Appium"];
    [theCapabilities addCapabilityForKey:@"automationName" andValue:@"XCUITest"];
    [theCapabilities addCapabilityForKey:@"udid" andValue:self.deviceInfos.udid];
    [theCapabilities addCapabilityForKey:@"deviceName" andValue:self.deviceInfos.deviceName];
    [theCapabilities addCapabilityForKey:@"fullReset" andValue:[NSNumber numberWithBool:false]];        // clear 명령이 들어왔을 때 App 을 삭제한다.
    [theCapabilities addCapabilityForKey:@"useNewWDA" andValue:[NSNumber numberWithBool:YES]];
//    [theCapabilities addCapabilityForKey:@"showXcodeLog" andValue:[NSNumber numberWithBool:true]];
    [theCapabilities addCapabilityForKey:@"newCommandTimeout" andValue:[NSNumber numberWithInt:0]];     // Default 60 초 자동으로 끊어짐.
    [theCapabilities addCapabilityForKey:@"waitForQuiescence" andValue:@NO];
    
    
    NSError * error = nil;
    [self.myWebDriver setTimeout:0 forType:SELENIUM_TIMEOUT_IMPLICIT];
//    [self.myWebDriver setTimeout:4000 forType:SELENIUM_TIMEOUT_SCRIPT];
    [self.myWebDriver setTimeout:4000 forType:SELENIUM_TIMEOUT_PAGELOAD];
    
    [self.myWebDriver startSessionWithDesiredCapabilities:theCapabilities requiredCapabilities:nil error:&error];
    if ((self.myWebDriver == nil) || (self.myWebDriver.session == nil) || (self.myWebDriver.session.sessionId == nil)) {
#ifdef DEBUG
        DDLogError(@" %s, %d -- Could not start a new session............", __FUNCTION__, deviceInfos.deviceNo);
#endif
        
        if( [self.customDelegate respondsToSelector:@selector(applicationLaunchFailed:)] ) {
            [self.customDelegate applicationLaunchFailed:@"Appium 연결 실패"];
        }
        
        return;
    }
    
#ifdef DEBUG
    if( error.code ) {
        DDLogError(@"setupWebDriverWithAgent error -- %@", error.description);
    }
#endif
    self.bLaunchDone = YES;
    
    if( [self.customDelegate respondsToSelector:@selector(applicationLaunchSuccessed)] ) {
        [self.customDelegate applicationLaunchSuccessed];
    }

    // SessionID 가 있어야 해서 WebDriver 연결 성공후 설정하도록 수정함..
//    [self.myWebDriver setTimeout:0 forType:SELENIUM_TIMEOUT_IMPLICIT];          // Default 값이 0임..
    //    [self.myWebDriver setTimeout:8000 forType:SELENIUM_TIMEOUT_SCRIPT];         // 8초
//    [self.myWebDriver setTimeout:8000 forType:SELENIUM_TIMEOUT_PAGELOAD];       // 8초
    DDLogWarn(@"%s, %d ---- END!!", __FUNCTION__, deviceInfos.deviceNo);
}

// Appium과 WebDriver등 연결 초기화.
/// @brief  Appium Task에 연결된 Pipe Handler 를 정리한다.
- (void)removePipe {
    DDLogWarn(@"%s, %d", __FUNCTION__, deviceInfos.deviceNo);
    if( _appiumHandler ) {
        [_appiumHandler closeHandler];
        _appiumHandler = nil;
    }
    
    if( _appiumErrorHandler ) {
        [_appiumErrorHandler closeHandler];
        _appiumErrorHandler = nil;
    }
}

/// @brief Appium 을 종료한다.
- (void)clearAppiumSession {
    
    if (self.myWebDriver) {
        @try
        {
            NSError * error = nil;
            [_myWebDriver closeAppWithError:&error];
            if( error.code > 0 ) {
                DDLogError(@"[#### Info ####] closeApp error!! -- %@", [error description]);
            } else {
                DDLogWarn(@"[#### Info ####] CloseApp was Successsed !!");
            }
            
            [self.myWebDriver quitWithError:&error];
            if( error.code > 0 ) {
                DDLogError(@"[#### Info ####] quit error!! -- %@", [error description]);
            } else {
                DDLogWarn(@"[#### Info ####] quit was Successsed !!");
            }
        }
        @catch (NSException *exception)
        {
            DDLogError(@"%@", exception.description);
        }
        self.myWebDriver.customDelegate = nil;
        self.myWebDriver = nil;
        self.bLaunchDone = NO;
        
        [self createDispatchWebPerformQueue];
    }
}

/// @brief  Appium 정리 시작.
- (void)finishControlAgent:(NSDictionary *)dicBundleIds {
    DDLogWarn(@"%s, %d", __FUNCTION__, deviceInfos.deviceNo);
    
    [self clearAppiumSession];
    
    if (self.myAppiumTask) {
        __block BOOL bFinish = NO;
        @try
        {
            if( [_myAppiumTask isRunning] ) {
                __block dispatch_semaphore_t terminateSem = dispatch_semaphore_create(0);
                self.myAppiumTask.terminationHandler = ^(NSTask *task){
                    // do things after completion
                    if( terminateSem )
                        dispatch_semaphore_signal(terminateSem);
                };
                
                [self.myAppiumTask terminate];              // Not always possible. Sends SIGTERM. 항상 가능한게 아니라서 5초 동안 기다려줌.
                
                dispatch_semaphore_wait(terminateSem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0f *NSEC_PER_SEC)));
                self.myAppiumTask.terminationHandler = nil;
                [self removePipe];
                
                _nAppiumConnectCount = 0;
                
                self.bStartDone = NO;
                
                self.prevBundleId = nil;
                self.installPath = nil;
                
                
                if([self.launchBundleId isEqualToString:@"com.onycom.ResourceMornitor2"]) {
                    if( [customDelegate respondsToSelector:@selector(reLaunchResourceMornitor)] ) {
                        [customDelegate reLaunchResourceMornitor];
                    }
                }
                
                // 인스톨한 앱을 삭제한뒤 초기화 해준다.
//                self.launchBundleId = nil;
//                self.bLaunchBundleID = NO;
                
                bFinish = YES;
                
                terminateSem = nil;
                DDLogWarn(@"[#### Info ####] Appium Terminated!! -- %d", deviceInfos.deviceNo);
            }
            
            _myAppiumTask = nil;
        }
        @catch (NSException *exception)
        {
            DDLogError(@"%@", exception.description);
        }
        
        DDLogWarn(@"finishControlAgent : terminate myAppiumTask");
    }
    
    [self createDispatchWebPerformQueue];
}

/// @brief 멀티터치시 사용하며, 2개의 터치 좌표의 거리를 계산한다.
- (CGFloat) calculateDistance:(NSPoint)point1 andPoint2:(NSPoint)point2 {
    CGFloat newXPos1 = point1.x / deviceInfos.ratio;
    CGFloat newYPos1 = point1.y / deviceInfos.ratio;
    
    CGFloat newXPos2 = point2.x / deviceInfos.ratio;
    CGFloat newYPos2 = point2.y / deviceInfos.ratio;
    
    CGFloat deltaX = newXPos2 - newXPos1;
    CGFloat deltaY = newYPos2 - newYPos1;
    
    CGFloat distance = sqrt((deltaX * deltaX) + (deltaY * deltaY));
    
    return distance;
}


#pragma mark - <DC>

#pragma mark -
#pragma mark Touch Event
/// @brief 드레그 시작 좌표
- (void)doTouchStartAtX:(int)argX andY:(int)argY{
    if (!self.bLaunchDone) return;
    
    touchDate = [NSDate date];
//    NSLog(@"======= start timestamp %f ====", timestamp);
    
    CGFloat ratio = deviceInfos.ratio;
    int newArgX = argX / ratio;
    int newArgY = argY / ratio;
    
    if (self.myMoveTouch) {
        [self.myMoveTouch.commands removeAllObjects];
        self.myMoveTouch = nil;
    }
    self.myMoveTouch = [[SETouchAction alloc] init];
    [self.myMoveTouch pressAtX:newArgX y:newArgY];
    self.prevX = newArgX;
    self.prevY = newArgY;
}

/// @brief 드레그 중
- (void)doTouchMoveAtX:(int)argX andY:(int)argY {
    if (!self.bLaunchDone) return;
    
    if (!self.bLaunchDone) {
        DDLogInfo(@"%s, %d, did not launched", __FUNCTION__, deviceInfos.deviceNo);
        return;
    }
    
    if( !self.myMoveTouch ) {
        [self doTouchStartAtX:argX andY:argY];
    }
}

/// @brief 드레그 끝
- (void)doTouchEndAtX:(int)argX andY:(int)argY andAuto:(BOOL)bAuto{
    if (!self.bLaunchDone) return;
    
    if (self.myWebDriver) {
        
        NSDate * newDate = [NSDate date];
        NSTimeInterval timeInterval = [newDate timeIntervalSinceDate:touchDate];
        
        if( timeInterval < 0.5f ) {
            timeInterval = 0.5f;
        }
        
        if( timeInterval > 60.0f ) {
            timeInterval = 60.0f;
        }
        
        NSError * error = nil;
        CGFloat ratio = deviceInfos.ratio;
        int newArgX = (argX/ratio) - self.prevX;
        int newArgY = (argY/ratio) - self.prevY;
        
        // 시작과 끝의 좌표만 넣어주면 내부에서 Drag & Drop 로 처리함.
        [self.myMoveTouch waitForTimeInterval:timeInterval];
        [self.myMoveTouch moveToX:newArgX y:newArgY];
        [self.myMoveTouch withdrawTouch];
        [self.myWebDriver performTouchAction:self.myMoveTouch error:&error];
        
        if( error.code > 0 ) {
            DDLogError(@"Error : %@", error.description);
            if( 1001 == error.code ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:deviceInfos.deviceNo];
                });
            }
        }
        
        [self.myMoveTouch.commands removeAllObjects];
        self.myMoveTouch = nil;
    }
    
    self.prevX = 0;
    self.prevY = 0;
}

/// @brief 멀티터치 드레그 시작 좌표 2개
- (void) doMultiTouchStartAtPoint1:(NSPoint)point1 andPoint2:(NSPoint)point2 {
    DDLogWarn(@"======= start timestamp ====");
    if (!self.bLaunchDone) return;
    
    __block __typeof__(self) blockSelf = self;
    dispatch_async(blockSelf.webPerformQueue,  ^{
        
        if( touchDate )
            touchDate = nil;
        
        blockSelf.touchDate = [NSDate date];
        
        blockSelf.preDistance = [self calculateDistance:point1 andPoint2:point2];
        
        blockSelf.prevX = point1.x / deviceInfos.ratio;
        blockSelf.prevY = point1.y / deviceInfos.ratio;
    });
}

/// @brief 멀티터치 드레그 중 좌표 2개
- (void) doMultiTouchMoveAtPoint1:(NSPoint)point1 andPoint2:(NSPoint)point2 {
    if (!self.bLaunchDone) return;
    
    if( _preDistance > 0.0f && touchDate ) {
        
    } else {
        [self doMultiTouchStartAtPoint1:point1 andPoint2:point2];
    }
}

/// @brief 멀티터치 드레그 끝 좌표 2개
- (void) doMultiTouchEndAtPoint1:(NSPoint)point1 andPoint2:(NSPoint)point2 {
    if (!self.bLaunchDone) return;
    
    if( _preDistance > 0.0f && touchDate ) {
        
        __block __typeof__(self) blockSelf = self;
        dispatch_async(blockSelf.webPerformQueue, ^{
            
            NSDate * newDate = [NSDate date];
            NSTimeInterval timeInterval = [newDate timeIntervalSinceDate:blockSelf.touchDate];
            
            CGFloat newDistance = [self calculateDistance:point1 andPoint2:point2];
            
            CGFloat scale = newDistance / blockSelf.preDistance;
            CGFloat velocity = scale / (CGFloat)timeInterval;
            
            CGFloat targetXPos = blockSelf.prevX;
            CGFloat targetYPos = blockSelf.prevY;
            
            if( scale < 1 ) {       // 축소       // Velocity 가 양수가 나와 음수로 보정해줌.
                velocity = -1.0f;
                if( scale < 0.02f )
                    scale = 0.02f;
            }
            
            NSError * error = nil;
            NSNumber *nbScale = [NSNumber numberWithFloat:scale];
            NSNumber *nbVelocity = [NSNumber numberWithFloat:velocity];
            
            NSNumber * nbXPos = [NSNumber numberWithFloat:(float)targetXPos];
            NSNumber * nbYPos = [NSNumber numberWithFloat:(float)targetYPos];
            
            DDLogInfo(@"[####] End  -- Scale : %f, Time Diff : %f, velocity : %f", scale, (CGFloat)timeInterval, velocity);
            
            NSDictionary * data = [NSDictionary dictionaryWithObjectsAndKeys:nbScale, @"scale", nbVelocity, @"velocity", nbXPos, @"x", nbYPos, @"y", nil];
            
            [blockSelf.myWebDriver pinch:data error:&error];
            if( error.code > 0 ) {
                DDLogError(@"Error : %@", error.description);
                if( 1001 == error.code ) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:deviceInfos.deviceNo];
                    });
                }
            }
            
            blockSelf.preDistance = 0.0f;
            blockSelf.touchDate = nil;
            blockSelf.prevX = 0;
            blockSelf.prevY = 0;
        });
    }
}

/// @brief 탭
- (void)doTapAtX:(float)argX andY:(float)argY {
    if (!self.bLaunchDone) return;
    
    float ratio = (float)deviceInfos.ratio;
    
    int newArgX = argX/ratio;
    int newArgY = argY/ratio;
    
    if (self.myWebDriver) {
        DDLogWarn(@"touch");
//        CGPoint touchPoint = CGPointMake(newArgX, newArgY);
        
        NSError * error = nil;
        // 원래 소스
        SETouchAction *theTouchAction = [[SETouchAction alloc] init];
        [theTouchAction pressAtX:newArgX y:newArgY];
        [theTouchAction waitForTimeInterval:50];
        [theTouchAction withdrawTouch];
        [self.myWebDriver performTouchAction:theTouchAction error:&error];
        if( error.code > 0 ) {
            DDLogError(@"Error : %@", error.description);
            if( 1001 == error.code ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:deviceInfos.deviceNo];
                });
            }
        }
    }
}

/// @brief 자동화 기능 Swipe
- (void)doSwipeAtX1:(int)argX1 andY1:(int)argY1 andX2:(int)argX2 andY2:(int)argY2 {
    if (!self.bLaunchDone) return;
    
    float ratio = (float)deviceInfos.ratio;
    
    float newArgX1 = argX1/ratio;
    float newArgY1 = argY1/ratio;
    float newArgX2 = argX2/ratio;
    float newArgY2 = argY2/ratio;
    
    float moveX = newArgX2 - newArgX1;
    float moveY = newArgY2 - newArgY1;
    
    if (self.myWebDriver) {
        DDLogWarn(@"siwpe");
        NSError * error = nil;
        SETouchAction *theTouchAction = [[SETouchAction alloc] init];
        [theTouchAction pressAtX:newArgX1 y:newArgY1];
        [theTouchAction waitForTimeInterval:0.5];
        [theTouchAction moveToX:moveX y:moveY];
        [theTouchAction withdrawTouch];
        [self.myWebDriver performTouchAction:theTouchAction error:&error];
        if( error.code > 0 ) {
            DDLogError(@"Error : %@", error.description);
            if( 1001 == error.code ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:deviceInfos.deviceNo];
                });
            }
        }
    }
}

/// @brief 물리 버튼 동작.  잠금화면, 볼륨조절 동작하지 않는다.
- (void)hardKeyEvent:(int)nKey longpress:(int)nType {
    if (!self.bLaunchDone) return;
    
//    NSString * script = @"";
    NSError * error = nil;
    if(nKey == 24) //volume up
    {
        [self.myWebDriver setVolume:@"UP" error:&error];
    }
    else if(nKey == 25) //volume down
    {
        [self.myWebDriver setVolume:@"DOWN" error:&error];
    }
    else if ( 91 == nKey ) {        // mute -- UIAutomation 에 없는 기능.
        return ;
    } else if ( 3 == nKey ) {       // home key
        /*
         // test Code;
         NSString * pageSource = [self.myWebDriver pageSource];
         if( pageSource.length ) {
         NSString * bundlePath = [[NSBundle mainBundle] bundlePath];
         NSString * fileFullPath = [bundlePath stringByAppendingPathComponent:@"../pageSource.xml"];
         NSData * xmlData = [pageSource dataUsingEncoding:NSUTF8StringEncoding];
         
         
         [xmlData writeToFile:fileFullPath atomically:YES];
         NSLog(@"[#### Info ####] Write To File End");
         }
         */
        return ;
    }
    
    if( error.code > 0 ) {
        DDLogError(@"Error : %@", error.description);
        if( 1001 == error.code ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:deviceInfos.deviceNo];
            });
        }
    }
}


/// @brief 문자열 입력. iphone 에 Keyboard 가 있어야 한다.
- (void)inputTextByString:(NSString *)string {
    // 기존 소스
    if (!self.bLaunchDone) return;
    
    DDLogWarn(@"CMD_INPUT_TEXT %@", string);
    __block NSError * error = nil;
    NSString * decomposition = [Utility getHangulDecomposition:string];
    SEBy *keypad = [SEBy className:@"XCUIElementTypeKeyboard"];
    SEWebElement *elemKeyboard = [self.myWebDriver findElementBy:keypad error:&error];
    if( error.code > 0 ) {
        DDLogError(@"Error : %@", error.description);
        [[CommunicatorWithDC sharedDCInterface] commonResponse:NO deviceNo:deviceInfos.deviceNo];
        if( 1001 == error.code ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:deviceInfos.deviceNo];
            });
        }
        return ;
    }else{
        [[CommunicatorWithDC sharedDCInterface] commonResponse:YES deviceNo:deviceInfos.deviceNo];
    }
    
    if (elemKeyboard != nil) {
        DDLogWarn(@"inputText not nil");
        //------- SendKeys가 비정상동작하여 script로 전달.
        
        dispatch_async(self.webPerformQueue, ^{
//            NSString* strScript = [NSString stringWithFormat:@"UIATarget.localTarget().frontMostApp().keyboard().typeString(\"%@\")", decomposition];
//            [self.myWebDriver executeAnsynchronousScript:strScript];
            [self.myWebDriver sendKeys:decomposition error:&error];
            if( error.code > 0 ) {
                DDLogError(@"Error : %@", error.description);
                if( 1001 == error.code ) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:deviceInfos.deviceNo];
                    });
                }
            }
        });
    } else {
        DDLogError(@"inputText nil");
    }
}


/// @brief RemoteKeyboard 기능 iphone 에 떠있는 키보드가 한글키보드인지 검사한뒤 한글이면 한글 토큰에서 아스키코드와 매칭되는 한글 문자를 찾아서 입력한다.
- (void)inputRemoteKeyboardByKey:(NSData *)key {
    // 기존 소스
    if (!self.bLaunchDone) return;
    
    DDLogWarn(@"CMD_INPUT_TEXT %@", key.description);
    
    // 키보드 검색
    SEBy *keypad = [SEBy className:@"XCUIElementTypeKeyboard"];
    SEWebElement *elemKeyboard = [self.myWebDriver findElementBy:keypad];
    
    if (elemKeyboard != nil) {
        DDLogWarn(@"inputText not nil");
        
        dispatch_async(self.webPerformQueue, ^{
            NSString * strToken = nil;
            uint32 * nTemp = (uint32 *)key.bytes;
            if( *nTemp > 64 && *nTemp < 91 ) {
               
                // 한글 키보드 검사
                SEBy * keyButton = [SEBy xPath:@"//XCUIElementTypeKey[@name=\"ㄱ\"]"];
                SEWebElement * item = [self.myWebDriver findElementBy:keyButton];
                if( item ) {       // 한글 키보드
                    strToken = [dicKorTokens objectForKey:key];
                }
            }
            
//            NSString* strScript = nil;
            if( !strToken.length ) {     // 영문자
                char cToken = (char)*nTemp;
                strToken = [NSString stringWithFormat:@"%c", cToken];
            }
            
            // 문자 전송
            [self.myWebDriver sendKeys:strToken];
        });
    } else {
        DDLogError(@"inputText nil");
    }
}

/// @brief 자동화 기능 텍스트 입력
- (void)autoInputText:(NSData *)data{

    SelectObject* obj = [self parsingAutoInputText:data];
    NSString *elementLabel = nil;
    bool bUseClassIndex = NO;
    @autoreleasepool {
        SEWebElement* elem = [self getElementByTargetInfo:obj];
        BOOL bRes = NO;
        
        if(elem != nil){
            bRes = [elem isDisplayed];
            if( obj.scrollType != 0 && !bRes )
            {
                bRes = [self scrollToView:elem ScrollObj:obj];
            }
            
            if( bRes )
            {
                DDLogInfo(@"autoInputText:(%@)",obj.inputText);
                [self.myWebDriver executeScript:@"env.sendKeyStrategy='setValue'"];
                [elem sendKeys:obj.inputText];
                bRes = YES;
                if( [obj.scrollClass caseInsensitiveCompare:@"Class"] == 0) {
                    bUseClassIndex = YES;
                    elementLabel = [elem attribute:@"value"];
                }
            }
        }
        
        if( bUseClassIndex) {
            [[CommunicatorWithDC sharedDCInterface] commonResponseClassIndex:bRes elemLabel:elementLabel deviceNo:deviceInfos.deviceNo];
        } else {
            [[CommunicatorWithDC sharedDCInterface] commonResponse:bRes deviceNo:deviceInfos.deviceNo];
        }
    }
}

/// @brief Orientation 설정
/// @param bLand    1 : LandScape, 0 : Protrait
- (void)autoOrientation:(BOOL)bLand {
    if (!self.bLaunchDone) return;
    
    DDLogWarn(@"== 회전 == %d",bLand);
    if(bLand){
        [self.myWebDriver setOrientation:SELENIUM_SCREEN_ORIENTATION_LANDSCAPE];
    }else{
        [self.myWebDriver setOrientation:SELENIUM_SCREEN_ORIENTATION_PORTRAIT];
    }
}

/// @brief 현재 화면의 객체정보를 XML 로 가져온다.
- (NSString *)getPageSource {
    if (!self.bLaunchDone) return nil;
    
    return [self.myWebDriver pageSource];
}

/// @brief 자동화 기능... 원래 개념은 BundleID 로 앱을 실행하는건데.. COSTEP 메니져에선 Appium 을 리셋하는걸로 되어있어서.. 미구현상태다.
/// @brief 위의 BundleID 로 앱을 실행하는 메소드를 호출해주면 될듯.
- (BOOL) autoRunApp:(NSString *)bundleId {
    [self.myWebDriver resetApp];
    
    return YES;
//    [[CommunicatorWithDC sharedDCInterface] commonResponse:YES reqCmd:CMD_RESPONSE msg:@"" deviceNo:deviceInfos.deviceNo];
}

//- (NSDictionary *)executeScript:(NSString *)script {
//    if (!self.bLaunchDone) return ;
//    NSDictionary * result = [self.myWebDriver executeScript:script];
//    return result;
//}

/// @brief 화면 이미지를 1장 가져온다.
- (NSData *)getScreenShot {
    if (!self.bLaunchDone) return nil;
    NSImage * screenShot = [_myWebDriver screenshot];
    return [screenShot TIFFRepresentation];
}

/// @brief Orientation 상태값을 가져온다.
- (int) orientation {
    return [self.myWebDriver orientation];
}

/// @brief DC 에서 들어온 객체정보로 객체를 찾아서 해당 객체가 화면에 없을때 보이도록 Scroll 을 움직인다.
- (bool) scrollToView:(SEWebElement*) elem ScrollObj:(SelectObject*)obj
{
    NSPoint pos = [elem locationInView];
    //NSSize elemsize = [elem size];
    NSString * dir;
    if(obj.scrollType == 1 ){ // vertical
        if( pos.y < 0 )
        {
            dir = @"up";
        }
        else {
            dir = @"down";
        }
    } else { // horizontal
        if( pos.x < 0 )
        {
            dir = @"left";
        }
        else {
            dir = @"right";
        }
    }
    
    int retry = obj.scrollCount;
    bool bView = false;
    do {
        NSError* error = nil;
        [self.myWebDriver executeScript:@"mobile: scroll" arguments:[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys: dir, @"direction", nil]] error:&error];
        
        if(error.code > 0){
            [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:deviceInfos.deviceNo];
        }
        
        bView = [elem isDisplayed];
//        pos = [elem locationInView];
//        pos.x = pos.x + elemsize.width /2 ;
//        pos.y = pos.y + elemsize.height /2;
//
//        if( pos.x >= 0 && pos.y >= 0 && pos.x <= screenSize.width && pos.y <= screenSize.height) {
//            bView = true;
//        }

    }
    //while (![elem isDisplayed] && retry-- > 0);
    while (!bView && retry-- > 0);
    
    return bView;
    
}

/// @brief 자동화기능.. DC 에서 넘어온 정보로 객체를 검색한다.
- (void)automationSearch:(NSData *)data andSelect:(BOOL)bSelect{
    if(!self.bLaunchDone) {
        [[CommunicatorWithDC sharedDCInterface] commonResponse:NO deviceNo:deviceInfos.deviceNo];
        return;
    }
    
    NSLog(@"automationSearch:bSelect(%d)", bSelect);
    
    SelectObject* obj = [self automationSearchParsing:data andSelect:bSelect];
    NSString *elementLabel = nil;
    bool bUseClassIndex = NO;
    @autoreleasepool {
        SEWebElement* elem = [self getElementByTargetInfo:obj];
        
        BOOL bRes = NO;
        
        if(elem != nil){
            bRes = [elem isDisplayed];
            if( obj.scrollType != 0 && !bRes )
            {
                bRes = [self scrollToView:elem ScrollObj:obj];
            }
            
            if( bRes ) {
                if(bSelect){
                    [self pressElement:elem isLong:(obj.longPress==1)? YES:NO];
                }
                bRes = YES;
                if( [obj.scrollClass caseInsensitiveCompare:@"Class"] == 0) {
                    bUseClassIndex = YES;
                    elementLabel = [elem attribute:@"value"];
                }
            }
        }
        
        if( bUseClassIndex) {
            [[CommunicatorWithDC sharedDCInterface] commonResponseClassIndex:bRes elemLabel:elementLabel deviceNo:deviceInfos.deviceNo];
        } else {
            [[CommunicatorWithDC sharedDCInterface] commonResponse:bRes deviceNo:deviceInfos.deviceNo];
        }
    }
}

/// @brief 자동화기능.. 객체 검색해서 찾은 객체에 Press 동작을 한다.
- (void)pressElement :(SEWebElement *)elem isLong:(BOOL)pressLong{
    
    DDLogInfo(@"pressElem(%d)", pressLong);
    if(pressLong){
        SETouchAction* action = [[SETouchAction alloc] init];
        [action longPressElement:elem];
        
        NSError* error = nil;
        [self.myWebDriver performTouchAction:action error:&error];
        
        if(error.code > 0){
            [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:deviceInfos.deviceNo];
        }
    }
    else{
//         [self.myWebDriver tapElement:elem];
        
        [elem click];
//        [elem click];

//        SETouchAction* action = [[SETouchAction alloc] init];
//        [action pressElement:elem];
//        [action waitForTimeInterval:0.01];
//        [action withdrawTouch];
//        [self.myWebDriver performTouchAction:action];
    }
}


#pragma mark -
#pragma mark Parsing Received Data
/// @brief 자동화 기능 문자열을 입력한다.
- (SelectObject *)parsingAutoInputText :(NSData*) data{
    
    SelectObject* obj = [[SelectObject alloc] init];
    
    int pos = 0;
    
    const uint8_t * type = (uint8_t *)[data subdataWithRange:NSMakeRange(pos, 1)].bytes;
    obj.scrollType  = type[0];
    pos = pos + 1;
    
    const uint8_t * count = (uint8_t *)[data subdataWithRange:NSMakeRange(pos, 1)].bytes;
    obj.scrollCount  = count[0];
    pos = pos + 1;
    
    
    //scroll path
    NSData *sPath = [data subdataWithRange:NSMakeRange(pos, 2)];
    short sPathSize  = CFSwapInt16HostToBig(*(short *)([sPath bytes]));
    pos = pos + 2;
    
    NSData * data1 = [data subdataWithRange:NSMakeRange(pos, sPathSize)];
    obj.scrollPath= [[NSString alloc] initWithData:data1 encoding: NSUTF8StringEncoding];
    pos = pos + sPathSize;
    
    //scroll class
    NSData *sClass = [data subdataWithRange:NSMakeRange(pos, 2)];
    short sClassSize  = CFSwapInt16HostToBig(*(short *)([sClass bytes]));
    pos = pos + 2;
    
    NSData * data2 = [data subdataWithRange:NSMakeRange(pos, sClassSize)];
    obj.scrollClass = [[NSString alloc] initWithData:data2 encoding: NSUTF8StringEncoding];
    pos = pos + sClassSize;
    
    //elem path swccc
    //    NSData *path = [data subdataWithRange:NSMakeRange(pos, 2)];
    //    short pathSize  = CFSwapInt16HostToBig(*(short *)([path bytes]));
    //    pos = pos + 2;
    
    //    NSData * data3 = [data subdataWithRange:NSMakeRange(pos, pathSize)];
    //    obj.targetPath = [[NSString alloc] initWithData:data3 encoding: NSUTF8StringEncoding];
    //    pos = pos + pathSize;
    
    NSData *pInstance = [data subdataWithRange:NSMakeRange(pos, 2)];
    obj.instance  = CFSwapInt16HostToBig(*(short *)([pInstance bytes]));
    pos = pos + 2;
    
    //elem value
    NSData *value = [data subdataWithRange:NSMakeRange(pos, 2)];
    short valueSize  = CFSwapInt16HostToBig(*(short *)([value bytes]));
    pos = pos + 2;
    
    NSData * data4 = [data subdataWithRange:NSMakeRange(pos, valueSize)];
    obj.targetValue = [[NSString alloc] initWithData:data4 encoding: NSUTF8StringEncoding];
    pos = pos + valueSize;
    
    //elem name
    NSData *name = [data subdataWithRange:NSMakeRange(pos, 2)];
    short nameSize  = CFSwapInt16HostToBig(*(short *)([name bytes]));
    pos = pos + 2;
    
    NSData * data5 = [data subdataWithRange:NSMakeRange(pos, nameSize)];
    obj.targetName = [[NSString alloc] initWithData:data5 encoding: NSUTF8StringEncoding];
    pos = pos + nameSize;
    
    //elem label
    NSData *label = [data subdataWithRange:NSMakeRange(pos, 2)];
    short labelSize  = CFSwapInt16HostToBig(*(short *)([label bytes]));
    pos = pos + 2;
    
    NSData * data6 = [data subdataWithRange:NSMakeRange(pos, labelSize)];
    obj.targetLabel = [[NSString alloc] initWithData:data6 encoding: NSUTF8StringEncoding];
    pos = pos + labelSize;
    
    //elem class
    NSData *class = [data subdataWithRange:NSMakeRange(pos, 2)];
    short classSize  = CFSwapInt16HostToBig(*(short *)([class bytes]));
    pos = pos + 2;
    
    NSData * data7 = [data subdataWithRange:NSMakeRange(pos, classSize)];
    obj.targetClass = [[NSString alloc] initWithData:data7 encoding: NSUTF8StringEncoding];
    pos = pos + classSize;
    
    //elem class
    NSData *input = [data subdataWithRange:NSMakeRange(pos, 2)];
    short inputSize  = CFSwapInt16HostToBig(*(short *)([input bytes]));
    pos = pos + 2;
    
    NSData * data8 = [data subdataWithRange:NSMakeRange(pos, inputSize)];
    obj.inputText = [[NSString alloc] initWithData:data8 encoding: NSUTF8StringEncoding];
    pos = pos + inputSize;
    
    
    DDLogInfo(@"parsingAutoInputText:longPress:%d, scrollType:%d, scrollCount:%d, scrollPath:%@, scrollClass:%@, targetPath:%@, targetValue:%@, targetName:%@, targetLabel:%@, targetClass:%@, inputText:%@", obj.longPress, obj.scrollType, obj.scrollCount, obj.scrollPath, obj.scrollClass, obj.targetPath, obj.targetValue, obj.targetName, obj.targetLabel, obj.targetClass,obj.inputText);
    
    return obj;
    
}

/// @brief DC 로 넘어온 값을 분석하여 검색할 정보를 추출한다.
- (SelectObject *)automationSearchParsing:(NSData *)data andSelect:(BOOL)bSelect{
    
    DDLogInfo(@"%s and %@ and length = %d",__FUNCTION__, data, (int)data.length);
    SelectObject* obj = [[SelectObject alloc] init];
    
    if(data.length > 0){
        int pos = 0;
        if(bSelect){
            const uint8_t * longPress = (uint8_t *)[data subdataWithRange:NSMakeRange(pos, 1)].bytes;
            obj.longPress  = longPress[0];
            pos = pos + 1;
        }
        
        const uint8_t * type = (uint8_t *)[data subdataWithRange:NSMakeRange(pos, 1)].bytes;
        obj.scrollType  = type[0];
        pos = pos + 1;
        
        const uint8_t * count = (uint8_t *)[data subdataWithRange:NSMakeRange(pos, 1)].bytes;
        obj.scrollCount  = count[0];
        pos = pos + 1;
        
        
        //scroll path
        NSData *sPath = [data subdataWithRange:NSMakeRange(pos, 2)];
        short sPathSize  = CFSwapInt16HostToBig(*(short *)([sPath bytes]));
        pos = pos + 2;
        
        NSData * data1 = [data subdataWithRange:NSMakeRange(pos, sPathSize)];
        obj.scrollPath= [[NSString alloc] initWithData:data1 encoding: NSUTF8StringEncoding];
        pos = pos + sPathSize;
        
        //scroll class
        NSData *sClass = [data subdataWithRange:NSMakeRange(pos, 2)];
        short sClassSize  = CFSwapInt16HostToBig(*(short *)([sClass bytes]));
        pos = pos + 2;
        
        NSData * data2 = [data subdataWithRange:NSMakeRange(pos, sClassSize)];
        obj.scrollClass = [[NSString alloc] initWithData:data2 encoding: NSUTF8StringEncoding];
        pos = pos + sClassSize;
        
        //elem path swccc
//        NSData *path = [data subdataWithRange:NSMakeRange(pos, 2)];
//        short pathSize  = CFSwapInt16HostToBig(*(short *)([path bytes]));
//        pos = pos + 2;
//
//        NSData * data3 = [data subdataWithRange:NSMakeRange(pos, pathSize)];
//        obj.targetPath = [[NSString alloc] initWithData:data3 encoding: NSUTF8StringEncoding];
//        pos = pos + pathSize;
        
        //객체 path 정보 대신, class 순서 사용
        NSData *pInstance = [data subdataWithRange:NSMakeRange(pos, 2)];
        obj.instance = CFSwapInt16HostToBig(*(short *)([pInstance bytes]));
        pos = pos + 2;
        
        //elem value
        NSData *value = [data subdataWithRange:NSMakeRange(pos, 2)];
        short valueSize  = CFSwapInt16HostToBig(*(short *)([value bytes]));
        pos = pos + 2;
        
        NSData * data4 = [data subdataWithRange:NSMakeRange(pos, valueSize)];
        obj.targetValue = [[NSString alloc] initWithData:data4 encoding: NSUTF8StringEncoding];
        pos = pos + valueSize;
        
        //elem name
        NSData *name = [data subdataWithRange:NSMakeRange(pos, 2)];
        short nameSize  = CFSwapInt16HostToBig(*(short *)([name bytes]));
        pos = pos + 2;
        
        NSData * data5 = [data subdataWithRange:NSMakeRange(pos, nameSize)];
        obj.targetName = [[NSString alloc] initWithData:data5 encoding: NSUTF8StringEncoding];
        pos = pos + nameSize;
        
        //elem label
        NSData *label = [data subdataWithRange:NSMakeRange(pos, 2)];
        short labelSize  = CFSwapInt16HostToBig(*(short *)([label bytes]));
        pos = pos + 2;
        
        NSData * data6 = [data subdataWithRange:NSMakeRange(pos, labelSize)];
        obj.targetLabel = [[NSString alloc] initWithData:data6 encoding: NSUTF8StringEncoding];
        pos = pos + labelSize;
        
        //elem class
        NSData *class = [data subdataWithRange:NSMakeRange(pos, 2)];
        short classSize  = CFSwapInt16HostToBig(*(short *)([class bytes]));
        pos = pos + 2;
        
        NSData * data7 = [data subdataWithRange:NSMakeRange(pos, classSize)];
        obj.targetClass = [[NSString alloc] initWithData:data7 encoding: NSUTF8StringEncoding];
        pos = pos + classSize;
        
    }
    
    DDLogInfo(@"\tSearch Parsing:longPress:%d, scrollType:%d, scrollCount:%d, scrollPath:%@, scrollClass:%@, targetPath:%@, targetValue:%@, targetName:%@, targetLabel:%@, targetClass:%@ and index = %d", obj.longPress, obj.scrollType, obj.scrollCount, obj.scrollPath, obj.scrollClass, obj.targetPath, obj.targetValue, obj.targetName, obj.targetLabel, obj.targetClass,obj.instance);
    
    //17.03.10 추가
    //XCUIElementType <--> UIA 서로 호환 되도록
    //추가 작업 필요 (예외처리)
    
    if(obj.className.length > 0){
        obj.targetClass = [self classNameForDevice:obj.targetClass];
    }
    
//
//    obj.longPress = 0;
//    obj.scrollType = 0;
//    obj.scrollCount = 3;
//    obj.scrollClass = @"Text";
//    obj.targetValue = @"Okay / Cancel";
//    obj.targetName = @"Okay / Cancel";
//    obj.targetLabel = @"Okay / Cancel";
//    obj.targetClass = @"XCUIElementTypeStaticText";
    
    DDLogInfo(@"\tSearch Parsing:longPress:%d, scrollType:%d, scrollCount:%d, scrollPath:%@, scrollClass:%@, targetPath:%@, targetValue:%@, targetName:%@, targetLabel:%@, targetClass:%@ and index = %d", obj.longPress, obj.scrollType, obj.scrollCount, obj.scrollPath, obj.scrollClass, obj.targetPath, obj.targetValue, obj.targetName, obj.targetLabel, obj.targetClass,obj.instance);
    
    return obj;
    
//    if(pos == [data length])
//    {
//        MLog(@"=====  matched data Size ======");
//        return obj;
//    }
//    else
//    {
//        return nil;
//    }
}

/// @brief  iOS 10.x 이상 버전과 iOS 9.x 이하 버전과의 호환성을 위해 접두어를 치환한다.
-(NSString *)classNameForDevice:(NSString *)className{
    
    int deviceVersion = deviceInfos.productVersion.intValue;
    NSString* temp = className;
    NSMutableString* str = [NSMutableString stringWithString:temp];
    
    if(deviceVersion >= 10.0){
        if([temp hasPrefix:@"XCUIElementType"]){
            return temp;
        }else if([temp hasPrefix:@"UIA"]){
            // TableView
            if([temp isEqualToString:@"UIATableView"]){
                NSString* strTable = @"XCUIElementTypeTable";
                return strTable;
            }else if([temp isEqualToString:@"UIAActionSheet"]){
                NSString* strActionSheet = @"XCUIElementTypeSheet";
                return strActionSheet;
            }else if([temp isEqualToString:@"UIATableCell"]){
                NSString* tableCell = @"XCUIElementTypeCell";
                return tableCell;
            }
            
            [str replaceCharactersInRange:NSMakeRange(0, 3) withString:@"XCUIElementType"];
            return str;
        }
    }else{
        if([temp hasPrefix:@"XCUIElementType"]){
            // TableView
            if([temp isEqualToString:@"XCUIElementTypeTable"]){
                NSString* strTable = @"UIATableView";
                return strTable;
            }else if([temp isEqualToString:@"XCUIElementTypeSheet"]){
                NSString* strActionSheet = @"UIAActionSheet";
                return strActionSheet;
            }else if([temp isEqualToString:@"XCUIElementTypeCell"]){
                NSString* strTableCell = @"UIATableCell";
                return strTableCell;
            }
            
            [str replaceCharactersInRange:NSMakeRange(0, 15) withString:@"UIA"];
            return str;
        }else if([temp hasPrefix:@"UIA"]){
            return temp;
        }
    }
    
    return temp;
}

/// @brief  DC 애서 넘어온 객체정보로 xPath 를 구성하여 객체를 검색한다.
- (SEWebElement *)getElementByTargetInfo:(SelectObject *)obj {
    
    SEBy* selectBy = nil;
    NSArray* arrayElem = nil;
    BOOL bUseClassIndexMethod = FALSE;
    
    BOOL bUseeSecondMethod = FALSE;
    if ((arrayElem == nil || arrayElem.count == 0) && bUseClassIndexMethod == FALSE) {
        DDLogInfo(@"try xpath method");
        
        NSMutableString * xPath = [NSMutableString stringWithFormat:@"//%@", obj.targetClass];
        
        if( obj.targetName.length || obj.targetValue.length ) {
            [xPath appendString:[NSString stringWithFormat:
                                 @"[%@ %@ %@]",
                                 (obj.targetName.length ? [NSString stringWithFormat:@"@name=\"%@\"", obj.targetName] : @""),
                                 (((obj.targetName.length > 0) && (obj.targetValue.length > 0)) ? @" and ": @""),
                                 (obj.targetValue.length ? [NSString stringWithFormat:@"@value=\"%@\"", obj.targetValue] : @"")]];
        }
        DDLogInfo(@"xPath = %@",xPath);
        selectBy = [SEBy xPath:xPath];
        arrayElem = [self.myWebDriver findElementsBy:selectBy];
    }
    
    if (arrayElem == nil || arrayElem.count==0) {
        DDLogInfo(@"findElementsBy Failed class='%@' name='%@' value='%@'", obj.targetClass, obj.targetName, obj.targetValue);
        return nil;
    } else { // filter targetClass match
        
//        long classCount = arrayElem.count;
//        int classIndex = obj.instance;
        if( bUseeSecondMethod == FALSE && arrayElem.count > 1 && bUseClassIndexMethod == FALSE) {
            DDLogInfo(@"found %lu elements", arrayElem.count);
            DDLogInfo(@"object info : name:%@, label:%@, value:%@, index:%d",
                  obj.targetName, obj.targetLabel, obj.targetValue, obj.instance);
            
            
            return [arrayElem objectAtIndex:obj.instance];
            
        } else {
            return [arrayElem objectAtIndex:0];
        }
    }
}

@end
