//
//  WebDriverAgent.m
//  Manager
//
//  Created by SR_LHH_MAC on 2017. 7. 31..
//  Copyright © 2017년 tomm. All rights reserved.
//

#import "WebDriverControlAgent.h"
#import "TaskHandler.h"
#import "Utility.h"
#import "AppInstaller.h"
#import "SEEnums.h"

#include <stdio.h>
#include <stdlib.h>

#define MAX_LAUNCH_TRY_COUNT        50//mg//30->50      // 30초 시도해서 실패 처리함.
#define TIMEOUT_COMMAND             20.0f   //

#define DEVICE_URL  @"http://localhost"

typedef NS_ENUM(NSUInteger, START_STATUS) {
    STATUS_NONE,
    STATUS_START,
    STATUS_READY,
    STATUS_LAUNCHED,
};

@interface WebDriverControlAgent() <PipeHandlerDelegate> {
    int nStartX,nStartY;
}

/// @brief  WebDriverAgent (WDA) 가 실행 되었는지 확인하는 타이머
@property (nonatomic, strong) NSTimer       * launchTimer;

/// @brief  WebDriverAgent (WDA) 와 통신을 하기 위한 iproxy
@property (nonatomic, strong) NSTask        * myIProxyTask;

/// @brief  WDA 를 실행하기 위한 타스크
@property (nonatomic, strong) NSTask        * myWDATask;

/// @brief  iproxy 에서 출력되는 정보를 확인하기 위한 핸들러
@property (nonatomic, strong) PipeHandler   * myIProxyHandler;

/// @brief  iproxy 에서 출력되는 예외 정보를 확인하기 위한 핸들러
@property (nonatomic, strong) PipeHandler   * myIproxyErrorHandler;

/// @brief  WDA 에서 출력되는 정보를 확인하기 위한 핸들러
@property (nonatomic, strong) PipeHandler   * myWDAHandler;

/// @brief  WDA 에서 출력되는 에외 정보를 확인하기 위한 핸들러
@property (nonatomic, strong) PipeHandler   * myWDAErrorHandler;

/// @brief  WDA 를 실행하는것에 대한 단계별 상태값
@property (nonatomic, assign) int           launchStatus;

/// @brief  WDA 와 연결할 소켓 포트번호
@property (nonatomic, assign) int           portNum;

/// @brief  WDA 가 실행되면.. Session가 리턴됨(UUID), WDA 로 앱을 실행하면.. 해당 앱에 대한 UUID 가 리턴됨.. 이렇게 WDA 는 앱마다 UUID 를 부여하여 관리하며.. 해당 UUID 로 앱을 찾아 명령을 수행함.
@property (nonatomic, strong) NSString      * sessionID;

/// @brief  WDA 실행시작.. 별의미 없음.
@property (nonatomic, assign) BOOL          bStartDone;

/// @brief  1초 단위로 WDA 실행 여부를 확인하며, 30초가 넘으면 실패처리하는데 사용함.
@property (nonatomic, assign) int           launchCount;

/// @brief  윈도우 사이즈.. 원래는 없던건데.. WebClient 에서 홈버튼이 드레그 됨.. 탭만 되어야 하는데 드레그 이벤트가 발생하는데 정상이라 함.. 다행인 점은 홈버튼 영역안에서만 발생함..
/// @brief  윈도우 영역을 벗어난 영역에서 드레그 이벤트가 발생한걸 구분하기 위해 WDA 에서 윈도우 사이즈를 리턴하도록 수정했고, 전달받아서 저장해둠.
@property (nonatomic, assign) CGSize        windowSize;

/// @brief  스레드
@property (nonatomic, strong) dispatch_queue_t  launchAppQueue;

/// @brief WDA 에 WDA 로 실행했던 앱을 종료하는 기능이 없던 시절.. 실행한 앱을 종료해주기 위해 추가했으나 지금은 필요없어 주석처리함..
- (void) clearWebDriverSession:(NSDictionary *)bundleIds;

// 실패시에 한번 더 실행하도록
@property (nonatomic, assign) BOOL          bOnce;


@end

/// @brief      홈스크린(Springboard)부터 제어하는 WebDriverAgent 와 HTTP 통신을 통해 명령을 전달한다.
@implementation WebDriverControlAgent {
    NSDate *launchTime;//mg//
}

/// @brief 초기화
- (id) init {
    self = [super init];
    if( self ) {
        touchDate = nil;
        _windowSize = CGSizeZero;
        
        _launchAppQueue = dispatch_queue_create("LaunchAppQueue", NULL);
        
    }
    return self;
}

/// @brief 정리.
- (void) dealloc {
    _launchAppQueue = nil;
}

#pragma mark - <User Functions>
/// @brief WDA 와 통신은 HTTP 프로토콜을 사용한다.
- (NSDictionary *)syncRequest:(NSDictionary *)requestData {
    DDLogDebug(@"%s", __FUNCTION__);
    
    if( !requestData )
        return nil;
    
    NSString * method = [requestData objectForKey:METHOD];          // POST, GET
    NSDictionary * dicData = [requestData objectForKey:BODY];       // body -- JSon 포멧
    NSString * command = [requestData objectForKey:CMD];            // 명령
    int nPort = [[requestData objectForKey:PORT] intValue];         // 통신 포트번호
    float timeout = [[requestData objectForKey:TIME_OUT] floatValue];   // 통신에 대한 타임아웃 값(second)
    NSString * sessionId = [requestData objectForKey:SESSION_ID];   // 앱의 UDID
    NSString * elementId = [requestData objectForKey:ELEMENT_ID];     // ELEMENT ID
    
    NSError * error = nil;
    NSString * strURL = nil;
    
    if( sessionId ) {
        if(elementId){
            strURL = [NSString stringWithFormat:@"%@:%d/session/%@/element/%@%@",DEVICE_URL,nPort,sessionId,elementId,command];
        }else{
            strURL = [NSString stringWithFormat:@"%@:%d/session/%@%@", DEVICE_URL, nPort, sessionId, command];
        }
    } else {
        strURL = [NSString stringWithFormat:@"%@:%d%@", DEVICE_URL, nPort, command];
    }
    DDLogVerbose(@"url = %@",strURL);
    
    /// @code http header 정보 구성
    NSURL * url = [NSURL URLWithString:strURL];
    //NSMutableURLRequest * httpRequest = [[NSMutableURLRequest alloc] initWithURL:url];
    NSMutableURLRequest * httpRequest = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:(NSTimeInterval)timeout];
    httpRequest.HTTPMethod = method;
    
    if( dicData ) {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dicData
                                                           options:0/*NSJSONWritingPrettyPrinted*/
                                                             error:&error];
        httpRequest.HTTPBody = jsonData;
    }
    
    [httpRequest setValue:@"application/json;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [httpRequest setValue:@"application/json" forHTTPHeaderField:@"accept"];
    /// @endcode
    
/*
    //    __block __typeof__(self) blockSelf = self;
    __block dispatch_semaphore_t syncSem = dispatch_semaphore_create(0);
    __block NSError * asyncError = nil;
    __block NSData * responsedData = nil;
    void (^completionHandler)(NSData * __nullable responseData, NSURLResponse * __nullable response, NSError * __nullable sessionError);
    completionHandler = ^(NSData * __nullable responseData, NSURLResponse * __nullable response, NSError * __nullable sessionError)
    {
//        DDLogInfo(@"########## %d ##########",(int)[(NSHTTPURLResponse*)response statusCode]);
        if( [sessionError code] ) {
            asyncError = sessionError;
            //            DDLogInfo(@"다운로드 실패 (portNum : %d) -- %@", nPort, asyncError);
            if( syncSem )
                dispatch_semaphore_signal(syncSem);
            return ;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        int nResponseCode =  (int)[httpResponse statusCode];
        if (nResponseCode != 200 && nResponseCode != 303)
        {
//            DDLogInfo(@"다운로드 실패 (portNum : %d) errorcode : %d", nPort, nResponseCode );
            if( syncSem )
                dispatch_semaphore_signal(syncSem);
            return ;
        }
        
        responsedData = responseData;
        if( syncSem )
            dispatch_semaphore_signal(syncSem);
    };
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:httpRequest completionHandler:completionHandler] resume];
    dispatch_semaphore_wait(syncSem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)));
    
    syncSem = nil;
    NSDictionary *json = nil;
    if( responsedData ) {
        json = [NSJSONSerialization JSONObjectWithData:responsedData
                                               options:NSJSONReadingMutableContainers & NSJSONReadingMutableLeaves
                                                 error:&error];
        
    }
*/

    /// @code 동기적으로 통신을 한뒤 결과데이터를 NSDictionary 로 변화시킨다.
    NSURLResponse *response;
    NSData *urlData = [NSURLConnection sendSynchronousRequest:httpRequest
                                            returningResponse:&response
                                                        error:&error];
    
    if ([error code] != 0) {
        DDLogDebug(@"request failed with error = %@", error);
        return nil;
    }
    
    NSDictionary * json = nil;
    if( urlData ) {
        json = [NSJSONSerialization JSONObjectWithData:urlData
                                                             options: NSJSONReadingMutableContainers & NSJSONReadingMutableLeaves
                                                               error: &error];
        if ([error code] != 0) {
            DDLogDebug(@"result failed with error = %@", error);
            return nil;
        }
    } else {
        DDLogDebug(@"결과 없음.!!");
    }
    /// @endcode
    
    return json;
}

/// @brief syncRequest 랑 동일한데.. 스냅샷은 Polling 방식으로 사용하는거라 주기적으로 가져와야 함.. 근데 명령과 polling을 분리해둠.
- (NSDictionary *)syncRequestSnapshot:(NSDictionary *)requestData {
    
    if( !requestData )
        return nil;
    
    NSString * method = [requestData objectForKey:METHOD];
    NSDictionary * dicData = [requestData objectForKey:BODY];
    NSString * command = [requestData objectForKey:CMD];
    int nPort = [[requestData objectForKey:PORT] intValue];
    float timeout = [[requestData objectForKey:TIME_OUT] floatValue];
    NSString * session = [requestData objectForKey:SESSION_ID];
    
    NSError * error = nil;
    NSString * strURL = nil;
    
    if( session ) {
        strURL = [NSString stringWithFormat:@"%@:%d/session/%@%@", DEVICE_URL, nPort, session, command];
    } else {
        strURL = [NSString stringWithFormat:@"%@:%d%@", DEVICE_URL, nPort, command];
    }
    
//    DDLogInfo(@"url = %@",strURL);
    
    NSURL * url = [NSURL URLWithString:strURL];
//    NSMutableURLRequest * httpRequest = [[NSMutableURLRequest alloc] initWithURL:url];
    NSMutableURLRequest * httpRequest = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:(NSTimeInterval)timeout];
    httpRequest.HTTPMethod = method;
    
    if( dicData ) {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dicData
                                                           options:0/*NSJSONWritingPrettyPrinted*/
                                                             error:&error];
        httpRequest.HTTPBody = jsonData;
    }
    
    [httpRequest setValue:@"application/json;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [httpRequest setValue:@"application/json" forHTTPHeaderField:@"accept"];
    

    //    __block __typeof__(self) blockSelf = self;
    __block dispatch_semaphore_t syncSem = dispatch_semaphore_create(0);
    __block NSError * asyncError = nil;
    __block NSData * responsedData = nil;
    void (^completionHandler)(NSData * __nullable responseData, NSURLResponse * __nullable response, NSError * __nullable sessionError);
    completionHandler = ^(NSData * __nullable responseData, NSURLResponse * __nullable response, NSError * __nullable sessionError)
    {
        //        DDLogInfo(@"########## %d ##########",(int)[(NSHTTPURLResponse*)response statusCode]);
        if( [sessionError code] ) {
            asyncError = sessionError;
            //            DDLogInfo(@"다운로드 실패 (portNum : %d) -- %@", nPort, asyncError);
            if( syncSem )
                dispatch_semaphore_signal(syncSem);
            return ;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        int nResponseCode =  (int)[httpResponse statusCode];
        if (nResponseCode != 200 && nResponseCode != 303)
        {
            //            DDLogInfo(@"다운로드 실패 (portNum : %d) errorcode : %d", nPort, nResponseCode );
            if( syncSem )
                dispatch_semaphore_signal(syncSem);
            return ;
        }
        
        responsedData = responseData;
        if( syncSem )
            dispatch_semaphore_signal(syncSem);
    };
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:httpRequest completionHandler:completionHandler] resume];
    dispatch_semaphore_wait(syncSem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)));
    
    syncSem = nil;
    NSDictionary *json = nil;
    if( responsedData ) {
        json = [NSJSONSerialization JSONObjectWithData:responsedData
                                               options:NSJSONReadingMutableContainers & NSJSONReadingMutableLeaves
                                                 error:&error];
        
    }

/*
    NSURLResponse *response;
    NSData *urlData = [NSURLConnection sendSynchronousRequest:httpRequest
                                            returningResponse:&response
                                                        error:&error];
    if ([error code] != 0)
        return nil;
    
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:urlData
                                                         options: NSJSONReadingMutableContainers & NSJSONReadingMutableLeaves
                                                           error: &error];
    if ([error code] != 0)
        return nil;
*/
    
    return json;
}

/// @brief 초기화 및 iproxy 타스크 실행.
-(void)settingBeforeLaunch {
    DDLogDebug(@"%s", __FUNCTION__);
    //DDLogVerbose(@"XCUITEST Appium Launch 생략");
    
    self.nLockSetting = 0;
    
    _myWDATask = nil;
    _myIProxyHandler = nil;
    _myIproxyErrorHandler = nil;
    _myWDAHandler = nil;
    _myWDAErrorHandler = nil;
    _launchTimer = nil;
    _portNum = 0;
    self.sessionID = nil;
    
    _launchStatus = STATUS_NONE;
    _launchCount = 0;
    self.bStartDone = YES;
    
    _portNum = WDAPort + self.deviceInfos.deviceNo;
    
    if( [self respondsToSelector:@selector(startIProxy)] )
        [self performSelectorInBackground:@selector(startIProxy) withObject:nil];
    
    // Start에 대한 Response 를 먼저 보내주는 이유는 WebDriverAgent 가 설치되고 사용가능한 상태가 되기 까지가 랜덤하며, 늦어질 수도 있음.
//    if( [customDelegate respondsToSelector:@selector(agentCtrlLaunchSuccessed)] ) {
//        [customDelegate agentCtrlLaunchSuccessed];
//    }
}

//mg//
/// @brief  WDA 실행
/*- (void)launchControlAgent {
    DDLogDebug(@"%s", __FUNCTION__);
    //DDLogDebug(@"XCUITEST START");
    
    if( _launchTimer ) {
        [_launchTimer invalidate];
        _launchTimer = nil;
    }
    
    /// @code   WDA 를 미리 빌드 해놓고, 빌드한 결과물을 가지고 실행한다. (test-without-building 옵션) 이렇게 하지 않고 멀티 제어를 하게 되면 실행이 안되는 디바이스들이 있었음. $HOME/OnycomManager/Manual/Prebuild4WDA.js 파일에 WDA 빌드하여 XCTRun 파일을 생성하는 명령이 있으며, 반드시 이 스크립트로 빌드를 해놔야 하며, XCTRun 정보를 AgentInfo.txt 파일에 넣어줘야 함.
    // xcodebuild 로 build-for-testing 의 옵션을 사용하여 빌드한뒤 생성된
    NSString * commandString = [NSString stringWithFormat:@"xcodebuild test-without-building -xctestrun %@/PreBuild4WDA/%@/Build/Products/%@ -destination id=%@", [Utility managerDirectory], self.deviceInfos.udid, _xctestRun, self.deviceInfos.udid];
    // @endcode
    //DDLogVerbose(@"start command = %@",commandString);
    
    _myWDATask = [[NSTask alloc] init];
    _myWDATask.launchPath = @"/bin/bash";
    _myWDATask.arguments = @[@"-l", @"-c", commandString];
    
    _myWDAHandler = [[PipeHandler alloc] initWithDelegate:self];
    _myWDAErrorHandler = [[PipeHandler alloc] initWithDelegate:self];
    [_myWDAHandler setReadHandlerForTask:_myWDATask withKind:PIPE_OUTPUT];
    [_myWDAErrorHandler setReadHandlerForTask:_myWDATask withKind:PIPE_ERROR];
    
    //onCheckLaunchedTimer 호출이 늦어지고 연결 실패가 되는 경우가 발생함.
    /// @code   WDA 가 사용가능한 상태인지 확인을 한다.
    dispatch_async(dispatch_get_main_queue(), ^{
     _launchStatus = STATUS_START;
     launchBundleId = @"HomeScreen";
     _launchCount = 0;
     //        _launchTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(onCheckLaunchedTimer:) userInfo:nil repeats:YES];
     
     _launchTimer = [NSTimer timerWithTimeInterval:1.0f target:self selector:@selector(onCheckLaunchedTimer:) userInfo:nil repeats:YES];
     NSRunLoop * curRunloop = [NSRunLoop currentRunLoop];
     [curRunloop addTimer:_launchTimer forMode:NSDefaultRunLoopMode];
     
     [_myWDATask launch];
     });
    /// @endcode
}//launchControlAgent
 */

//mg//
/// @brief  WDA 실행
- (void)launchControlAgent {
    DDLogDebug(@"%s", __FUNCTION__);
    
    if( _launchTimer ) {
        [_launchTimer invalidate];
        _launchTimer = nil;
    }
    
    /// @code   WDA 를 미리 빌드 해놓고, 빌드한 결과물을 가지고 실행한다. (test-without-building 옵션) 이렇게 하지 않고 멀티 제어를 하게 되면 실행이 안되는 디바이스들이 있었음. $HOME/OnycomManager/Manual/Prebuild4WDA.js 파일에 WDA 빌드하여 XCTRun 파일을 생성하는 명령이 있으며, 반드시 이 스크립트로 빌드를 해놔야 하며, XCTRun 정보를 AgentInfo.txt 파일에 넣어줘야 함.
    // xcodebuild 로 build-for-testing 의 옵션을 사용하여 빌드한뒤 생성된
    DDLogDebug(@"%@",[Utility managerDirectory]);
    DDLogDebug(@"%@",_xctestRun);
    
//    _myWDATask = [[NSTask alloc] init];
//    _myWDATask.launchPath = @"usr/bin/xcodebuild";
//    _myWDATask.arguments = @[@"test-without-building", @"-xctestrun", [NSString stringWithFormat:@"%@/PreBuild4WDA/%@/Build/Products/%@",
//                                                                       [Utility managerDirectory], self.deviceInfos.udid, _xctestRun], @"-destination", [NSString stringWithFormat:@"id=%@", self.deviceInfos.udid]];
    
    
    NSString * commandString = [NSString stringWithFormat:@"xcodebuild test-without-building -xctestrun %@/PreBuild4WDA/%@/Build/Products/%@ -destination id=%@", [Utility managerDirectory], self.deviceInfos.udid, _xctestRun, self.deviceInfos.udid];
    // @endcode
    //DDLogVerbose(@"start command = %@",commandString);
    
    _myWDATask = [[NSTask alloc] init];
    _myWDATask.launchPath = @"/bin/bash";
    _myWDATask.arguments = @[@"-l", @"-c", commandString];
    
    _myWDAHandler = [[PipeHandler alloc] initWithDelegate:self];
    _myWDAErrorHandler = [[PipeHandler alloc] initWithDelegate:self];
    [_myWDAHandler setReadHandlerForTask:_myWDATask withKind:PIPE_OUTPUT];
    [_myWDAErrorHandler setReadHandlerForTask:_myWDATask withKind:PIPE_ERROR];
    
    _launchStatus = STATUS_START;
    launchBundleId = @"HomeScreen";
    _launchCount = 0;    
    
    if( [NSThread isMainThread] ) {
        //예외 일괄처리
        [_myWDATask launch];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            //예외 일괄처리
            [_myWDATask launch];
        });
    }
    
    //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
      //  [_myWDATask launch];
    //});
    
    launchTime = [NSDate date];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        _launchTimer = [NSTimer timerWithTimeInterval:1.0f target:self selector:@selector(onCheckLaunchedTimer:) userInfo:nil repeats:YES];
        NSRunLoop * curRunloop = [NSRunLoop currentRunLoop];
        [curRunloop addTimer:_launchTimer forMode:NSDefaultRunLoopMode];
    });

    //onCheckLaunchedTimer 호출이 늦어지고 연결 실패가 되는 경우가 발생함.
    //연결 일괄 처리
    /*_launchStatus = STATUS_START;
    launchBundleId = @"HomeScreen";

    @try {
        [_myWDATask launch];
        DDLogDebug(@"launch WDA");
    } @catch (NSException *e) {
        DDLogError(@"WDA launch error = %@", e.reason);

        if( [customDelegate respondsToSelector:@selector(agentCtrlLaunchFailed)] ) {
            [customDelegate agentCtrlLaunchFailed];
        }
        return;
    }
    
    // 상태 체크
    NSDictionary * requestData = @{METHOD:@"GET", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:1.0f], CMD:@"/status"};

    for (int i=0; i<30; ++i) {
        DDLogVerbose(@"check loop");
        sleep(1);//[NSThread sleepForTimeInterval:1.0f];
        
        //@autoreleasepool {
            DDLogVerbose(@"http request");
            NSDictionary * result = [self syncRequest:requestData];
            DDLogVerbose(@"status output = %@", result);
        
        //  상태체크를 하였을때 몇가지 동작 상태변화
        //  1. SessionID --> nil --> SessionID      이때 처음의 SessionID 와 두번째 SessionID 는 다르다. 두번째의 SessionID 를 사용해야 한다.
        //  2. SessionID --> nil                    WDA 구동에 실패 한 상태.
        //  3. SessionID                            처음 나온 SessionID 가 그대로 유지되는 상태이며, 이 SessioID 를 사용하여 제어가 가능하다.
            if( STATUS_START == _launchStatus ) {
                if( nil == result )
                    _launchStatus = STATUS_READY;
                
                //  멀티 실행하다 보면.. 처음 나온 Session 에서 변경되지 않는 경우도 존재하는데 이때, 이 Session 로 idevice 가 제어되기 때문에 사용해야 한다.   그래서.. 4초 동안 session 가 변경되지 않으면.. 사용하기 위해 만들어둠...
                if( 3 < i )
                    _launchStatus = STATUS_READY;
            } else if( STATUS_READY == _launchStatus ) {
                if (result == nil)
                    continue;
                
                NSDictionary * value = [result objectForKey:@"value"];
                if( [value count] ) {
                    NSString * sessionId = [result objectForKey:@"sessionId"];
                    if( sessionId)
                        self.sessionID = sessionId;
                    
                    NSDictionary * size = [value objectForKey:@"size"];
                    if( size ) {
                        int width = [[size objectForKey:@"width"] intValue];
                        int height = [[size objectForKey:@"height"] intValue];
                        _windowSize = CGSizeMake(width, height);
                    }
                    
                    _launchStatus = STATUS_LAUNCHED;
                    self.bLaunchDone = YES;
                    DDLogWarn(@"launch success");
                    
                    // 임시로 사용함.
                    self.launchBundleId = @"HomeScreen";
                    self.launchAppName = @"HomeScreen";
                    // 성공했음을 알림.
                    if( [customDelegate respondsToSelector:@selector(agentCtrlLaunchSuccessed)] ) {
                        [customDelegate agentCtrlLaunchSuccessed];
                        return;
                    }
                }//if : count
            }//if - else : STATUS
        //}//auto release
    }

    // 5분동안 체크해서 WebDriverAgnet 가 활성화 안되면 실패 처리함. (Appium 은 6000초 10분 설정되어있는데 10분은 너무 긴거 같음.)
    if( [customDelegate respondsToSelector:@selector(agentCtrlLaunchFailed)] ) {
        [customDelegate agentCtrlLaunchFailed];
    }
     */
}//launchControlAgent

/// @brief  WDA 와 통신을 하기 위한 iproxy 를 실행한다.
- (void) startIProxy {          // WebDriverAgent 와 통신을 하기 위한 iProxy 를 실행시킨다.
    // _portNum 으로 실행중인 iproxy 를 강제 종료시킨다. (확인)
    [Utility killListenPort:_portNum exceptPid:getpid()];
    
    NSString * commandString = [NSString stringWithFormat:@"iproxy %d %d %@", _portNum, _portNum, deviceInfos.udid];
    
    _myIProxyTask = [[NSTask alloc] init];
    _myIProxyTask.launchPath = @"/bin/bash";
    _myIProxyTask.arguments = @[@"-l", @"-c", commandString];
    
    _myIProxyHandler = [[PipeHandler alloc] initWithDelegate:self];
    _myIproxyErrorHandler = [[PipeHandler alloc] initWithDelegate:self];
    [_myIProxyHandler setReadHandlerForTask:_myIProxyTask withKind:PIPE_OUTPUT];
    [_myIproxyErrorHandler setReadHandlerForTask:_myIProxyTask withKind:PIPE_ERROR];
    
    //mg//
    /*
     dispatch_async(dispatch_get_main_queue(), ^{
        [_myIProxyTask launch];
    });
     */
    
    //mg//s
    if( [NSThread isMainThread] ) {
        //예외 일괄처리
        [_myIProxyTask launch];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            //예외 일괄처리
            [_myIProxyTask launch];
        });
    }//mg//e
}//startIProxy

/// @brief  iproxy 를 종료한다.
- (void) stopIProxy {
    if( _myIProxyTask.isRunning) {
        __block dispatch_semaphore_t terminationSem = dispatch_semaphore_create(0);
        _myIProxyTask.terminationHandler = ^(NSTask * task) {
            if( terminationSem ) {
                dispatch_semaphore_signal(terminationSem);
            }
        };
        
        [_myIProxyTask terminate];
        dispatch_semaphore_wait(terminationSem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0f * NSEC_PER_SEC)));
        terminationSem = nil;
        _myIProxyTask = nil;
        
        if( _myIProxyHandler ) {
            [_myIProxyHandler closeHandler];
            _myIProxyHandler = nil;
        }
        
        if( _myIproxyErrorHandler ) {
            [_myIproxyErrorHandler closeHandler];
            _myIproxyErrorHandler = nil;
        }
    }
}

/// @brief  WDA 를 종료시킨다. WDA 내부적으로 자신이 관리하던 앱들을 종료하고 종료됨.
- (void) shutdownWDA {
    if (!self.bLaunchDone) return;
    
    NSDictionary * requestData = @{METHOD:@"GET", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:0.5f], CMD:@"/wda/shutdown"};
    NSDictionary * result = [self syncRequest:requestData];
    
    DDLogDebug(@"### SHUTDOWN RESULT ### \n %@", result);
}

/// @brief  WDA 타스크를 종료 및 정리한다.
- (void) stopWDA {
    
    if( _launchTimer ) {
        [_launchTimer invalidate];
        _launchTimer = nil;
    }
    
    if( _myWDATask ) {
        __block dispatch_semaphore_t terminationSem = dispatch_semaphore_create(0);
        _myWDATask.terminationHandler = ^(NSTask * task) {
            if( terminationSem )
                dispatch_semaphore_signal(terminationSem);
        };
        
        [_myWDATask terminate];
        dispatch_semaphore_wait(terminationSem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0f * NSEC_PER_SEC)));
        terminationSem = nil;
        _myWDATask = nil;
        
        if( _myWDAHandler ) {
            [_myWDAHandler closeHandler];
            _myWDAHandler = nil;
        }
        
        if( _myWDAErrorHandler ) {
            [_myWDAErrorHandler closeHandler];
            _myWDAErrorHandler = nil;
        }
    }
}

/// @brief  iphone 에 WDA 앱을 삭제 한다.
- (void) removeWDA {
    DDLogInfo(@"%s", __FUNCTION__);

    //mg//s
   /* NSString *agentId = @"com.apple.test.WebDriverAgentRunner-Runner";
    
    if( [customDelegate respondsToSelector:@selector(getAppListForDevice:)] ) {

        NSMutableArray * dicAppList = (NSMutableArray *)[customDelegate getAppListForDevice:NO];
        
        for(int i = 0; i<dicAppList.count; i++){
            NSString* temp = [dicAppList objectAtIndex:i];
            
            if([temp containsString:@"com.apple.test.OnyAgent-Runner"]) {
                agentId = @"com.apple.test.OnyAgent-Runner";
                break;
            } else if([temp containsString:@"com.apple.test.Don't Touch Me-Runner"]) {
                agentId = @"com.apple.test.Don't Touch Me-Runner";
                break;
            } else if([temp containsString:@"com.apple.test.WebDriverAgentRunner-Runner"]) {
                agentId = @"com.apple.test.WebDriverAgentRunner-Runner";
                break;
            }
        }//for : app list
    }//if : getAppListForDevice
    
    DDLogVerbose(@"agent id = %@", agentId);

    NSString * commandString = [NSString stringWithFormat:@"ideviceinstaller -U %@ -u %@", agentId, deviceInfos.udid];
    */
    //mg//e
    
    NSString * commandString = [NSString stringWithFormat:@"ideviceinstaller -U com.apple.test.WebDriverAgentRunner-Runner -u %@", deviceInfos.udid];
    
    NSTask * removeTask = [[NSTask alloc] init];
    removeTask.launchPath = @"/bin/bash";
    removeTask.arguments = @[@"-l", @"-c", commandString];
    
    NSPipe * outputPipe = [[NSPipe alloc] init];
    [removeTask setStandardOutput:outputPipe];
    NSFileHandle * outputHandle = [outputPipe fileHandleForReading];
    
    if( [NSThread isMainThread] ) {
        [removeTask launch];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [removeTask launch];
        });
    }
    
    NSData * readData = [outputHandle readDataToEndOfFile];
    NSString * readString = [[NSString alloc] initWithData:readData encoding:NSUTF8StringEncoding];
    [outputHandle closeFile];
    
    NSArray * component = [readString componentsSeparatedByString:@"\n\r"];
    NSString * lastObject = [[component lastObject] lowercaseString];
    
    if( [lastObject containsString:@"complete"] ) {
        DDLogInfo(@"삭제 성공");
    }
}


//#pragma mark - Bundle ID 를 이용한 앱 실행
///// @brief  BundleID 로 앱을 실행시켜 새로운 Session (udid) 를 생성한다.
//-(void)launchAppWithBundleID {
//    //DDLogInfo(@"### LAUNCH BUNDLE ID = %@", self.launchBundleId);
//    DDLogDebug(@"%s", __FUNCTION__);
//    DDLogInfo(@"launch : %@", self.launchBundleId)
//
//    //mg//s
//    if ([self launchAppWithBundleID:self.launchBundleId]) {
//        if( [customDelegate respondsToSelector:@selector(applicationLaunchSuccessed)] )
//            [customDelegate applicationLaunchSuccessed];
//    } else {
//        if( [customDelegate respondsToSelector:@selector(applicationLaunchFailed:)] )
//            [customDelegate applicationLaunchFailed:@"Failed to start a session"];
//    }
//    //mg//e
//
//}//launchAppWithBundleID

///// @brief launchAppWithBundleID 메소드와 동일한 역활을 한다.
//- (BOOL) launchAppWithBundleID:(NSString *)bundleID {
//    //DDLogVerbose(@"### LAUNCH BUNDLE ID = %@", bundleID);
//    DDLogDebug(@"%s", __FUNCTION__);
//    DDLogInfo(@"launch : %@", bundleID);
//
//    NSDictionary * body = @{@"desiredCapabilities":@{
//                                    @"bundleId":bundleID,
//                                    @"arguments":@[],
//                                    @"environment":@{},
//                                    @"shouldWaitForQuiescence":@NO,
//                                    @"shouldUseTestManagerForVisibilityDetection":@YES,
//                                    @"maxTypingFrequency":@60,
//                                    @"shouldUseSingletonTestManager":@YES,
//                                    }};
//
//    //mg//timeout 10->30
//    // 단말이 구릴수록 타임아웃이 많이 걸림
//    // 기종별로 타임아웃 시간을 늘려줄 필요가 있을것으로 보임
//    NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:10.0f], CMD:@"/session", BODY:body};
////    NSDictionary * requestData = @{METHOD:@"GET", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:1.0f], CMD:@"/status"};
//
//    __block NSDictionary * result = nil;
//    dispatch_sync(_launchAppQueue, ^{
//        result = [self syncRequest:requestData];
//    });
//
//    if( !result ) {
//        DDLogError(@"%s -- 결과 없음!!", __FUNCTION__);
//        return NO;
//    }
//
//    //DDLogVerbose(@"BUNDLE ID 실행 = %@",result);
//    DDLogDebug(@"response : %@", result);
//    DDLogVerbose(@"[#### Info ####] before Session ID : %@", self.sessionID);
//
//    int nResult = [[result objectForKey:@"status"] intValue];
//    if( 0 == nResult ) {
//        self.sessionID = [result objectForKey:@"sessionId"];
//        DDLogVerbose(@"[#### Info ####] after Session ID : %@\n\n", self.sessionID);
//
//        return YES;
//    } else {
//        //DDLogVerbose(@"응답은 있지만.. 예외 발생!! -- error code : %d", nResult);
//        DDLogError(@"error = %d", nResult);
//
//        return NO;
//    }
//}//launchAppWithBundleID

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - Bundle ID 를 이용한 앱 실행
/// @brief  BundleID 로 앱을 실행시켜 새로운 Session (udid) 를 생성한다.
-(void)launchAppWithBundleID {
    DDLogInfo(@"### LAUNCH BUNDLE ID = %@", self.launchBundleId);
    
    NSDictionary * body = @{@"desiredCapabilities":@{
                                    @"bundleId":self.launchBundleId,
                                    }};
    
    NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:5 * 60.0f], CMD:@"/session", BODY:body};
    
    __block NSDictionary * result = nil;
    dispatch_sync(_launchAppQueue, ^{
        result = [self syncRequest:requestData];;
    });
    
    if( !result ) {
        DDLogError(@"%s -- 결과 없음", __FUNCTION__);
        if( [customDelegate respondsToSelector:@selector(applicationLaunchFailed:)] ) {
            [customDelegate applicationLaunchFailed:@"WebDriverAgent 연결 실패1"];
        }
    }
    
    DDLogInfo(@"BUNDLE ID 실행 = %@",result);
    DDLogInfo(@"[#### Info ####] before Session ID : %@", self.sessionID);
    
    int nResult = [[result objectForKey:@"status"] intValue];
    if( 0 == nResult ) {
        self.sessionID = [result objectForKey:@"sessionId"];
        DDLogInfo(@"[#### Info ####] after Session ID : %@\n\n", self.sessionID);
        
        if( [customDelegate respondsToSelector:@selector(applicationLaunchSuccessed)] ) {
            [customDelegate applicationLaunchSuccessed];
        }
    } else if( 13 == nResult){
        if(self.nRetryCount > 5){
            DDLogError(@"error code : %d", nResult);
            if( [customDelegate respondsToSelector:@selector(applicationLaunchFailed:)] ) {
                [customDelegate applicationLaunchFailed:@"앱 실행 실패2"];
            }
        }else{
            DDLogError(@"error code : %d", nResult);
            self.nRetryCount += 1;
            DDLogError(@"번들아이디 재 시도 = %d",self.nRetryCount);
            [self launchAppWithBundleID];
        }
    }
    else {
        DDLogError(@"응답은 있지만.. 예외 발생!! -- error code : %d", nResult);
        if( [customDelegate respondsToSelector:@selector(applicationLaunchFailed:)] ) {
            [customDelegate applicationLaunchFailed:@"앱 실행 실패2"];
        }
    }
}

/// @brief launchAppWithBundleID 메소드와 동일한 역활을 한다.
- (BOOL) launchAppWithBundleID:(NSString *)bundleID {
    DDLogInfo(@"### LAUNCH BUNDLE ID = %@", bundleID);
    
    NSDictionary * body = @{@"desiredCapabilities":@{
                                    @"bundleId":bundleID,
                                    }};
    
    NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:15.], CMD:@"/session", BODY:body};
    
    __block NSDictionary * result = nil;
    dispatch_sync(_launchAppQueue, ^{
        result = [self syncRequest:requestData];;
    });
    
    if( !result ) {
        DDLogError(@"%s -- 결과 없음!!", __FUNCTION__);
        return NO;
    }
    
    DDLogInfo(@"BUNDLE ID 2 실행 = %@",result);
    DDLogInfo(@"[#### Info ####] before Session ID : %@", self.sessionID);
    
    int nResult = [[result objectForKey:@"status"] intValue];
    if( 0 == nResult ) {
        self.sessionID = [result objectForKey:@"sessionId"];
        DDLogInfo(@"[#### Info ####] after Session ID : %@\n\n", self.sessionID);
        
        return YES;
    } else {
        DDLogError(@"응답은 있지만.. 예외 발생!! -- error code : %d", nResult);
        return NO;
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/// @brief 비동기적으로 ipa 파일을 iphone 에 설치한다.
- (void) launchAppWithFilePath {
    __block __typeof__(self) blockSelf = self;
    [AppInstaller asyncIDeviceInstaller:self.installPath withUDID:deviceInfos.udid completion:^(BOOL successed, NSString *description) {
//    [AppInstaller asyncIOS_Deploy:self.installPath withUDID:deviceInfos.udid completion:^(BOOL successed, NSString *description) {
        if( successed ) {
            // 인스톨 성공한뒤 앱을 실행하지 않고, DC 로 부터 RunApp 커멘드를 받아서 실행한다.
            [customDelegate applicationLaunchSuccessed];
        } else {
            if( [customDelegate respondsToSelector:@selector(applicationLaunchFailed:)] ) {
                [customDelegate applicationLaunchFailed:description];
            }
        }
    }];
}


#pragma mark - DC_STOP 명령어에 따른 초기화
/// @brief  사용하지 않음. WDA 에 shutdown 을 하는걸로 대체됨.
- (void) clearWebDriverSession:(NSDictionary *)dicBundleIds {
    // BundleID 또는 ipa 파일로 설치한 앱을 종료하는 과정이 필요함...
    // touch 로 실행한 App 들을 종료 해줘야 함...
    /*
    BOOL bSuccessed = NO;
    NSArray * bundleIds = dicBundleIds.allKeys;
    for( NSString * bundleId in bundleIds ) {
        bSuccessed = [self launchAppWithBundleID:bundleId];
    }
     */
}

/// @brief  WDA 를 종료하고 정리한다.
/// @param dicBundleIds     clearWebDriverSession 메소드에서 사용하려고 BundleID 정보들을 넣어줬는데 필요없어짐..
- (void)finishControlAgent:(NSDictionary *)dicBundleIds {
    DDLogWarn(@"%s, %d", __FUNCTION__, self.deviceInfos.deviceNo);
    
//    [self clearWebDriverSession:dicBundleIds];
    //    [self shutdownWDA];    // hoonl : ios 11 버전에서 이상동작을 야기시켜 사용안함 (이전에도 null 값 떨어지던 부분)
    [self stopIProxy];
    [self stopWDA];
    [self removeWDA];
    
    _launchStatus = STATUS_NONE;
    self.sessionID = nil;
    self.bStartDone = NO;
    self.bLaunchDone = NO;
    launchBundleId = nil;
    _portNum = 0;
}

#pragma mark - <PipeHnaler Delegate>
/// @brief  WDA handler, iproxy handler 에서 출력되는 문자열과 예외 문자열을 가져와 예외 처리를 하거나 로그를 출력한다.
- (void) readData:(NSData *)readData withHandler:(const PipeHandler *)handler {
    DDLogVerbose(@"%s", __FUNCTION__);
    
    if( handler == _myIProxyHandler ) {
        
    } else if( handler == _myIproxyErrorHandler ) {
        
    } else if( handler == _myWDAHandler) {
//        NSString * readString = [[NSString alloc] initWithData:readData encoding:NSUTF8StringEncoding];
//        DDLogInfo(@"[#### Info ####] %@", readString);
        
        //NSString * errorReadString = [[NSString alloc] initWithData:readData encoding:NSUTF8StringEncoding];
        //DDLogVerbose(@"start agent output : %@", errorReadString);
    } else if( handler == _myWDAErrorHandler ) {
        NSString * errorReadString = [[NSString alloc] initWithData:readData encoding:NSUTF8StringEncoding];
        DDLogInfo(@"[#### Error ####] %d,  %@", deviceInfos.deviceNo, errorReadString);
        errorReadString = [errorReadString stringByReplacingOccurrencesOfString:@"\r" withString:@""];
        NSArray* arrOut = [errorReadString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        
        for (NSString *errMsg in arrOut ) {
            
            NSString * lowerErrMsg = [errMsg lowercaseString];
            if( [lowerErrMsg isEqualToString:@"** test failed **"] ) {
                DDLogError(@"[#### Info ####] Test Failed !!");
                if( [customDelegate respondsToSelector:@selector(agentCtrlLaunchFailed)] ) {
                    [customDelegate agentCtrlLaunchFailed];
                }
            } else if( [lowerErrMsg isEqualToString:@"xcodebuild: error: failed to build workspace temporary with scheme transient testing."] ) {
                DDLogError(@"[#### Info ####] Test Failed !! -- 잘못된 scheme 선택 또는 xctrun 파일 없음.!!");
                if( [customDelegate respondsToSelector:@selector(agentCtrlLaunchFailed)] ) {
                    [customDelegate agentCtrlLaunchFailed];
                }
            }
        }
    }
}


#pragma mark - <Timer Delegate>
/// @brief  WDA 가 정상적으로 실행되어 준비 완료되었는지 1초단위로 확인하는 타이머 메소드
- (void) onCheckLaunchedTimer:(NSTimer *)theTimer {
    DDLogDebug(@"%s", __FUNCTION__);
    
    // 30초 동안 확인후 실패 처리 한다.
    if( ++_launchCount == MAX_LAUNCH_TRY_COUNT ) {
        [_launchTimer invalidate];
        _launchTimer = nil;

        // 5분동안 체크해서 WebDriverAgnet 가 활성화 안되면 실패 처리함. (Appium 은 6000초 10분 설정되어있는데 10분은 너무 긴거 같음.)
        if( [customDelegate respondsToSelector:@selector(agentCtrlLaunchFailed)] ) {
            [customDelegate agentCtrlLaunchFailed];
        }
        return;
    }

    // 상태 체크
    NSDictionary * requestData = @{METHOD:@"GET", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:1.0f], CMD:@"/status"};
    NSDictionary * result = [self syncRequest:requestData];
    DDLogVerbose(@"### STATUS RESULT ### \n %@", result);
    
    //  상태체크를 하였을때 몇가지 동작 상태변화
    //  1. SessionID --> nil --> SessionID      이때 처음의 SessionID 와 두번째 SessionID 는 다르다. 두번째의 SessionID 를 사용해야 한다.
    //  2. SessionID --> nil                    WDA 구동에 실패 한 상태.
    //  3. SessionID                            처음 나온 SessionID 가 그대로 유지되는 상태이며, 이 SessioID 를 사용하여 제어가 가능하다.
    if( STATUS_START == _launchStatus ) {
        if( nil == result ) {
            _launchStatus = STATUS_READY;
        }
        //  멀티 실행하다 보면.. 처음 나온 Session 에서 변경되지 않는 경우도 존재하는데 이때, 이 Session 로 idevice 가 제어되기 때문에 사용해야 한다.   그래서.. 4초 동안 session 가 변경되지 않으면.. 사용하기 위해 만들어둠...
        else if( 4 < _launchCount ) {
            _launchStatus = STATUS_READY;
        }
        //mg//s
        else {
            
            // Do some stuff to setup for timing
            //const uint64_t startTime = mach_absolute_time();
            // Do some stuff that you want to time
            //const uint64_t endTime = mach_absolute_time();
            
            // Time elapsed in Mach time units.
            //const uint64_t elapsedMTU = endTime - startTime;
            
            // Get information for converting from MTU to nanoseconds
            //mach_timebase_info_data_t info;
            //if (mach_timebase_info(&info))
                //handleErrorConditionIfYoureBeingCareful();
            
            // Get elapsed time in nanoseconds:
            //const double elapsedNS = (double)elapsedMTU * (double)info.numer / (double)info.denom;
            
            //timer 호출이 10초 이상 걸리면서, 이미 연결이 되었는데 4회 확인 과정을 거치느라, 시간 초과로 연결 실패
            NSDate *date = [NSDate date];
            long elapsed = [date timeIntervalSince1970]*1000 - [launchTime timeIntervalSince1970]*1000;
            DDLogDebug(@"elapsed time = %ld", elapsed);
            
            if (elapsed > 5000)
                _launchStatus = STATUS_READY;
            else
                return;
        }//mg//e
        
        //mg//return ;
    }//if : STATUS_START

    if( STATUS_READY == _launchStatus ) {
        NSDictionary * value = [result objectForKey:@"value"];
        if( [value count] ) {
            
            NSString * sessionId = [result objectForKey:@"sessionId"];
            if( sessionId)
                self.sessionID = sessionId;
            
            NSDictionary * size = [value objectForKey:@"size"];
            if( size ) {
                int width = [[size objectForKey:@"width"] intValue];
                int height = [[size objectForKey:@"height"] intValue];
                _windowSize = CGSizeMake(width, height);
            }
            
            _launchStatus = STATUS_LAUNCHED;
            [_launchTimer invalidate];
            _launchTimer = nil;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self.bLaunchDone = YES;

                // 임시로 사용함.
                self.launchBundleId = @"HomeScreen";
                self.launchAppName = @"HomeScreen";
                // 성공했음을 알림.
                if( [customDelegate respondsToSelector:@selector(agentCtrlLaunchSuccessed)] ) {
                   [customDelegate agentCtrlLaunchSuccessed];
                }
            });
        }
    }//if : STATUS_READY
 
    //DDLogInfo(@"\n\nResult : %@\n\n", result);
}//onCheckLaunchedTimer

#pragma mark - 탭
/// @brief  touch 처리
/// @bug    WDA 에서 LandScape 상태일 때 Springboard와 App 의 Touch 동작이 다름. 예외 처리 해줘야 함.
- (void)doTapAtX:(float)argX andY:(float)argY{
    if (!self.bLaunchDone || nil == _sessionID ) return;
    
    NSLog(@"%s, %d -- %.2f, %.2f",__FUNCTION__, self.deviceInfos.deviceNo, argX, argY);
    float ratio = (float)self.deviceInfos.ratio;
    
    int newArgX = argX/ratio;
    int newArgY = argY/ratio;
    
    NSLog(@"%s, %d -- %d, %d",__FUNCTION__, self.deviceInfos.deviceNo, newArgX, newArgY);
    NSDictionary * body = @{@"x":[NSNumber numberWithFloat:newArgX], @"y":[NSNumber numberWithFloat:newArgY], @"duration":[NSNumber numberWithFloat:0.1]};
    
    NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/wda/touchAndHold", BODY:body, SESSION_ID:self.sessionID};
    NSDictionary * result = [self syncRequest:requestData];
    DDLogInfo(@"tap result = %@",result);
    if( result ) {
        DDLogInfo(@"성공");
    } else {
        DDLogInfo(@"실패");
    }
    NSString * sessionId = [result objectForKey:@"sessionId"];
    if( sessionId)
        self.sessionID = sessionId;
    else
        NSLog(@"흠...");
}


#pragma mark - 드래그 & 드롭
/// @brief  자동화 기능에서 사용함.   드레그 동작
- (void)doSwipeAtX1:(int)argX1 andY1:(int)argY1 andX2:(int)argX2 andY2:(int)argY2 {
    if (!self.bLaunchDone || nil == _sessionID ) return;
    
    float ratio = (float)deviceInfos.ratio;
    
    float newArgX1 = argX1/ratio;
    float newArgY1 = argY1/ratio;
    float newArgX2 = argX2/ratio;
    float newArgY2 = argY2/ratio;
    
    NSError * error = nil;
    NSDictionary * body = @{@"fromX":[NSNumber numberWithFloat:newArgX1], @"fromY":[NSNumber numberWithFloat:newArgY1], @"toX":[NSNumber numberWithFloat:newArgX2], @"toY":[NSNumber numberWithFloat:newArgY2], @"duration":[NSNumber numberWithFloat:0.01]};
    
    NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/wda/dragfromtoforduration", BODY:body, SESSION_ID:self.sessionID};
    
    NSDictionary * result = [self syncRequest:requestData];
    
    if( result ) {
        DDLogInfo(@"성공");
        NSString * sessionId = [result objectForKey:@"sessionId"];
        if( sessionId)
            self.sessionID = sessionId;
        else
            NSLog(@"흠....");
        nStartX = 0;
        nStartY = 0;
    } else {
        NSLog(@"실패");
        
        DDLogError(@"Drag and Drop Error");
        if( 1001 == error.code ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:self.deviceInfos.deviceNo];
            });
        }
    }
}

/// @brief  드레그 시작
- (void)doTouchStartAtX:(int)argX andY:(int)argY{
    DDLogInfo(@"%s, %d",__FUNCTION__, self.deviceInfos.deviceNo);
    
    if (!self.bLaunchDone || nil == _sessionID ) return;
    touchDate = [NSDate date];
    
    float ratio = (float)self.deviceInfos.ratio;
    nStartX = argX/ratio;
    nStartY = argY/ratio;
}

/// @brief  드레그
- (void)doTouchMoveAtX:(int)argX andY:(int)argY{
    DDLogInfo(@"%s, %d",__FUNCTION__, self.deviceInfos.deviceNo);
    
    if (!self.bLaunchDone) {
        DDLogInfo(@"%s, %d, did not launched", __FUNCTION__, deviceInfos.deviceNo);
        return;
    }
    
    if( nStartX == 0 && nStartY == 0 ) {
        [self doTouchStartAtX:argX andY:argY];
    }
}

/// @brief  드레그 끝
- (void)doTouchEndAtX:(int)argX andY:(int)argY andAuto:(BOOL)bAuto{
    DDLogInfo(@"%s, %d",__FUNCTION__, self.deviceInfos.deviceNo);
    if (!self.bLaunchDone || nil == _sessionID ) return;
    
    float ratio = (float)self.deviceInfos.ratio;
    int endX = argX/ratio;
    int endY = argY/ratio;
    
    if( !touchDate ) {
        if( endX > endY ) {         // Landscape
            if( endX > _windowSize.height ) {       // 홈버튼 클릭
                [self homescreen];
            }
        } else {                    // Portrait
            if( endY > _windowSize.height ) {       // 홈버튼 클릭
                [self homescreen];
            }
        }
        DDLogWarn(@"드레그의 시작이 없음!!");
        return ;
    }
    
    NSError * error = nil;
    NSDictionary * requestData = nil;
    
    NSDate * newDate = [NSDate date];
    NSTimeInterval timeInterval = [newDate timeIntervalSinceDate:touchDate];
    
    // 롱프레스의 경우 드레그 처리되어 DC 로 부터 전달되는경우가 있어 예외 처리해줌.
    // LongPress 의 범위를 (20,20) 으로 잡음....
    if( abs(nStartX - endX) < 21 && abs(nStartY - endY) < 21 ) {
        NSDictionary * body = @{@"x":[NSNumber numberWithFloat:nStartX], @"y":[NSNumber numberWithFloat:nStartY], @"duration":[NSNumber numberWithFloat:(float)timeInterval]};
        requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/wda/touchAndHold", BODY:body, SESSION_ID:self.sessionID};
        
    } else {        // Drag & Drop
        NSDictionary * body = nil;
        
        if( timeInterval < 0.5f && bAuto == NO) {     // 짧지만 빠르게 움직임.

            body = @{@"fromX":[NSNumber numberWithFloat:nStartX], @"fromY":[NSNumber numberWithFloat:nStartY], @"toX":[NSNumber numberWithFloat:endX], @"toY":[NSNumber numberWithFloat:endY]};
            
            requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/wda/dragSwipe", BODY:body, SESSION_ID:self.sessionID};
        } else {                        // 밀듯이 움직임.
            //mg//객체가 선택되는 사례가 있어서 duration 0.1->0
            body = @{@"fromX":[NSNumber numberWithFloat:nStartX], @"fromY":[NSNumber numberWithFloat:nStartY], @"toX":[NSNumber numberWithFloat:endX], @"toY":[NSNumber numberWithFloat:endY], @"duration":[NSNumber numberWithFloat:(float)0.0]};
            
            requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/wda/dragfromtoforduration", BODY:body, SESSION_ID:self.sessionID};
        }
    }
    
    NSDictionary * result = [self syncRequest:requestData];
    
    if( result ) {
        DDLogInfo(@"성공");
        NSString * sessionId = [result objectForKey:@"sessionId"];
        if( sessionId)
            self.sessionID = sessionId;
        else
            NSLog(@"흠....");
        nStartX = 0;
        nStartY = 0;
        touchDate = nil;
    } else {
        NSLog(@"실패");
        
        DDLogError(@"Drag and Drop Error");
        if( 1001 == error.code ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:self.deviceInfos.deviceNo];
            });
        }
    }
}


/// @brief  멀티터치의 경우 WDA 에 줌 인/아웃 기능이 있지만, 줌아웃은 동작하지 명령을 보내지 않고 있다.  pinchWithScale 함수가 정상동작하지 않음.
- (void) doMultiTouchStartAtPoint1:(NSPoint)point1 andPoint2:(NSPoint)point2 {
    
}

- (void) doMultiTouchMoveAtPoint1:(NSPoint)point1 andPoint2:(NSPoint)point2 {
    
}

- (void) doMultiTouchEndAtPoint1:(NSPoint)point1 andPoint2:(NSPoint)point2 {
    
}

#pragma mark - 텍스트 입력
/// @brief  텍스트 입력  키보드 확인후 키보드가 있을경우 문자열을 넣어준다.
- (void)inputTextByString:(NSString *)string{
    if (!self.bLaunchDone || nil == _sessionID ) return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary* bodyKeyboard = @{@"using":@"class name",@"value":@"XCUIElementTypeKeyboard"};
        NSDictionary * requestKeyBoardData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/element", BODY:bodyKeyboard, SESSION_ID:self.sessionID};
        
        NSDictionary* resultKeyboard = [self syncRequest:requestKeyBoardData];
        
        NSLog(@"key resulst = %@",resultKeyboard);
        int nStatus = [[resultKeyboard objectForKey:@"status"] intValue];
        NSLog(@"nstatus = %d",nStatus);
        
        // 단일객체 검색일 경우.
        // "value" : {
        //   "ELEMENT" : "26DEC1C7-B1E5-4B96-B5ED-D7082A56CD2A"
        // },
        
        // 복수객체 검색일 경우
//        "value" : [
//            {
//                "ELEMENT" : "0A8D1D4A-9AC1-4BBD-B791-0FBAAE59AD56"
//            }
//        ],
        // 단일 객체를 검색했기 때문에 결과는 Array 가 아닌 Dictionary 가 된다.
        
        /*
        NSArray * tempArr = [resultKeyboard objectForKey:@"value"];
        int nValueCount = 0;
        if(tempArr != nil){
            nValueCount = (int)tempArr.count;
        }
         */
        NSDictionary * tmpDic = [resultKeyboard objectForKey:@"value"];
        bool bExistObject = NO;
        if( tmpDic ) {
//            nValueCount = (int)[tmpDic count];
            NSString * objectUuid = [tmpDic objectForKey:@"ELEMENT"];           // 객체가 없으면.. ELEMENT 정보가 없어 nil 이 나올거임.
            bExistObject = objectUuid ? YES : NO;
        }
        
        if( bExistObject ) {
            dispatch_sync(dispatch_get_main_queue(),^ {
                if( nStatus == 0 ) {
//                    NSString * decomposition = [Utility getHangulDecomposition:string];
//                    NSDictionary * body = @{@"value":@[decomposition]};
                    NSDictionary * body = @{@"value":@[string]};
                    
                    NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/wda/keys", BODY:body, SESSION_ID:self.sessionID};
                    NSDictionary * result = [self syncRequest:requestData];
                    if( result ) {
                        DDLogInfo(@"%s success", __FUNCTION__);
                        [[CommunicatorWithDC sharedDCInterface] commonResponse:YES deviceNo:self.deviceInfos.deviceNo];
                    } else {
                        NSLog(@"실패");
                        [[CommunicatorWithDC sharedDCInterface] commonResponse:NO deviceNo:self.deviceInfos.deviceNo];
                    }
                    
                    NSString * sessionId = [result objectForKey:@"sessionId"];
                    if( sessionId)
                        self.sessionID = sessionId;
                    else
                        NSLog(@"흠....");
                }else{
                    NSLog(@"키보드 없다 ");
                    
                }
            });
        }
    });
}

/// @brief  리모트 키보드 기능.. 입력받은 아스키코드값중 문자의 범위만 입력하도록 함.
/// @brief  해당 명령이 DC 에서 많이 들어오는데(정상이라함) 불필요한 명령도 있어서 범위를 지정함.
- (void)inputRemoteKeyboardByKey:(NSData *)key {
    // 기존 소스
    if (!self.bLaunchDone) return;
    
    DDLogWarn(@"CMD_INPUT_TEXT %@", key.description);
    /*
    SEBy *keypad = [SEBy className:@"XCUIElementTypeKeyboard"];
    SEWebElement *elemKeyboard = [self.myWebDriver findElementBy:keypad];
    
    if (elemKeyboard != nil) {
        DDLogWarn(@"inputText not nil");
        
        dispatch_async(self.webPerformQueue, ^{
            NSString * strToken = nil;
            uint32 * nTemp = (uint32 *)key.bytes;
            if( *nTemp > 64 && *nTemp < 91 ) {
                
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
            
            [self.myWebDriver sendKeys:strToken];
        });
    } else {
        DDLogError(@"inputText nil");
    }
     */
    
    NSString * strToken = nil;
    uint32 * nTemp = (uint32 *)key.bytes;
    if( *nTemp > 64 && *nTemp < 91 ) {
        char cToken = (char)*nTemp;
        strToken = [NSString stringWithFormat:@"%c", cToken];
        
        [self inputTextByString:strToken];
    }
}

/// @brief 자동화 기능에서 텍스트 입력 //ERROR체크사항 redmine올라와있는 사항으로 확인 해야함
- (void)autoInputText:(NSData *)data {
    
    SelectObject* obj = [self parsingAutoInputText:data];
    //NSString *elementLabel = nil;
    //bool bUseClassIndex = NO;
    
    @autoreleasepool {
//        NSDictionary * elem = [self getElementByTargetInfo:obj];
        NSDictionary* elem = [self getElementByTargetString:obj];
        //mg//BOOL bRes = NO;
        
        if(elem != nil) {
//            bRes = [self elementIsDisplayed:elem];
            // Scene 정보를 얻을 떄 어차피 보이는 부분만 있기 때문에 시간을 단축 할수 있다.
            //mg//
            /*bRes = YES;
            if( obj.scrollType != 0 && !bRes )
                bRes = [self scrollToView:elem ScrollObj:obj];
            
            if( bRes ){
             */
            
//                NSString * decomposition = [Utility getHangulDecomposition:obj.inputText];
//                NSDictionary * body = @{@"value":@[decomposition]};
            
            //mg//clear test
            /*NSString * strCmd2 = [NSString stringWithFormat:@"/element/%@/clear", [elem objectForKey:@"ELEMENT"]];
            NSDictionary* body2 = @{};

            NSDictionary * requestData2 = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:strCmd2, BODY:body2, SESSION_ID:self.sessionID};
             [self syncRequest:requestData2];
             */

            NSString* inputText = [NSString stringWithFormat:@"%@",[obj inputText]];
                NSDictionary * body = @{@"value":@[inputText]};
                
                NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/wda/keys", BODY:body, SESSION_ID:self.sessionID};
                NSDictionary * result = [self syncRequest:requestData];
            
                if( result ) {
                    [[CommunicatorWithDC sharedDCInterface] commonResponse:YES deviceNo:self.deviceInfos.deviceNo];
                    
                    NSString * sessionId = [result objectForKey:@"sessionId"];
                    DDLogVerbose(@"session id = %@", sessionId);
                    if( sessionId)
                        self.sessionID = sessionId;
                    else
                        NSLog(@"흠....");
                } else {
                    [[CommunicatorWithDC sharedDCInterface] commonResponse:NO deviceNo:self.deviceInfos.deviceNo];
                }
            
                //mg//텍스트 입력에서 불필요
                /*if( [obj.scrollClass caseInsensitiveCompare:@"Class"] == 0) {
                    bUseClassIndex = YES;
                    elementLabel = [self getElementAttribute:elem attribute:@"value"];
                }
                 */
            //}
        }//if : element
        
        //mg//텍스트 입력에서 불필요
        /*if( bUseClassIndex)
            [[CommunicatorWithDC sharedDCInterface] commonResponseClassIndex:bRes elemLabel:elementLabel deviceNo:deviceInfos.deviceNo];
         else
         */
            [[CommunicatorWithDC sharedDCInterface] commonResponse:NO deviceNo:deviceInfos.deviceNo];
    }//autoreleasepool
}//autoInputText


#pragma mark - 하드키 조작
/// @brief 하드키 동작
- (void)hardKeyEvent:(int)nKey longpress:(int)nType{
    DDLogInfo(@"%s, %d",__FUNCTION__, self.deviceInfos.deviceNo);
    DDLogInfo(@"%d",nKey);
    if (!self.bLaunchDone || nil == _sessionID ) return;
    
    // volume up/down 은 Onycap 에서 audio 자원을 점유하면서 컨트롤이 안됨.
    NSDictionary * requestData = nil;
    if(nKey == 24) //volume up
    {
        //  WDA 에 /wda/volumeup 명령을 받아서 처리하는 코드를 넣어줘야 함.
        requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/wda/volumeup"};
    }
    else if(nKey == 25) //volume down
    {
        //  WDA 에 /wda/volumedown 명령을 받아서 처리하는 코드를 넣어줘야 함.
        requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/wda/volumedown"};
        
    }
    else if ( 91 == nKey ) {        // mute -- UIAutomation 에 없는 기능.
        
    } else if ( 3 == nKey ) {       // home key
        if(nType == 2){
            requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/wda/homedouble"};
        }else{
            // Home 버튼을 누름.
            requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/wda/homescreen"};
        }
    }
//    //더블 홈버튼 클릭 기능 추가
//    else if( 4 == nKey){
//        NSLog(@"Double Click");
//        requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/wda/homedouble"};
//    }
    
    
//    else if ( 26 == nKey ) {
//        requestData = @{METHOD:@"GET", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:10.0f], CMD:@"/source"};
//    }
    
    if( !requestData )
        return ;
    
    NSDictionary* result = [self syncRequest:requestData];
    if( !result ) {
        DDLogInfo(@"%s, %d -- 결과 없음.", __FUNCTION__, self.deviceInfos.deviceNo);
        return ;
    }
    
    int nResult = [[result objectForKey:@"status"] intValue];
    if(nResult == 0){
        NSString * sessionId = [result objectForKey:@"sessionId"];
        if( sessionId)
            self.sessionID = sessionId;
        else
            NSLog(@"흠...");
        NSLog(@"성공 == %@",self.sessionID);
    }else{
        NSLog(@"실패");
        if( 1001 == nResult ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:self.deviceInfos.deviceNo];
            });
        }
    }
}

/// @brief  springboard 로 이동한다.
- (void) homescreen {
   if (!self.bLaunchDone || nil == _sessionID ) return;
    
    NSDictionary * requestData = requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/wda/homescreen"};
    
    if( !requestData )
        return ;
    
    NSDictionary* result = [self syncRequest:requestData];
    if( !result )
        return ;
    
    int nResult = [[result objectForKey:@"status"] intValue];
    if( !result ) {
        DDLogInfo(@"%s, %d -- 결과 없음.", __FUNCTION__, self.deviceInfos.deviceNo);
        return ;
    }
    
    if(nResult == 0){
        NSString * sessionId = [result objectForKey:@"sessionId"];
        if( sessionId)
            self.sessionID = sessionId;
        else
            NSLog(@"흠...");
        NSLog(@"성공 == %@",self.sessionID);
    }else{
        NSLog(@"실패");
        if( 1001 == nResult ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:self.deviceInfos.deviceNo];
            });
        }
    }
}

#pragma mark - Device 회전

/// @biref  portrate 상태인지 확인한다.
-(BOOL)devicePortrate{
    if (!self.bLaunchDone || nil == _sessionID ) return NO;
    
    NSString* command = [NSString stringWithFormat:@"/session/%@/orientation",self.sessionID];
    NSDictionary * requestData = @{METHOD:@"GET", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:command};
    NSDictionary * result = [self syncRequest:requestData];
    NSLog(@"회전상태 = %@",result);
    if(result){
        NSString* value = [result objectForKey:@"value"];
        if([value isEqualToString:@"PORTRAIT"]){
            return true;
        }
    }else{
        
    }
    return false;
}


/// @brief 회전 시킨다.
- (void)autoOrientation:(BOOL)bLand{
    if (!self.bLaunchDone || nil == _sessionID ) return;
    
    DDLogWarn(@"== 회전 == %d",bLand);
    
    DDLogInfo(@"%d",[self devicePortrate]);
    
    NSDictionary * body;
    if(bLand){
        body = @{@"orientation":@"LANDSCAPE"};
    }else{
        body = @{@"orientation":@"PORTRAIT"};
    }
    
    NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/orientation", BODY:body, SESSION_ID:self.sessionID};
    NSDictionary * result = [self syncRequest:requestData];
    
    NSString * sessionId = [result objectForKey:@"sessionId"];
    if( sessionId)
        self.sessionID = sessionId;
    else
        NSLog(@"흠....");
    
    int nStatus = [[result objectForKey:@"status"] intValue];
    if( 0 == nStatus ) {
        DDLogInfo(@"회전 성공");
    } else {
        DDLogInfo(@"%@", result);
        //swccc 회전 성공을 못했으니 다시 회전을 시도한다.
//        [self autoOrientation:bLand];
    }
}

/// @brief  화면정보를 가져온다.
/// @return xml 데이터
- (NSString *)getPageSource {
    DDLogInfo(@"%s", __FUNCTION__);
   
    if (!self.bLaunchDone || nil == _sessionID )
        return nil;
    
    NSDictionary * requestData = @{METHOD:@"GET", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:120.0f], CMD:@"/source"};
    
    //mg//
    //if( !requestData )
      //  return nil;
    
    NSDictionary * result = [self syncRequest:requestData];
    if( !result ) {
        DDLogError(@"none http response");
        return nil;
    }
    
    NSString * strValue = nil;
    int nResult = [[result objectForKey:@"status"] intValue];
    if(nResult == 0){
        NSString * sessionId = [result objectForKey:@"sessionId"];
        if( sessionId) {
            self.sessionID = sessionId;
            DDLogVerbose(@"session id = %@", sessionId);
        } else {
            NSLog(@"흠...");
        }
        
        NSString * resultValue = [result objectForKey:@"value"];
        DDLogVerbose(@"value : %@", resultValue);
        
        strValue = [resultValue stringByReplacingOccurrencesOfString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>" withString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><AppiumAUT>"];
        strValue = [strValue stringByAppendingString:@"</AppiumAUT>"];
    } else {
        DDLogError(@"error = %d", nResult);

        if( 1001 == nResult ) {
            //mg//dispatch_async(dispatch_get_main_queue(), ^{
                [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:self.deviceInfos.deviceNo];
            //});
        }
    }
    
    return strValue;
}

/// @brief bundleID 로 앱을 실행한다.
- (BOOL) autoRunApp:(NSString *)bundleId {
    return [self launchAppWithBundleID:bundleId];
}

/// @brief  스크린 이미지 한장을 가져온다.
- (NSData *)getScreenShot {
//    DDLogInfo(@"%s, %d",__FUNCTION__, self.deviceInfos.deviceNo);
    if (!self.bLaunchDone || nil == _sessionID ) return nil;
    
    NSDictionary * requestData = @{METHOD:@"GET", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/screenshot"};
    if( !requestData )
        return nil;
    
    NSDictionary * result = [self syncRequestSnapshot:requestData];
    if( !result ) {
        DDLogInfo(@"%s, %d -- 결과 없음.", __FUNCTION__, self.deviceInfos.deviceNo);
        return nil;
    }
    
    NSData * decodedImageData = nil;
    int nResult = [[result objectForKey:@"status"] intValue];
    if(nResult == 0){
        NSString * sessionId = [result objectForKey:@"sessionId"];
        if( sessionId)
            self.sessionID = sessionId;
        else
            NSLog(@"흠... 스크린샷 세선야이디 없음..");
//        NSLog(@"성공 == %@",self.sessionID);
        
        NSString * imageString = [result objectForKey:@"value"];
        decodedImageData = [[NSData alloc] initWithBase64EncodedString:imageString options:NSDataBase64DecodingIgnoreUnknownCharacters];
        
    }else{
        NSLog(@"실패");
        if( 1001 == nResult ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:self.deviceInfos.deviceNo];
            });
        }
    }
    
    return decodedImageData;
}

/// @brief orientaion 값을 확인한다.
/// @return 0, 1, 2
- (int) orientation {
    int orientation = 0;
    
//    DDLogInfo(@"%s, %d",__FUNCTION__, self.deviceInfos.deviceNo);
    if (!self.bLaunchDone || nil == _sessionID ) return 0;
    
    NSDictionary * requestData = @{METHOD:@"GET", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], SESSION_ID:_sessionID, CMD:@"/orientation"};
    
    if( !requestData )
        return nil;
    
    NSDictionary * result = [self syncRequest:requestData];
    if( !result ) {
        DDLogInfo(@"%s, %d -- 결과 없음.", __FUNCTION__, self.deviceInfos.deviceNo);
        return SELENIUM_SCREEN_ORIENTATION_UNKOWN;
    }
    
    NSString * value = nil;
    int nResult = [[result objectForKey:@"status"] intValue];
    if( 0 == nResult ) {
        NSString * sessionId = [result objectForKey:@"sessionId"];
        if( sessionId)
            self.sessionID = sessionId;
        else
            NSLog(@"흠...");
        
        return ([[result objectForKey:@"value"] isEqualToString:@"LANDSCAPE"] ? SELENIUM_SCREEN_ORIENTATION_LANDSCAPE :SELENIUM_SCREEN_ORIENTATION_PORTRAIT);
    } else {
        NSLog(@"%s -- 실패", __FUNCTION__);
        if( 1001 == nResult ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:self.deviceInfos.deviceNo];
            });
        }
    }
    
    return SELENIUM_SCREEN_ORIENTATION_UNKOWN;
}

/// @brief  엘리멘트의 위치정보를 가져온다.
/// @param element
- (CGRect) elementLocationInView:(NSDictionary *)element {
    if( nil == element ) {
        DDLogInfo(@"Element 정보가 없음!!");
        return CGRectZero;
    }
    
    NSString * strCmd = [NSString stringWithFormat:@"/element/%@/rect", [element objectForKey:@"ELEMENT"]];
    NSDictionary * requestData = @{METHOD:@"GET", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:strCmd, SESSION_ID:self.sessionID};
    
    NSDictionary * result = [self syncRequest:requestData];
    int nResult = [[result objectForKey:@"status"] intValue];
    if( 0 == nResult ) {
        DDLogInfo(@"성공");
        NSString * sessionId = [result objectForKey:@"sessionId"];
        if( sessionId)
            self.sessionID = sessionId;
        else
            NSLog(@"흠....");
        
        NSDictionary * value = [result objectForKey:@"value"];
        float y = [[value objectForKey:@"y"] floatValue];
        float x = [[value objectForKey:@"x"] floatValue];
        float width = [[value objectForKey:@"width"] floatValue];
        float height = [[value objectForKey:@"height"] floatValue];
        
        return CGRectMake(x, y, width, height);
    } else {
        DDLogError(@"LocationInView Error");
        if( 1001 == nResult ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:self.deviceInfos.deviceNo];
            });
        }
    }
    
    return CGRectZero;
}
/// @brief xPath 로 검색한 객체가 현재 화면에 보여지고 있는지 확인함.
- (BOOL) elementIsDisplayed:(NSDictionary *)element {
    if( nil == element ) {
        DDLogInfo(@"Element 정보가 없음!!");
        return NO;
    }
    
    NSString * strCmd = [NSString stringWithFormat:@"/element/%@/displayed", [element objectForKey:@"ELEMENT"]];
    NSDictionary * requestData = @{METHOD:@"GET", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:strCmd, SESSION_ID:self.sessionID};
    
    DDLogInfo(@"%s -- cmd : %@", __FUNCTION__, strCmd);
    
    // TO DO : Element 를 검색한 결과에 대한 확인을 하는 부분에서 검증이 이뤄지지 않았음.. 터미널에서 명령을 보내 출력된 결과를 가지고 데이터를 확인하여 아래와 같이 처리했지만.. 실제 프로그램에서 정상동작하는지는 확인을 하지 않았음.
    NSDictionary * result = [self syncRequest:requestData];
    int nResult = [[result objectForKey:@"status"] intValue];
    if( 0 == nResult ) {
        DDLogInfo(@"성공");
        NSString * sessionId = [result objectForKey:@"sessionId"];
        if( sessionId)
            self.sessionID = sessionId;
        else
            NSLog(@"흠....");
        
//        NSNumber * nbValue = [result objectForKey:@"value"] ;
//        if( nbValue.intValue ) {
//            return YES;
//        } else {
//            return NO;
//        }
        return YES;
    } else {
        NSLog(@"실패");
        
        DDLogError(@"IsDisplayed Error");
        if( 1001 == nResult ) {         //TimeOut
            dispatch_async(dispatch_get_main_queue(), ^{
                [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:self.deviceInfos.deviceNo];
            });
        }
    }
    
    return NO;
}

- (bool) scrollToView:(NSDictionary*)elem ScrollObj:(SelectObject*)obj
{
    CGRect rectElement = [self elementLocationInView:elem];
    
    NSString * dir;
    if(obj.scrollType == 1 ){ // vertical
        if( rectElement.origin.y < 0 )
            dir = @"up";
        else
            dir = @"down";
    } else { // horizontal
        if( rectElement.origin.x < 0 )
            dir = @"left";
        else
            dir = @"right";
    }
    
    NSDictionary* bodySwipe = @{@"direction":dir};
    NSString * strCmd = [NSString stringWithFormat:@"/wda/element/%@/swipe", [elem objectForKey:@"ELEMENT"]];
    NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], BODY:bodySwipe, CMD:strCmd, SESSION_ID:self.sessionID};
    
    DDLogInfo(@"%s -- cmd : %@", __FUNCTION__, strCmd);
    
    int retry = obj.scrollCount;
    bool bView = false;
    
    do {
        [self syncRequest:requestData];
        bView = [self elementIsDisplayed:elem];
    } while (!bView && retry-- > 0);
    
    return bView;
}

//mg//
/// @brief  DC 에서 넘겨준 객체정보로 객체를 찾는다.
/*- (void)automationSearch:(NSData *)data andSelect:(BOOL)bSelect{
    DDLogDebug(@"%s", __FUNCTION__);
    
    if(!self.bLaunchDone) {
        [[CommunicatorWithDC sharedDCInterface] commonResponse:NO deviceNo:deviceInfos.deviceNo];
        return;
    }
    
    SelectObject* obj = [self automationSearchParsing:data andSelect:bSelect];
    NSString *elementLabel = nil;
    bool bUseClassIndex = NO;

    @autoreleasepool {
        //검색방식 xpath
//        NSDictionary * elem = [self getElementByTargetInfo:obj];
        
        NSDictionary* elem = nil;
            //검색방식 String
            elem = [self getElementByTargetString:obj];
            
        BOOL bRes = NO;
        
        if(elem != nil){
//            bRes = [self elementIsDisplayed:elem];
            //Scene 할때 어차피 보이는 부분이기 때문에 할 필요 없다.
            bRes = YES;
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
//                    elementLabel = [self getElementAttribute:elem attribute:@"value"];
                    elementLabel = [self getElementAttributeName:elem attribute:@"name"];
                    DDLogInfo(@"label = %@",elementLabel);
                    
                }//if : class search
            }//if : search succeeded
        }//if : search succeeded
        
        if( bUseClassIndex) {
            [[CommunicatorWithDC sharedDCInterface] commonResponseClassIndex:bRes elemLabel:elementLabel deviceNo:deviceInfos.deviceNo];
        } else {
            [[CommunicatorWithDC sharedDCInterface] commonResponse:bRes deviceNo:deviceInfos.deviceNo];
        }
    }//autoreleasepool
}//automationSearch
*/

//mg//
/// @brief  DC 에서 넘겨준 객체정보로 객체를 찾는다.
- (void)automationSearch:(NSData *)data andSelect:(BOOL)bSelect{
    DDLogDebug(@"%s", __FUNCTION__);

    if(!self.bLaunchDone) {
        [[CommunicatorWithDC sharedDCInterface] commonResponse:NO deviceNo:deviceInfos.deviceNo];
        return;
    }

    SelectObject* obj = [self automationSearchParsing:data andSelect:bSelect];
    NSString *elementLabel = nil;

    @autoreleasepool {
        NSDictionary* elem = nil;
        
        if ([obj.scrollClass caseInsensitiveCompare:@"Pattern"] == 0)
            elem = [self getElementByPattern:obj];
        else{
            elem = [self getElementByTargetString:obj];
        }
        
        if(elem == nil){
            DDLogInfo(@"elem 검색 실패");
//            elem = [self getElementByTargetInfo:obj];
        }else{
            DDLogInfo(@"elem 검색 성공");
        }
        
        if(elem != nil){
            BOOL bPress = YES;
            if(bSelect)
                bPress = [self pressElement:elem isLong:(obj.longPress==1)? YES:NO];
            
            if( [obj.scrollClass caseInsensitiveCompare:@"Text"] != 0) {
                elementLabel = [self getElementAttributeName:elem attribute:@"name"];
                DDLogInfo(@"label = %@",elementLabel);
                
                [[CommunicatorWithDC sharedDCInterface] sendResponse:YES message:elementLabel deviceNo:deviceInfos.deviceNo];
                
                //mg//search test
                /*for (int j=0; j<elementLabel.length; ++j)
                 DDLogVerbose(@"%d", [elementLabel characterAtIndex:j]);
                 
                 SelectObject* obj2 = [[SelectObject alloc] init];
                 obj2.scrollType  = 0;
                 obj2.scrollCount  = 0;
                 obj2.scrollPath= @"";
                 obj2.scrollClass = @"";
                 obj2.instance = 0;
                 obj2.targetValue =@"";
                 obj2.targetName= elementLabel;
                 obj2.targetLabel = obj2.targetName;
                 obj2.targetClass = [self getElementAttributeName:elem attribute:@"type"];
                     
                     NSDictionary* elem2 = [self getElementByTargetString:obj2];
                     if (elem2 != nil)
                     DDLogVerbose(@"label2 = %@",[self getElementAttributeName:elem2 attribute:@"name"]);
                     */
            }//if : class, pattern search
            
            else{
                if(bPress){
                    [[CommunicatorWithDC sharedDCInterface] commonResponse:YES deviceNo:deviceInfos.deviceNo];
                }else{
                    [[CommunicatorWithDC sharedDCInterface] commonResponse:NO deviceNo:deviceInfos.deviceNo];
                }
            }
        }//if : succeeded
        else{
            [[CommunicatorWithDC sharedDCInterface] commonResponse:NO deviceNo:deviceInfos.deviceNo];
        }
    }//autoreleasepool
}//automationSearch


- (NSString *) getElementAttributeName:(NSDictionary *)elem attribute:(NSString *)attribute {
    NSDictionary* bodySwipe = @{@"duration":@2.0f};
    NSString * strCmd = [NSString stringWithFormat:@"/element/%@/attribute/%@", [elem objectForKey:@"ELEMENT"], attribute];
    
//    NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], BODY:bodySwipe, CMD:strCmd, SESSION_ID:self.sessionID};

    NSDictionary * requestData = @{METHOD:@"GET", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], SESSION_ID:_sessionID, CMD:strCmd};
    NSDictionary * result = [self syncRequest:requestData];

    
    DDLogInfo(@"%s -- cmd : %@", __FUNCTION__, strCmd);
    
    int nResult = [[result objectForKey:@"status"] intValue];
    if( 0 == nResult ) {
        DDLogInfo(@"성공");
        NSString * sessionId = [result objectForKey:@"sessionId"];
        if( sessionId)
            self.sessionID = sessionId;
        else
            NSLog(@"흠....");
        
        return [result objectForKey:@"value"];
    } else {
        NSLog(@"실패");
        
        DDLogError(@"Press Long Error");
        if( 1001 == nResult ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:self.deviceInfos.deviceNo];
            });
        }
        
    }
    return nil;
}

/// @brief  객체에서 attribute 정보를 가져온다.
/// @param  elem xPath 로 찾은 객체
/// @param  attribute 검색할 Attribute
- (NSString *) getElementAttribute:(NSDictionary *)elem attribute:(NSString *)attribute {
    NSDictionary* bodySwipe = @{@"duration":@2.0f};
    NSString * strCmd = [NSString stringWithFormat:@"/element/%@/attribute/%@", [elem objectForKey:@"ELEMENT"], attribute];
    
    NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], BODY:bodySwipe, CMD:strCmd, SESSION_ID:self.sessionID};
    
    DDLogInfo(@"%s -- cmd : %@", __FUNCTION__, strCmd);
    
    NSDictionary * result = [self syncRequest:requestData];
    int nResult = [[result objectForKey:@"status"] intValue];
    if( 0 == nResult ) {
        DDLogInfo(@"성공");
        NSString * sessionId = [result objectForKey:@"sessionId"];
        if( sessionId)
            self.sessionID = sessionId;
        else
            NSLog(@"흠....");
        
        return [result objectForKey:@"value"];
    } else {
        NSLog(@"실패");
        
        DDLogError(@"Press Long Error");
        if( 1001 == nResult ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:self.deviceInfos.deviceNo];
            });
        }
        
    }
    return nil;
}

/// @brief 자동화 기능에서 사용하며 xPath 로 찾은 객체 정보로 탭/롱프레스 를 한다.
/// @param elem xPath 로 검색해서 찾은 객체
/// @param pressLong 롱프레스로 탭을 한다.
- (BOOL)pressElement:(NSDictionary *)elem isLong:(BOOL)pressLong {
    
    DDLogInfo(@"pressElem(%d)", pressLong);

    NSDictionary * result = nil;
    
    if(pressLong){
        NSDictionary* bodySwipe = @{@"duration":@2.0f};
        NSString * strCmd = [NSString stringWithFormat:@"/wda/element/%@/touchAndHold", [elem objectForKey:@"ELEMENT"]];
        NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], BODY:bodySwipe, CMD:strCmd, SESSION_ID:self.sessionID};
        
        DDLogInfo(@"%s -- cmd : %@", __FUNCTION__, strCmd);
        
        result = [self syncRequest:requestData];
    }
    else {
//        NSString * strCmd = [NSString stringWithFormat:@"/element/%@/click", [elem objectForKey:@"ELEMENT"]];
//        NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:strCmd, SESSION_ID:self.sessionID};
        
        NSDictionary* bodySwipe = @{@"duration":@0.1f};
        //옥수수를 위하여 Click으로 잠시 변경 swccc
        // 자동화에서는 TouchAndHold보다 Click 이벤트를 줄떄 객체를 선택 및 터치 확률이 높음 계속 유지할 것

        NSString * strCmd = [NSString stringWithFormat:@"/wda/element/%@/touchAndHold", [elem objectForKey:@"ELEMENT"]];

        NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], BODY:bodySwipe, CMD:strCmd, SESSION_ID:self.sessionID};
        
        DDLogInfo(@"%s -- cmd : %@", __FUNCTION__, strCmd);
        
        result = [self syncRequest:requestData];
    }
    
    int nResult = [[result objectForKey:@"status"] intValue];
    
    if( 0 == nResult ) {
        DDLogInfo(@"성공");
        NSString * sessionId = [result objectForKey:@"sessionId"];
        if( sessionId)
            self.sessionID = sessionId;
        else
            NSLog(@"흠....");
        
        return YES;
    } else {
        NSLog(@"실패");
        
        DDLogError(@"Press Long Error = %d", nResult);
        if( 1001 == nResult ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:self.deviceInfos.deviceNo];
            });
        }
        
        return NO;
    }
}

#pragma mark -
#pragma mark Parsing Received Data
/// @brief DC 에서 전달받은 객체정보를 파싱한다.
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

/// @brief DC 에서 전달받은 객체정보를 파싱한다.
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
//        obj.instance = CFSwapInt16HostToBig(*(short *)([pInstance bytes]));
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

/// @brief  iOS 9.x 이하 버전의 UIAutomation 과 iOS 10.x 의 XCUITest 의 엘리멘트 이름을 치환해줌.
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

//mg
// @brief link text로 WDA에 검색을 요청하여 찾는다.
// @param obj 객체 정보
/*-(NSDictionary *)getElementByTargetString:(SelectObject *)obj{
    
//    curl -X POST $JSON_HEADER \
//    -d "{\"using\":\"predicate string\",\"value\":\"wdVisible==1 AND type=='XCUIElementTypeButton' AND label='브랜드'\"}" \
//    $DEVICE_URL/session/7E46BFA0-D7FC-46DA-B4AC-32D8D17D08B0/elements
    
//    NSMutableString * temp = [NSMutableString stringWithFormat:@"//%@", obj.targetClass];
//    NSMutableString* temp = [NSMutableString stringWithFormat:@"wdVisible==1 AND type==\'%@\' AND label='%@'", obj.targetClass, obj.targetLabel];
    
    DDLogDebug(@"%s", __FUNCTION__);
    
    NSArray* arrayElem = nil;
    NSMutableString* temp = [[NSMutableString alloc] init];

    if( obj.targetName.length || obj.targetValue.length ) {
        if(obj.targetName.length > 0)
            temp = [NSMutableString stringWithFormat:@"type==\'%@\' AND name='%@'", obj.targetClass, obj.targetName];
        else
            temp = [NSMutableString stringWithFormat:@"type==\'%@\' AND value='%@'", obj.targetClass, obj.targetValue];
    }else
        //Visible이
//        temp = [NSMutableString stringWithFormat:@"wdVisible==1  AND type==\'%@\' ", obj.targetClass];
        temp = [NSMutableString stringWithFormat:@"type==\'%@\' ",obj.targetClass];

    NSDictionary * body = @{@"using":@"predicate string", @"value":temp};
    DDLogVerbose(@"search query = %@", temp);
    
    NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/elements", BODY:body, SESSION_ID:self.sessionID};
    
    NSDictionary * result = [self syncRequest:requestData];
    DDLogDebug(@"getElementByTargetInfo result = %@",result);
    if (result == nil)
        return nil;
    
    int nStatus = [[result objectForKey:@"status"] intValue];
    if( 0 == nStatus ) {
        DDLogDebug(@"성공");
        arrayElem = [result objectForKey:@"value"];
    } else
        DDLogDebug(@"실패");
    
    NSString * sessionId = [result objectForKey:@"sessionId"];
    if( sessionId)
        self.sessionID = sessionId;
    else
        NSLog(@"흠...");
    
    if (arrayElem == nil || arrayElem.count ==0) {
        DDLogInfo(@"findElementsBy Failed class='%@' name='%@' value='%@'", obj.targetClass, obj.targetName, obj.targetValue);
        return nil;
    } else { // filter targetClass match
        //        long classCount = arrayElem.count;
        //        int classIndex = obj.instance;
        if(arrayElem.count > 1) {
            DDLogInfo(@"found %lu elements", arrayElem.count);
            DDLogInfo(@"object info : name:%@, label:%@, value:%@, index:%d",
                      obj.targetName, obj.targetLabel, obj.targetValue, obj.instance);
            
            if( obj.instance >= arrayElem.count ) {
                DDLogError(@"검색결과 보다 찾는 위치가 큼.. 다른 UI 수 있음.");
                return nil;
            }
            //obj.instance 가 array 의 카운트보다 높게 나올경우 죽는다 ERROR 확인
            return [arrayElem objectAtIndex:(int)obj.instance];
        } else {
            return [arrayElem objectAtIndex:0];
        }
    }//if - else : array
}//getElementByTargetString
*/

//mg
// @brief link text로 WDA에 검색을 요청하여 찾는다.
// @param obj 객체 정보
-(NSDictionary *)getElementByTargetString:(SelectObject *)obj{
    DDLogDebug(@"%s", __FUNCTION__);
    
    //query
    NSMutableString* temp = [[NSMutableString alloc] init];
    temp = [NSMutableString stringWithFormat:@"type == '%@'", obj.targetClass];// AND visible == 1
//    temp = [NSMutableString stringWithFormat:@"wdVisible==1 AND type == '%@'", obj.targetClass];// AND visible == 1
    //        temp = [NSMutableString stringWithFormat:@"wdVisible==1  AND type==\'%@\' ", obj.targetClass];
    
    DDLogVerbose(@"type=%@ name=%@ value=%@ label=%@ instance=%d", obj.targetClass, obj.targetName, obj.targetValue, obj.targetLabel, obj.instance);
    
    if( obj.targetName.length >0)
        [temp appendString:[NSMutableString stringWithFormat:@" AND name='%@' AND wdVisible==1", obj.targetName]];
    //mg//substring test//[temp appendString:[NSMutableString stringWithFormat:@" AND name CONTAINS[c] '%@'", obj.targetName]];
    else if(obj.targetValue.length >0)
        [temp appendString:[NSMutableString stringWithFormat:@" AND value='%@' AND wdVisible==1", obj.targetValue]];
    else
        [temp appendString:[NSMutableString stringWithFormat:@" AND wdVisible==1"]];
//    if( obj.targetName.length >0)
//        [temp appendString:[NSMutableString stringWithFormat:@" AND name='%@'", obj.targetName]];
//    //mg//substring test//[temp appendString:[NSMutableString stringWithFormat:@" AND name CONTAINS[c] '%@'", obj.targetName]];
//    else if(obj.targetValue.length >0)
//        [temp appendString:[NSMutableString stringWithFormat:@" AND value='%@'", obj.targetValue]];
//    else
//        [temp appendString:[NSMutableString stringWithFormat:@" AND wdVisible==1"]];
    
    //http request
    NSDictionary * body = @{@"using":@"predicate string", @"value":temp};
    DDLogVerbose(@"search query : %@", temp);
    
    //mg//timeout TIMEOUT_COMMAND->30
    NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:30.0f], CMD:@"/elements", BODY:body, SESSION_ID:self.sessionID};
    
    //response
    NSDictionary * result = [self syncRequest:requestData];
    DDLogDebug(@"response : %@",result);
    if (result == nil)
        return nil;
    
    //status
    int nStatus = [[result objectForKey:@"status"] intValue];
    DDLogDebug(@"status=%d", nStatus);
    if( 0 != nStatus )
        return nil;
    
    //element list
    NSArray* arrayElem = [result objectForKey:@"value"];
    
    //session id
    NSString * sessionId = [result objectForKey:@"sessionId"];
    DDLogDebug(@"session id = %@",sessionId);
    if( sessionId)
        self.sessionID = sessionId;
    
    if (arrayElem == nil || arrayElem.count ==0) {
        DDLogInfo(@"none element");
        return nil;
    } else { // filter targetClass match
        if(arrayElem.count > 1) {
            DDLogDebug(@"element count = %lu", arrayElem.count);
            //element count
            if( obj.instance >= arrayElem.count ) {
                DDLogError(@"items insufficient");
                return nil;
            }

            return [arrayElem objectAtIndex:(int)obj.instance];
        } else {
            return [arrayElem objectAtIndex:0];
        }//if - else : element count
    }//if - else : array
}//getElementByTargetString

//mg//
-(NSDictionary *)getElementByPattern:(SelectObject *)obj{
    DDLogDebug(@"%s", __FUNCTION__);
    
    //query
    NSMutableString* temp = [[NSMutableString alloc] init];
    temp = [NSMutableString stringWithFormat:@"type == '%@'", obj.targetClass];// AND visible == 1
    
    DDLogVerbose(@"type=%@ name=%@ value=%@ label=%@ instance=%d", obj.targetClass, obj.targetName, obj.targetValue, obj.targetLabel, obj.instance);
    
    //http request
    NSDictionary * body = @{@"using":@"predicate string", @"value":temp};
    DDLogVerbose(@"search query : %@", temp);
    
    NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:30.0f], CMD:@"/elements", BODY:body, SESSION_ID:self.sessionID};
    
    //response
    NSDictionary * result = [self syncRequest:requestData];
    DDLogDebug(@"response : %@",result);
    if (result == nil)
        return nil;
    
    //status
    int nStatus = [[result objectForKey:@"status"] intValue];
    DDLogDebug(@"status=%d", nStatus);
    if( 0 != nStatus )
        return nil;
    
    //element list
    NSArray* arrayElem = [result objectForKey:@"value"];
    
    //session id
    NSString * sessionId = [result objectForKey:@"sessionId"];
    DDLogDebug(@"session id = %@",sessionId);
    if( sessionId)
        self.sessionID = sessionId;
    
    if (arrayElem == nil || arrayElem.count ==0) {
        DDLogInfo(@"none element");
        return nil;
    } else {
        //"\\[.+?\\]"
        NSRegularExpression *regex = nil;
        NSDictionary* elem = nil;
        NSString *txt = nil;
        NSArray *matches = nil;
        
        //name pattern
        if( obj.targetName.length >0) {
            regex = [NSRegularExpression regularExpressionWithPattern:obj.targetName options:0 error:nil];

            for (int i=0; i< arrayElem.count; ++i) {
                //element
                elem = [arrayElem objectAtIndex:i];
                txt = [self getElementAttributeName:elem attribute:@"name"];
                
                DDLogVerbose(@"name=%@", txt);
                
                NSRange matchRange = [regex rangeOfFirstMatchInString:txt options:0 range:NSMakeRange(0, [txt length])];
                // Did we find a matching range
                if (matchRange.location != NSNotFound) {
                    //부분 문자열이 아니라, 전체 문자열이 일치하는 경우 성공
                    if (matchRange.length == [txt length])
                        return elem;
                }
                
                //matches = [regex matchesInString:txt options:0 range:NSMakeRange(0, [txt length])];
                //if ([matches count] > 0)
            }
        }
        //value pattern
        else if(obj.targetValue.length >0) {
            regex = [NSRegularExpression regularExpressionWithPattern:obj.targetValue options:0 error:nil];
 
            for (int i=0; i< arrayElem.count; ++i) {
                //element
                elem = [arrayElem objectAtIndex:i];
                txt = [self getElementAttributeName:elem attribute:@"value"];
                
                DDLogVerbose(@"value=%@", txt);
                
                NSRange matchRange = [regex rangeOfFirstMatchInString:txt options:0 range:NSMakeRange(0, [txt length])];
                // Did we find a matching range
                if (matchRange.location != NSNotFound) {
                    //부분 문자열이 아니라, 전체 문자열이 일치하는 경우 성공
                    if (matchRange.length == [txt length])
                        return elem;
                }
            }
        }//if - else :
    }//if - else : array
    
    return nil;
}//getElementByPattern
    
//mg//
/*-(NSString *)getElementByScene:(SelectObject *)obj{
    DDLogDebug(@"%s", __FUNCTION__);
    
    NSString *page = [self getPageSource];
    NSString *strType = [NSString stringWithFormat:@"type=\"%@\"", obj.targetClass];
    
    NSRange subRange;
    NSRange searchCharRange = NSMakeRange(0, [page length]);
    int idx=0;
    
    while (YES) {
        subRange = [page rangeOfString:strType options:0 range:searchCharRange];

        if (subRange.location == NSNotFound)
            break;
        
        if (idx == obj.instance)
            break;
        ++idx;

        searchCharRange = NSMakeRange(subRange.location +1, [page length] - subRange.location -1);
    }
    
    subRange = [page rangeOfString:@"<" options:NSBackwardsSearch range:NSMakeRange(0, subRange.location)];
    idx = subRange.location;
    
    subRange = [page rangeOfString:@">" options:0 range:NSMakeRange(subRange.location, [page length])];
    
    return page substringWithRange:NSMakeRange(idx, subRange.location);
}//getElementByScene
*/

/// @brief  xpath 로 WDA 에 검색을 요청하여 찾는다.
/// @param obj 객체정보
- (NSDictionary *)getElementByTargetInfo:(SelectObject *)obj {
    DDLogDebug(@"%s", __FUNCTION__);
    
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
        
        NSDictionary * body = @{@"using":@"xpath", @"value":xPath};
//        NSDictionary* body = nil;
//        if(obj.targetName.length > 0 || obj.targetValue.length > 0){
//            body = @{@"using":@"xpath", @"value":xPath};
//        }else{
//            body = @{@"using":@"class name",@"value":obj.targetClass};
//        }
        
        
        NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/elements", BODY:body, SESSION_ID:self.sessionID};
        NSDictionary * result = [self syncRequest:requestData];
        DDLogInfo(@"getElementByTargetInfo result = %@",result);
        
        int nStatus = [[result objectForKey:@"status"] intValue];
        if( 0 == nStatus && result != nil) {
            DDLogInfo(@"성공");
            arrayElem = [result objectForKey:@"value"];
        } else {
            DDLogInfo(@"실패");
            arrayElem = nil;
        }
        NSString * sessionId = [result objectForKey:@"sessionId"];
        if( sessionId)
            self.sessionID = sessionId;
        else
            NSLog(@"흠...");
        
        
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
            
            
            if( obj.instance >= arrayElem.count ) {
                DDLogError(@"검색결과 보다 찾는 위치가 큼.. 다른 UI 수 있음.");
                return nil;
            }
            //obj.instance 가 array 의 카운트보다 높게 나올경우 죽는다 ERROR 확인
            return [arrayElem objectAtIndex:obj.instance];
        } else {
            return [arrayElem objectAtIndex:0];
        }
    }
}

- (NSString *)safariAddressElemSessionId:(NSString *)url{
    DDLogInfo(@"%s | %@",__FUNCTION__,self.sessionID);
    
    NSMutableString * xPath = [NSMutableString stringWithFormat:@"//%@", @"XCUIElementTypeButton"];
    
    [xPath appendString:[NSString stringWithFormat:
                         @"[%@]",
                         [NSString stringWithFormat:@"@label=\"%@\"", @"주소"]]];
    
    DDLogInfo(@"xPath = %@",xPath);
    
    NSDictionary * body = @{@"using":@"xpath", @"value":xPath};
    NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/element", BODY:body, SESSION_ID:self.sessionID};
    NSDictionary * result = [self syncRequest:requestData];
    DDLogInfo(@"getElementByTargetInfo result = %@",result);
    
    int nStatus = [[result objectForKey:@"status"] intValue];

    NSString* sessionId = [result objectForKey:@"sessionId"];

    DDLogInfo(@"nStatus = %d and SessionId = %@ and result SessionId = %@",nStatus,self.sessionID,sessionId);
    if([sessionId isEqualToString:self.sessionID] && nStatus == 0){
        NSString* elementId = [[result objectForKey:@"value"] objectForKey:@"ELEMENT"];
        DDLogInfo(@"### elementId = %@ ####",elementId);
        [self movetoURL:url addressElem:elementId];
    }else{
        self.sessionID = [NSString stringWithFormat:@"%@",sessionId];
        [self safariAddressElemSessionId:url];
    }
    
    return nil;
}

- (void)openURL:(NSString *)url{
    
    NSDictionary * body = @{@"url":url};;
    
    NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/url", BODY:body, SESSION_ID:self.sessionID};
    NSDictionary * result = [self syncRequest:requestData];
    
    NSString * sessionId = [result objectForKey:@"sessionId"];
    if( sessionId)
        self.sessionID = sessionId;
    else
        NSLog(@"흠....");
    
    int nStatus = [[result objectForKey:@"status"] intValue];
    if( 0 == nStatus ) {
        DDLogInfo(@"사파리오픈성공");
    } else {
        DDLogInfo(@"%@", result);
    }
}

-(BOOL)movetoURL:(NSString *)url addressElem:(NSString * )elemId{
    NSString* temp = [[url componentsSeparatedByString:@"|"] objectAtIndex:1];
    NSString* moveUrl = [NSString stringWithFormat:@"%@\n",temp];
    NSDictionary * body = @{ @"value":moveUrl};
    NSDictionary * requestData = @{METHOD:@"POST", PORT:[NSNumber numberWithInt:_portNum], TIME_OUT:[NSNumber numberWithFloat:TIMEOUT_COMMAND], CMD:@"/value", BODY:body, SESSION_ID:self.sessionID, ELEMENT_ID:elemId};
    NSDictionary * result = [self syncRequest:requestData];
    
    DDLogInfo(@"%s = %@",__FUNCTION__,result);
    
    return true;
}

@end
