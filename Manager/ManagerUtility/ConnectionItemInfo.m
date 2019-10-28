//
//  ConnectionItemInfo.m
//  Manager
//
//  Created by User on 6/30/15.
//  Copyright (c) 2015 tomm. All rights reserved.
//

#import "ConnectionItemInfo.h"
#import "Selenium.h"
#import "AppDelegate.h"
#import "DeviceLog.h"
#import "CommunicatorWithDC.h"
#import "CommunicatorWithIProxy.h"

#import "TaskHandler.h"

#import "HHURLConnection.h"

#import "DeviceInfo.h"
#import "Utility.h"

#include <math.h>
#import "ControlAgent.h"
#import "AppiumControlAgent.h"
#import "WebDriverControlAgent.h"
#import "InstrumentsControlAgent.h"

#import "ResourceMornitor.h"
#import "10HighVerResourceMornitor.h"
#import "AppInstaller.h"

//#import "ScreenCapture.h"
#import "CommunicatorWithVPS.h"

#define MAX_LAUNCH_TRY_COUNT        5


@interface ConnectionItemInfo () <DeviceInfosDelegate, CommunicatorWithIProxyDelegate, ControlAgentDelegate, DeviceLogDelegate> {
    ConnectionItemInfo* w_self;
}

/// @brief  ControlAgent 인터페이스 객체
@property (nonatomic, strong) ControlAgent      * myAgent;

/// @brief  리소스모니터 인터페이스 객체
@property (nonatomic, strong) ResourceMornitor  * myResource;
//@property (nonatomic, strong) ScreenCapture     * mySCapture;

/// @brief  VPS 와 통신하는 인스턴스... 멀티제어기능을 사용할때, 폴링방법을 선택해야 하며, 일정한 주기로 idevice 스크린을 캡쳐해서 VPS 로 전송함.
@property (nonatomic, strong) CommunicatorWithVPS   * myComuVps;

/// @brief  ResourceMornitor 와 Socket 통신을 하기 위해 사용하며, 내부적으로 iProxy 를 사용하여 USB 터널링을 하여 USB 로 Socket 통신을 하게 된다.
@property (nonatomic, strong) CommunicatorWithIProxy    * cmtIProxy;

/// @brief  Start 후 DC 로 부터 AppList 커멘드가 왔을때, 앱정보들을 가져와 리스트로 구성함... STOP 명령이 들어와 앱을 삭제하는 경우 다시 한번 앱정보들을 가져와 2개의 값을 비교하여 새로 추가된 앱들만 추려내서 삭제 하게됨.
//mg//@property (nonatomic, strong) NSArray       * myAppList;

// swccc
@property (nonatomic, strong) NSArray       * deviceInitAppList;


/// @brief  현재 사용하지 않는 타이머
@property (nonatomic, strong) NSTimer       * detachTimer;

/// @brief  리소스모니터 앱과의 소켓 연결 상태
@property (atomic,    assign) BOOL          bConnectedResourceApp;

/// @brief  HTTP 다운로드 성공 Noti 이름
@property (nonatomic, strong) NSString      * NAME_DOWN_SUCCESS;

/// @brief  HTTP 다운로드 실패 Noti 이름
@property (nonatomic, strong) NSString      * NAME_DOWN_FAIL;

/// @brief  사파리 오픈하면서 이동시킬 URL 정보
@property (nonatomic, strong) NSString      * openURL;

/// @brief  RemoteKeyboard 기능에 사용하려고 만들었는데.. 만들다 중지 하여 동잗하지 않음. 자세한 내용은 해당 구현함수에 있음.
@property (nonatomic, strong) NSTimer       * remoteInputTimer;

/// @brief  사용안함.
@property (nonatomic, assign) int           remoteKeyType;


/// @brief  이건 뭐하는 변수인지 모르겟음..
@property (nonatomic, strong) NSString      * sessionID;

/// @brief  launchedAppInfos 메소드에 자세한 내용이 있음
@property (nonatomic, strong) NSMutableDictionary * dicBundleIDs;

/// @brief  비동기 처리
@property (nonatomic, strong) dispatch_queue_t launchedAppQueue;

- (NSString *)managerDirectoryForDevice;
- (void)removeDeviceDirectoryFile;
- (void)suceessFileDownload : (NSNotification* )noti;
- (void)failFileDownload;

@end

/// @brief 각각의 디바이스 제어를 위해 사용함. (실제 디바이스 제어는 ControlAgent 에서 이뤄짐.)
@implementation ConnectionItemInfo
@synthesize customDelegate;
@synthesize dicKorTokens;

/// @brief      초기화
- (id) init {
    if (self = [super init]) {
        
        _connectType = CNNT_TYPE_NONE;
        _myDeviceLog = nil;
//mg//        _myAppList = nil;
        self.bConnectedResourceApp = NO;
        _cmtIProxy = nil;
        
        w_self = self;
        
        _NAME_DOWN_SUCCESS = nil;
        _NAME_DOWN_FAIL = nil;
        
        _bInstalling = NO;                  // 인스톨 중 일 때 End 가 들어오면 예외 처리하기 위해서 넣어둠.
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:ApplicationWillTerminateNotification object:nil];      // add by leehh
        
        _openURL = nil;
        
        _dicBundleIDs = [NSMutableDictionary dictionary];
        _dicAgentInfos = nil;
        
        _myComuVps = nil;
        _launchedAppQueue = dispatch_queue_create("LaunchedAppQueueu", NULL);
        
        
        _deviceInitAppList = nil;
    }
    return self;
}

/// @brief      지금은 필요없으나.. 습관 처럼 해둠..
- (void) dealloc {
    DDLogWarn(@"%s, %d", __FUNCTION__, self.deviceInfos.deviceNo);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ApplicationWillTerminateNotification object:nil];
    [self unRegisterFileNotification];
    
    if( _cmtIProxy )
        [_cmtIProxy stopIProxyTask];
    
    self.bConnectedResourceApp = NO;
    _launchedAppQueue = nil;
}

#pragma mark - <User Functions>

/// @brief      Agent 실행
- (void)startAgentManual:(BOOL)isManual
{
    DDLogDebug(@"%s", __FUNCTION__);
    
    if (isManual) {
        _connectType = CNNT_TYPE_MAN;
    } else {
        _connectType = CNNT_TYPE_AUTO;
    }
    
    [_myAgent settingBeforeLaunch];
    [_myAgent launchControlAgent];
}

/// @brief      Agent 종료, 관련 타스크 정리 및 메모리 정리
- (void)stopAgent {
    DDLogDebug(@"%s", __FUNCTION__);
    
    if( _bInstalling )
        [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:NO appId:@"Install중 Stop이 들어옴." deviceNo:_deviceInfos.deviceNo];
    
    [_cmtIProxy stopIProxyTask];
    [_myAgent finishControlAgent:_dicBundleIDs];
    
    if (self.myDeviceLog) {
        [self.myDeviceLog killLogProcess];
        self.myDeviceLog = nil;
    }
    
    self.openURL = nil;
    self.bConnectedResourceApp  = NO;
    
    if( _dicBundleIDs.count ) {
        [_dicBundleIDs removeAllObjects];
    }
    
    [self clearProcess];        // TestForte 작업이 완료되면 정리한다... TestForte 작업중 Manager 를 종료시 이 블록은 호출되지 않아 해당 프로세스들이 완전히 정맇됬는지는 확인을 못하지만, 다음 Manager 실행시 이전에 작업했던 프로세스를 검사하여 정리해주기 때문에 안정적으로 돌아가게 된다.
    
    [self removeDeviceDirectoryFile];
}


/// @brief      Agent 를 선택적으로 생성함.
/// @brief      Instruments 와 WebDriverAgent 로 나뉘면 될텐데.. Appium을 넣은건.. Appium 에서 처리하는 데이터를 로그상으로 확인 할 상황이 생길 수 있어서임...
/// @details    iOS 9.x 이하 번전, iOS 10.x 이상 버전의 통합을 위해 이러한 구조를 선택했었음.. 완전한건아니고 iOS 9.x 이하 버전을 넣으면서 수정을 해야함.
/// @details    Manager 의 제어 부분을 제외한 다른 부분들은 다 겹치기 때문에 이렇게 했으며, 이때 당시엔 리소스 모니터앱을 WebDriverAgent 로 실행시킬 생각이 없었기 때문에
/// @details    리소스 앱을 Agent 와는 독립적으로 만들었었음...
/// @details    통합 문제는 중요도가 떨어지기에 판단은 후임지가 알아서 하시길...
- (void) initialize {
    DDLogInfo(@"%s -- START", __FUNCTION__);
    if( nil== _dicAgentInfos ) {
        DDLogError(@"Agent 정보가 없음!!");
        return ;
    }
    
    NSString * agentMode = [_dicAgentInfos objectForKey:AGENT_MODE_KEY];
    
    if( NSOrderedAscending == [@"9.3" compare:self.deviceInfos.productVersion options:NSNumericSearch] ) {
        if( [AGENT_MODE_WEBDRIVER isEqualToString:agentMode] ) {
            DDLogInfo(@"HomeScreen Mode");
            WebDriverControlAgent * webAgent = [[WebDriverControlAgent alloc] init];
            webAgent.xctestRun = [_dicAgentInfos objectForKey:XCTEST_RUN_KEY];
            
            _myAgent = webAgent;
        } else if ( [AGENT_MODE_APPIUM isEqualToString:agentMode] ) {
            DDLogInfo(@"Appium Mode");
            
            // Appium은 App 을 설치한뒤 앱을 실행하여 시작이 완료되기 때문에 지금과는(홈스크린 부터 시작) 진입부분이 다르다.
            // WebDriverAgent/Appium 모두 정상동작하는걸 확인했으며, 현재는 Appium 을 사용하기 위해선 진입부분에 대한 수정이 필요하다..
            // 진입부분에 대안 동작 절차의 차이점은 김선아 선임에게 문의 하면 됩니다.
            AppiumControlAgent * appAgent = [[AppiumControlAgent alloc] init];
            appAgent.xctestRun = [_dicAgentInfos objectForKey:XCTEST_RUN_KEY];
            
            _myAgent = appAgent;
        }
        _myResource = [ResourceMornitor highVersionResourceMornitor];
    } else {
        if ([AGENT_MODE_INSTRUMENTS isEqualToString:agentMode] ) {
            DDLogInfo(@"Instruments Mode");
            _myAgent = [[InstrumentsControlAgent alloc] init];
        }
        _myResource = [ResourceMornitor lowVersionResourceMornitor];
    }
    
    if( !_myAgent ) {
        DDLogError(@"Not Matching AgentMode : %@", agentMode);
    }
    
    _myAgent.customDelegate = self;
    _myAgent.deviceInfos = _deviceInfos;
    _myResource.deviceInfos = _deviceInfos;
    
    NSString * captureMode = [_dicAgentInfos objectForKey:SCAPTURE_MODE_KEY];
    if( [captureMode isEqualToString:SCAPTURE_MODE_POLLING] ) {
        _myComuVps = [[CommunicatorWithVPS alloc] initWithCaptureMode:[_dicAgentInfos objectForKey:SCAPTURE_MODE_KEY] withDeviceInfos:_deviceInfos withControlAgent:_myAgent];
        [_myComuVps startVPSSocketServer];
    }
    
    DDLogInfo(@"%s -- END", __FUNCTION__);
}


/// @brief  남아있는 타스크를 찾아서 강종시킴.
- (void) clearProcess {
    DDLogWarn(@"%s, %d", __FUNCTION__, _deviceInfos.deviceNo);
//    dispatch_async([[CommunicatorWithDC sharedDCInterface] getDispatchQueue:_deviceInfos.deviceNo], ^(){
        [self checkAndClearProcess:_deviceInfos.udid];      // appium, idevice, instrument 의 프로세스가 남았는지 확인해서 있으면, 정리한다.
//    });
}

/// @brief  타스크를 종료했는데.. 남았는경우가 가끔씩 있어 확인사살함. [NSTask terminate] 의 정의를 보면 다음과 같이 되어있음.  "Not always possible. Sends SIGTERM."
- (void) checkAndClearProcess:(NSString *)name {
    
    NSString * output = [Utility launchTaskFromBash:[NSString stringWithFormat:@"ps -ef | grep %@", _deviceInfos.udid]];
    
    output = [output stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    NSArray* arrOut = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    //    int nCount = arrOut.count;
    NSMutableArray * arrPid = [NSMutableArray array];
    for( NSString * outputProcessInfos in arrOut ) {
        if( 0 == outputProcessInfos.length )
            continue;
        
        if( [outputProcessInfos containsString:@"grep "] ) {
            continue;
        }
        
        NSArray * component = [outputProcessInfos componentsSeparatedByString:@" "];
        [arrPid addObject:[component objectAtIndex:3]];
    }
    
    if( arrPid.count ) {
        NSString * strPids = [arrPid componentsJoinedByString:@" "];
        NSString * command = [NSString stringWithFormat:@"kill -9 %@", strPids];
        int result = system([command cStringUsingEncoding:NSUTF8StringEncoding]);
        DDLogWarn(@"Kill Process Result : %d", result);
    }
}

- (void) initUSBConnect {
    _cmtIProxy = [[CommunicatorWithIProxy alloc] init];
    if( _deviceInfos ) {
        _cmtIProxy.deviceNo = _deviceInfos.deviceNo;
        _cmtIProxy.udid = _deviceInfos.udid;
    }
    _cmtIProxy.customDelegate = self;
}

- (void) initDeviceLog {
    if(_myDeviceLog == nil)
        _myDeviceLog = [[DeviceLog alloc] initWithDeviceNo:self.deviceInfos.deviceNo UDID:self.deviceInfos.udid withDelegate:self];
}

/// @brief      메니져 경로획득
- (NSString *)managerDirectoryForDevice {
    
    NSString * managerPath = [Utility managerDirectory];
    NSFileManager* fileMgr = [NSFileManager defaultManager];
    NSString * theManagerDirectory = [managerPath stringByAppendingPathComponent:self.deviceInfos.udid];
    
    BOOL isDirectory;
    BOOL isExist = [fileMgr fileExistsAtPath:theManagerDirectory isDirectory:&isDirectory];
    if (! isExist || !isDirectory) {
        [fileMgr createDirectoryAtPath:theManagerDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return theManagerDirectory;
}

- (void)removeDeviceDirectoryFile {
    NSString* dirPath = [self managerDirectoryForDevice];
    NSFileManager* fileMgr = [NSFileManager defaultManager];
    [fileMgr removeItemAtPath:dirPath error:nil];
}

/// @brief      사용하지 않음.
- (void)openSafari
{
    [_myResource launchResourceMornitor];
}

-(void)SafariOpen:(NSString* )url{
    [self.myAgent openURL:url];
}



/// @brief      DC 에서 OpenURL 명령을 받았을때 호출되며, 리소스앱을 실행한뒤 완전히 실행될때 까지 대기하다가 전달받은 URL 을 리소스 앱으로 전달하여 이동하게 한다.
/// @detail     launchedAppInfos 메소드에서 리소스 앱이 실행됐는지 확인한뒤 URL 을 넘겨준다.
- (void)launchResource
{
    DDLogDebug(@"%s",__FUNCTION__);
    DDLogVerbose(@"version = %d",[_deviceInfos.productVersion intValue]);
    
    if([_deviceInfos.productVersion intValue] > 9){
        __block __typeof__(self) blockSelf = self;
        //KB 는 ResourceMonitor4
//        NSString * commandString = [NSString stringWithFormat:@"idevicedebug run %@", @"com.onycom.ResourceMornitor4"];
        NSString * commandString = [NSString stringWithFormat:@"idevicedebug -u %@ run com.onycom.ResourceMornitor2", self.deviceInfos.udid];//mg//add udid to kill process
        
        NSTask * launchTask = [[NSTask alloc] init];
        launchTask.launchPath = @"/bin/bash";
        launchTask.arguments = @[@"-l", @"-c", commandString];
        
        NSPipe * outputPipe = [[NSPipe alloc] init];
        [launchTask setStandardOutput:outputPipe];
        NSFileHandle * outputHandle = [outputPipe fileHandleForReading];
        
        //mg//s
        if( [NSThread isMainThread] ) {
            [launchTask launch];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [launchTask launch];
            });
        }
        //mg//e

        //예외 일괄 처리
        //mg//[launchTask launch];
    }else{
//        [_myResource launchResourceMornitor];
    }
    // 1초 단위로 10초동안 Safari 가 실행되었는지 확인하여 대기하다가 Safari 실행되었으면 전달한 URL로 이동하게 한다.
    //    [self waitforLaunchedSafariWithURL:url withCount:10];
    
}


/// @brief      DC 에서 OpenURL 명령을 받았을때 호출되며, 리소스앱을 실행한뒤 완전히 실행될때 까지 대기하다가 전달받은 URL 을 리소스 앱으로 전달하여 이동하게 한다.
/// @detail     launchedAppInfos 메소드에서 리소스 앱이 실행됐는지 확인한뒤 URL 을 넘겨준다.
- (void)sendOpenURL:(NSString *)url
{
    DDLogWarn(@"%s, %d",__FUNCTION__, _deviceInfos.deviceNo);
    DDLogWarn(@"%d",[_deviceInfos.productVersion intValue]);
    _openURL = url;
    if([_deviceInfos.productVersion intValue] > 9){
        __block __typeof__(self) blockSelf = self;
        NSString * commandString = [NSString stringWithFormat:@"idevicedebug run %@", @"com.apple.test.OnyAgent-Runner"];
        
        NSTask * launchTask = [[NSTask alloc] init];
        launchTask.launchPath = @"/bin/bash";
        launchTask.arguments = @[@"-l", @"-c", commandString];
        
        NSPipe * outputPipe = [[NSPipe alloc] init];
        [launchTask setStandardOutput:outputPipe];
        NSFileHandle * outputHandle = [outputPipe fileHandleForReading];
        
        //mg//s
        if( [NSThread isMainThread] ) {
            [launchTask launch];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [launchTask launch];
            });
        }
        //mg//e

        //mg//[launchTask launch];
        
        NSLog(@"url = %@",url);
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self SafariOpen:url];
        });
       
    }else{
        [_myResource launchResourceMornitor];
    }
    // 1초 단위로 10초동안 Safari 가 실행되었는지 확인하여 대기하다가 Safari 실행되었으면 전달한 URL로 이동하게 한다.
//    [self waitforLaunchedSafariWithURL:url withCount:10];
   
}


/// @brief      사용하지 않음..  1초단위로 count 값만큼 사라피가 실행되었는지 확인하고, 실행되었으면 DC 로 전달받은 URL 로 이동하게 한다.
/// @todo       이 역시 리소스 앱 구동방식을 변경해야 하는부분...
- (void) waitforLaunchedSafariWithURL:(NSString *)url withCount:(int)count {
    DDLogWarn(@"%s, %d",__FUNCTION__, _deviceInfos.deviceNo);
    
    if( --count < 0 )
        return ;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        NSString * launchStatus = [self.dicBundleIDs objectForKey:@"com.apple.mobilesafari"];
        NSString * launchStatus = [self.dicBundleIDs objectForKey:@"com.onycom.ResourceMornitor2"];
        if( launchStatus && [launchStatus boolValue] ) {
            [_cmtIProxy sendCommand:url autoConnect:true];
        } else {
            [self waitforLaunchedSafariWithURL:url withCount:count];
        }
    });
}

/// @brief      appbuilder 타스크가 종료될때 호출된다.  appbuilder 는 commandLine Tool 이며, Mac 터미널에서 USB 로 연결된 iPhone 의 특정 앱을 실행시킬 수 있다.
/// @brief      근데.. 실행되기 까지가 약간의 시간이 필요한다.
-(void)taskTerminated:(NSNotification *) aNotification
{
    DDLogError(@"%s, %d",__FUNCTION__, _deviceInfos.deviceNo);
}

/// @brief      리소스 모니터 앱에 명령을 전달한다.
//mg//- (void) sendResourceMornitorCommand:(NSString *)cmd {
- (void) sendResourceMornitorCommand:(NSString *)cmd autoConnect:(BOOL)connect {//mg//
    if( !_cmtIProxy )
        return ;
    
    //mg//[_cmtIProxy sendCommand:cmd];
    [_cmtIProxy sendCommand:cmd autoConnect:connect];//mg//
}

/// @brief      사용안함.. 이전담당자가 사용했을 듯..
- (void) removeTempFilesOfPath:(NSString *)path {
    NSError * error = nil;
    NSString * strURL = [NSString stringWithFormat:@"file:///private%@", path];
    NSURL * url = [NSURL URLWithString:strURL];
    [[NSFileManager defaultManager] removeItemAtURL:url error:&error];
    if( error ) {
        DDLogError(@"remove fiale  Failed!! -- error : %@", error.description);
    }
}

/// @brief      standalone 기능 지금은 사용하지 않으며, 예전에 peartalk 을 사용하여 USB 터널링을 했을때, Mac 에 USB 로 iPhone 이 연결하는지, 떨어지는지 등의 이벤트를 감지하는 기능과 관련이 있다.
- (void) startDetachTimer {
    _detachTimer = [NSTimer scheduledTimerWithTimeInterval:1*30 target:self selector:@selector(onDetachTimer:) userInfo:nil repeats:NO];
}

/// @brief      standalone 기능 지금은 사용하지 않으며, 예전에 peartalk 을 사용하여 USB 터널링을 했을때, Mac 에 USB 로 iPhone 이 연결하는지, 떨어지는지 등의 이벤트를 감지하는 기능과 관련이 있다.
- (void) stopDetachTimer {
    if( _detachTimer && _detachTimer.isValid ) {
        [_detachTimer invalidate];
    }
}

#pragma mark - <DeviceLogDelegate>
/// @brief      상당히 중요한 함수!! iOS 11.x 홈스크린(springboard) 제어 기능의 핵심!!
/// @details    iOS 11.x 버전은 XCode9.x 버전으로 실행해야 하는데.. WebDriverAgent 에서 Touch 로 실행한 앱은 제어가 안됨.
/// @details    다행인점은 bundleid 로 앱을 실행시키면 제어가 가능함.
/// @details    DeviceLog.m 에서 로그 정보를 읽어들여 앱이 실행된 시점에서 BundlID 정보를 획득하여 호촐뒴.
- (void) launchedAppInfos:(NSArray *)arrInfos {

    __block __typeof__(self) blockSelf = self;
    dispatch_async(self.launchedAppQueue, ^{
        NSString * bundleID = arrInfos[0];              // [com.onycom.uicatalog]
        bundleID = [bundleID substringWithRange:NSMakeRange(1, bundleID.length - 2)];
        
        /// @code   관리자 페이지에서 설정한 설정앱 차단값에 의해 설정앱을 차단하는 부분... 설정앱이 실행되면 HomeScreen 으로 이동한다.
        if( 1 == blockSelf.myAgent.nLockSetting ) {
            if( NSOrderedSame == [@"com.apple.Preferences" compare:bundleID] ) {
                [blockSelf.myAgent homescreen];
            }
        }
        /// @endcode
        
        /// @code   현재 실행된 App 의 번들아이디 중에 재실행하지 않아야 하는 App 을 걸러낸다. com.apple.AdSheetPhone 의 경우 특정기능을 사용할때 iOS 내부에서 실행되며 원래는 사용자는 보지 못하는 앱인데..                     WebDriverAgent 가 com.apple.AdSheetPhone 번들 아이디로 실행하게 되면.. 검은색 UI 를 가진 View 가 Foreground 오 올라오면서 화면을 가리게 된다. com.apple.AdSheetPhone 앱 말고도 이러한 앱들이 더 있을걸로 추정되며.. 그럴때 마다 막아줘야 한다.
        if( NSOrderedSame == [@"com.onycom.ResourceMornitor2" compare:bundleID] ) {
            // 리소스 앱은 계속 실행된 상태여야 함..
            // @todo 리소스 앱을 실행하는 과정을 변경해야 한다.
            if( _cmtIProxy ) {
                [_cmtIProxy sendCommand:_openURL autoConnect:true];
                _openURL = nil;
            }
            return ;
        } else if( NSOrderedSame == [@"com.apple.test.WebDriverAgentRunner-Runner" compare:bundleID] )
            return;
        //add agent name
        //mg//s
        else if( NSOrderedSame == [@"com.apple.test.OnyAgent-Runner" compare:bundleID] )
            return ;
        else if( NSOrderedSame == [@"com.apple.test.Don't Touch Me-Runner" compare:bundleID] )
            return ;
        //mg//e
        else if ( NSOrderedSame == [@"com.apple.AdSheetPhone" compare:bundleID] ) {
            return;
        }
        /// @endcode
        
        DDLogInfo(@"%s, %d, Infos : %@",__FUNCTION__, _deviceInfos.deviceNo, arrInfos);
        
        //swccc 검색 설정 변경으로 인하여 불필요 해당 부분 주석처리
        /// @code   아래의 dicBundleIDs Dictionary 구조이며, bundleid 를 키워드로 검색하여 해당 번들아이디가 있는지 확인 할 수 있다.  이 변수가 필요한 이유는 Client 동작중에 BundleID 로 실행하는 경우가 있는데 BundlID 로 실행한 App 의 경우 제어가 잘되기 때문에 굳이 재실행해 줄 필요가 없어서.. 막아주는 역활을 한다.
//        NSString * exist = [blockSelf.dicBundleIDs objectForKey:bundleID];
//        if( nil == exist || NO == exist.boolValue  ) {           // Tap 으로 실행한 앱을 BundleID 로 재실행 한다. iOS11 대응
//            
//            DDLogInfo(@"앱 실행!! -- %@", bundleID );
//            
//            if( [blockSelf.myAgent respondsToSelector:@selector(launchAppWithBundleID:)] ) {
//                [self.dicBundleIDs setObject:@YES forKey:bundleID];
//                if( NO == [blockSelf.myAgent launchAppWithBundleID:bundleID] ) {
//                    DDLogError(@"결과 없음.!! 또는 타임아웃!!");
//                    [self.dicBundleIDs removeObjectForKey:bundleID];
//                    
//                    // 실패를 하면 DeviceDisconnect 를 DC 로 전달하여 모두 종료하는 과정을 거친다. (Web Client, DC, Manager)
//                    dispatch_async(dispatch_get_main_queue(), ^{
//                        [[CommunicatorWithDC sharedDCInterface] responseDeviceDisconnected:self.deviceInfos.deviceNo];
//                    });
//                }
//            }
//        } else {
//            DDLogInfo(@"앱이 실행되어있음");
//        }
        /// @endcode
    });
}

#pragma mark - <DeviceInfosDelegate>
/// @brief      디바이스 정보를 DC 에 올려줌..  Standalone 기능임.. 현재 사용하지 않음.
- (void) didCompletedGetDeviceInfos {
    if( self.customDelegate && [self.customDelegate respondsToSelector:@selector(didCompletedGetDeviceInfos:)] ) {
        [self.customDelegate didCompletedGetDeviceInfos:_deviceInfos.udid];
    }
}

#pragma mark - <CommunicatorWithIProxy Delegate>
/// @brief      리소스 모니터 앱과 소켓 연결이 성공했을 때 호출되는 Delegate 메소드.
/// @details    iproxy 를 통해 연결을 하는데 iproxy 는 usb 터널링을 하여 Manager  와 리소스 앱과의 통로 역활을 함.
/// @details    리소스 모니터 앱은 서버로 동작을 하며, Connect 과 이뤄지면, 리소스 앱에서 Manager 로 DeviceNo 를 담은 패킷을 보내준다.
/// @details    이 패킷을 받으면 메니져와 리소스앱이 연결이 성공된걸로 판당하여 아래의 메소드가 호출된다.
/// @details    Install 명령중 사파리 실행이 있는데 이 메소드가 호출된 상태에서 사파리 실행 정보가 있으면 사파리를 실행시킨다.
- (void) didConnectedToResourceApp {
    if( [self.myAgent.launchBundleId isEqualToString:@"com.onycom.ResourceMornitor2"] ) {
        NSString* safari = [NSString stringWithFormat:@"%@|%@",CMD_SAFARI, _openURL];
        [_cmtIProxy sendCommand:safari autoConnect:true];
        _openURL = nil;
    }
    
    self.bConnectedResourceApp = YES;
}

- (void) didDisconnectedFromResourceApp {
    self.bConnectedResourceApp = NO;
}

#pragma mark - <ControlAgent Delegate>
//mg//
/// @brief  Agent 의 실행이 성공함. (Appium, WebDriverAgent, Instruments) DC 로 Start 에 대한 성공을 응답한다.
- (void) agentCtrlLaunchSuccessed {
    DDLogDebug(@"%s", __FUNCTION__);
    
    _deviceInitAppList = [((NSArray *)[self getAppListForDevice:NO]) copy];
    
    //resource app 화면 표시됨//

    [_cmtIProxy startIProxyTask];       // ResourceMornitor App 과 통신을 하기 위한 iProxy 를 실행한다.
    
    //(Log를 시작할 때마다 로그를 출력하면 로그가 중복되어, 디바이스 연결시에 로그 출력을 시작하고 로그 출력 커맨드가 왔을 때 로그를 D.C로 전송)
    [self initDeviceLog];      // App 이 실행된 정보(BundleID)를 획득해야 하기 때문에 자동화/메뉴얼 구분없이 실행되어야 함.
    [self.myDeviceLog startLogAtFirst];
 
    [[CommunicatorWithDC sharedDCInterface] sendResponse:YES message:self.deviceInfos.productVersion deviceNo:self.deviceInfos.deviceNo];
    
    // 아래의 2개중 한개만 있으면 됨..
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3f * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
        [_cmtIProxy connectResourceMornitor];
    });
    
    //홈화면부터 시작하기 위하여 190218 swccc
    if([self.deviceInfos.productVersion intValue] > 11.5){
        NSLog(@"######## VERSION 12 = %@ ##############",self.deviceInfos.productVersion);
        [self.myAgent homescreen];
    }else{
        NSLog(@"######## VERSION 12 UNDER = %@ ##############",self.deviceInfos.productVersion);
    }
        
    
    //display
    NSString* ratio = [NSString stringWithFormat:@"%.1f", self.deviceInfos.ratio];
    NSDictionary* dict = [[NSDictionary alloc] initWithObjectsAndKeys:self.deviceInfos.udid,@"UDID"
                          ,self.deviceInfos.deviceName, @"NAME"
                          ,self.deviceInfos.productVersion,@"VERSION"
                          ,ratio, @"RATIO"
                          , nil];
    
    //deviceLog정보를 UI로 보여줌
    dispatch_async(dispatch_get_main_queue(), ^{
        // code here
        [[NSNotificationCenter defaultCenter] postNotificationName:DEVICE_CONNECT object:self userInfo:dict];
    });
}//agentCtrlLaunchSuccessed

//mg//
/*- (void) agentCtrlLaunchSuccessed {
    DDLogDebug(@"%s", __FUNCTION__);
    
    //response
    [[CommunicatorWithDC sharedDCInterface] commonResponse:YES deviceNo:self.deviceInfos.deviceNo];
    
    //(Log를 시작할 때마다 로그를 출력하면 로그가 중복되어, 디바이스 연결시에 로그 출력을 시작하고 로그 출력 커맨드가 왔을 때 로그를 D.C로 전송)
    
    [_cmtIProxy startIProxyTask];       // ResourceMornitor App 과 통신을 하기 위한 iProxy 를 실행한다.
    //    [self.myDeviceLog startLogAtFirst];
    
    if( [NSThread isMainThread] ) {
     [self.myDeviceLog startLogAtFirst];
     } else {
     dispatch_async(dispatch_get_main_queue(), ^{
     [self.myDeviceLog startLogAtFirst];
     });
     }
    
    [[CommunicatorWithDC sharedDCInterface] commonResponse:YES deviceNo:self.deviceInfos.deviceNo];
    
    {
        // 아래의 2개중 한개만 있으면 됨..
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [_cmtIProxy connectResourceMornitor];
        });
    }
}//agentCtrlLaunchSuccessed
 */

/// @brief  Agent 의 실행이 실패함. (Appium, WebDriverAgent, Instruments)
- (void) agentCtrlLaunchFailed {
    DDLogInfo(@"%s", __FUNCTION__);
    [[CommunicatorWithDC sharedDCInterface] commonResponse:NO deviceNo:self.deviceInfos.deviceNo];
    
    [self stopAgent];
}

/// @brief  앱 실행이 완료됨.
- (void) applicationLaunchSuccessed {
    
    NSString * responseName = nil;
//    사파리 시작일 경우, 리소스 모니터 앱을 실행하게 되는데.. 리소스 앱이 실행되면 URL정보로 사파리를 이동시켜야 한다.
    if([self.myAgent.launchBundleId isEqualToString:@"com.onycom.ResourceMornitor2"]) {
        
        if( self.bConnectedResourceApp ) {
            NSString* safari = [NSString stringWithFormat:@"%@|%@",CMD_SAFARI, _openURL];
            [_cmtIProxy sendCommand:safari autoConnect:true];
            _openURL = nil;
        } else {
            // Appium 으로 실행할 경우 WebDriverAgent 를 실행하기 전에 Appium 에서 모든 iproxy를 종료시킨뒤 8100 port 를 사용하는
            // iproxy 를 생성하기 때문에 ResourceMornitor App 과 연결되는 iproxy 도 종료되기에 새로 연결해준다.
            [_cmtIProxy startIProxyTask];
            // iProxy 타스크를 실행한 뒤 약간의 시간뒤에 소켓연결을 시도함.. 0.3초는 별 의미 없음.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [_cmtIProxy connectResourceMornitor];
            });
        }
        
        //Safari 의 번들 아이디
        NSString* launchId = @"Safari";
        responseName = [NSString stringWithFormat:@"Safari\n%@", launchId];
    }else{
        //swccc HomeScreen이 아닌 값이 넘어가도록
        if(_deviceInitAppList == nil){
            DDLogWarn(@"_deviceInitAppList null");
        }else{
            DDLogWarn(@"%@",  _deviceInitAppList);
            
            for(int i = 0; i<_deviceInitAppList.count; i++){
                NSString* temp = [_deviceInitAppList objectAtIndex:i];
                NSString* temp2 = [[temp componentsSeparatedByString:@"|"] objectAtIndex:0];
                
                if([temp2 isEqualToString:self.myAgent.launchBundleId]){
                    self.myAgent.launchAppName = [[temp componentsSeparatedByString:@"|"] objectAtIndex:1];
                }
            }
        }

        //추후 선아 수정 요청 가능성 1%있음
        responseName = [NSString stringWithFormat:@"%@\n%@", self.myAgent.launchAppName, self.myAgent.launchBundleId];
    }
    
    // 중요 !! Manual 모드일경우, RunApp 에 의해 설치된 App 이 실행되지만, Auto 모드일경우 설치된 앱을 바로 실행한다.
    if( CNNT_TYPE_MAN == _connectType ) {
        [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:YES appId:responseName deviceNo:_deviceInfos.deviceNo];
    } else {
        // TO DO :
        // 실행중 한번 설치했던 파일은 두번째 설치가 안됨... 아래의 코드때문에....
        // 해당 버그는 다음 기회에....
        
        
        //설치 중에 연결 종료 처리가 중복되면서, launchBundleId가 nil 로 변경되는 사례 발생
        if (_myAgent.launchBundleId != nil) {//mg//
            if( ![[self.dicBundleIDs objectForKey:_myAgent.launchBundleId] boolValue] ) {
                [self.dicBundleIDs setObject:@YES forKey:_myAgent.launchBundleId];//crash : key=nil
                _myAgent.nRetryCount = 0;
                //swcccc 홈자동화시작이 되면서 설치후 바로 시작 되는 기능 주석 처리 190515
                [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:YES appId:responseName deviceNo:_deviceInfos.deviceNo];
//                [_myAgent launchAppWithBundleID];
//                return;
                //swccc 190515
            }
            else{
                [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:YES appId:responseName deviceNo:_deviceInfos.deviceNo];
            }
        }
    }//else : auto
}//applicationLaunchSuccessed

/// @brief  앱 실행 실패
- (void) applicationLaunchFailed:(NSString *)description {
    DDLogDebug(@"%s", __FUNCTION__);
    
    //mg//NSString* temp = [NSString stringWithFormat:@"앱 설치오류 = %@",description];
    //mg//[[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:NO appId:temp deviceNo:_deviceInfos.deviceNo];
    
    [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:NO appId:description deviceNo:_deviceInfos.deviceNo];//mg//
    // 1초 뒤 DeviceDisconnected 를 보낸다.
}

/// @brief  Install 명령에 Safari 실행이 들어와 WebDriverAgent 를 실행한뒤 바로 ResourceMornitor 앱을 실행시킨경우, WebDriverAgent 가 종료되면서 ResourceMornitor App 이 종료됨.
/// @brief  ResourceMornitor App 은 항상 실행되어있어야 하므로 재실행 한다.
/// @bug    Appium을 사용하던 시절 만들어진 코드이며, WebDriverAgent 를 직접 사용하게되면서 그대로 사용함.
/// @todo   WebDriverAgent 가 실행완료되면, 리소스 앱을 번들아이디로 실행시킨뒤 Start 에 대한 Response 를 DC 에 전달하는 과정으로 수정되어야 함.
- (void) reLaunchResourceMornitor {
    [_myResource launchResourceMornitor];
}

// add by leehh
#pragma mark - <Notification>
/// @brief  메니져가 종료될때 Notification 을 발생시켜서 호출된 메소드.. 종료과정을 거친다.
- (void) applicationWillTerminate:(NSNotification *)notification {
    DDLogWarn(@"%s, %d", __FUNCTION__, _deviceInfos.deviceNo);
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    int nPortNum = _deviceInfos.deviceNo + RESOURCE_PORT;
//    [self clearIProxy:nPortNum];
    [_cmtIProxy stopIProxyTask];
    self.bConnectedResourceApp = NO;
    [self stopAgent];
}


#pragma mark - <Timer>
/// @brief  Standalone 기능이라 현재는 중요하지 않으며... 해당 기능을 활성화 할때 많은 수정이 필요하다. 지금은 사용하지 않는 peartalk 와 관련이 있다.
- (void) onDetachTimer:(NSTimer *)theTimer {
    if( self.customDelegate && [self.customDelegate respondsToSelector:@selector(didCompletedDetachDevice:)] ) {
        [self.customDelegate didCompletedDetachDevice:_deviceInfos.usbNumber];
    }
}


#pragma mark -
#pragma mark Touch Event
/// @brief  touch 동작
- (void)doTouchStartAtX:(int)argX andY:(int)argY{
    [_myAgent doTouchStartAtX:argX andY:argY];
}

/// @brief  Drag 중...
- (void)doTouchMoveAtX:(int)argX andY:(int)argY {
    [_myAgent doTouchMoveAtX:argX andY:argY];
}

/// @brief  Drag 끝
- (void)doTouchEndAtX:(int)argX andY:(int)argY{
//    _connectType = CNNT_TYPE_AUTO;
    BOOL bAuto = NO;
    if(_connectType == CNNT_TYPE_AUTO){
        bAuto = YES;
    }
    
    [_myAgent doTouchEndAtX:argX andY:argY andAuto:bAuto];
}

/// @brief  MultiTouch 시작 (줌인/줌아웃 을 할 때 사용함.)
- (void) doMultiTouchStartAtPoint1:(NSPoint)point1 andPoint2:(NSPoint)point2 {
    [_myAgent doMultiTouchStartAtPoint1:point1 andPoint2:point2];
}

/// @brief  Multi Touch Drag 중
- (void) doMultiTouchMoveAtPoint1:(NSPoint)point1 andPoint2:(NSPoint)point2 {
    [_myAgent doMultiTouchMoveAtPoint1:point1 andPoint2:point2];
}

/// @brief  Multi Touch 끝
- (void) doMultiTouchEndAtPoint1:(NSPoint)point1 andPoint2:(NSPoint)point2 {
    [_myAgent doMultiTouchEndAtPoint1:point1 andPoint2:point2];
}

/// @brief  Tap
- (void)doTapAtX:(float)argX andY:(float)argY{
    [_myAgent doTapAtX:argX andY:argY];
//    for(int i = 0; i<10; i++){
//        dispatch_sync(dispatch_get_main_queue(), ^(void){
//            [_myAgent doTapAtX2:argX andY:argY];
//        });
//    }
}

/// @brief  Swipe... 자동화 기능이며, 구현은 했지만, 확인은 안해봄.. 위의 Drag & Drop 과 같은 처리가 되어있어서 동작할거라 판단됨.  후임자는 확인해보시길..
- (void)doSwipeAtX1:(int)argX1 andY1:(int)argY1 andX2:(int)argX2 andY2:(int)argY2 {
    [_myAgent doSwipeAtX1:argX1 andY1:argY1 andX2:argX2 andY2:argY2];
}

#pragma mark -
#pragma mark Start/Stop Log

/// @brief  로그 검색 시작   문제점은 DeviceLog.m 파일에 기술해놨음.
- (void)startLogSearch:(NSString *)search identifier:(NSString* )identifier level: (char)level{
    if(self.myDeviceLog == nil)
        self.myDeviceLog = [[DeviceLog alloc] initWithDeviceNo:_deviceInfos.deviceNo UDID:_deviceInfos.udid withDelegate:self];
    
    NSString * searchName = nil, * searchBundleID = nil;
    
    if([identifier isEqualToString:@"*"]) {
        searchName = @"*";
        searchBundleID = @"*";
    } else {
        searchName = _myAgent.launchAppName;
        searchBundleID = _myAgent.launchBundleId;
    }
    
    [self.myDeviceLog startLog:search identifier:identifier level:level bundleID:searchBundleID appName:searchName];
}

/// @brief  로그 전송 중지.
- (void)stopLog{
    if(self.myDeviceLog == nil) return;
    [self.myDeviceLog stopLog];
}


#pragma mark -
#pragma mark Automation Event

/// @brief  물리버튼 이벤트 (Volume Up/Down, 화면잠금)
/// @bug    Onycap 이 idevice 의 자원을 점유하면서 볼륨 컨트롤이 안됨. QuickTimePlayer 의 미러링 기능을 확인해보면 알수 있음.
/// @bug    화면잠금 기능이 없음.
/// @todo   AVCaptureSession 이 아닌 다른 방법으로 미러링 하는 방식을 찾아봐야 함.
/// @todo   현재 찾아본 방법은 Airplay 앱을 만들어 idevice 의 Airplay를 연결해 미러링 영상을 가져와 iproxy 로 USB 터널링을 한뒤 소켓통신을 하는거임..
/// @todo   https://brunch.co.kr/@aw2sum/40 에 나와있는 앱의 동작 방식이며, 개발자가 년간 $60,00 라이센스 비용을 요구함.
- (void)hardKeyEvent:(int)nKey longpress:(int)nType {
    [_myAgent hardKeyEvent:nKey longpress:nType];
}

/// @brief  idevice 의 화면정보를 XML 로 추출하여 DC 로 전송함.
- (void)uploadDumpFile:(NSString*)url
{
    if(!_myAgent.bLaunchDone) {
        [[CommunicatorWithDC sharedDCInterface] commonResponse:NO reqCmd:CMD_REQ_DUMP msg:@"" deviceNo:self.deviceInfos.deviceNo];
        return;
    }
    
    DDLogVerbose(@"upload url = %@", url);
    
    NSString* saveDump = [self saveToSourceFile];
    if( nil == saveDump ) {
        [[CommunicatorWithDC sharedDCInterface] commonResponse:NO reqCmd:CMD_REQ_DUMP msg:@"" deviceNo:_deviceInfos.deviceNo];
    }
    
    if (![saveDump isEqualToString:@""]) {
        NSString* fileName;
        if(self.sessionID.length > 0){
            fileName = [NSString stringWithFormat:@"%@.scene.xml", self.sessionID];
        }else{
            //예전엔 홈화면으로 보내왔던 것을
//            fileName = [NSString stringWithFormat:@"%@.scene.xml", [self getAppName]];
            fileName = @"HomeScreen.scene.xml";
        }
        
        NSString* path = [NSString stringWithFormat:@"%@/%@", [self managerDirectoryForDevice], fileName];
        NSData* dump = [NSData dataWithContentsOfFile:path];
        
//        NSMutableURLRequest* request= [[NSMutableURLRequest alloc] init];
//        [request setURL:[NSURL URLWithString:url]];
        
        NSMutableURLRequest * request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30.0f];
//        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0f];
        [request setHTTPMethod:@"POST"];
        NSString *boundary = @"---------------------------14737809831466499882746641449";
        NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
        [request addValue:contentType forHTTPHeaderField: @"Content-Type"];
        NSMutableData *postbody = [NSMutableData data];
        [postbody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [postbody appendData:[[NSString stringWithFormat:@"Content-Disposition:form-data;name=\"file\";filename=\"%@\"\r\n", fileName] dataUsingEncoding:NSUTF8StringEncoding]];
        [postbody appendData:[@"Content-Type:application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [postbody appendData:[NSData dataWithData:dump]];
        [postbody appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [request setHTTPBody:postbody];
        
        [ASyncURLConnection asyncSendHttpURLConnection:request completion:^(NSURLResponse *response, NSData *returnData, NSError *error) {
            if( error ) {               // 실패
                DDLogError(@"dumpfile upload fail = %@",error.description);
                [[CommunicatorWithDC sharedDCInterface] commonResponse:NO reqCmd:CMD_REQ_DUMP msg:error.description deviceNo:_deviceInfos.deviceNo];
            } else {                    // 성공
                NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:returnData options:kNilOptions error:nil];
                DDLogWarn(@"jsonparsing %@", dict);
                NSString* res = [dict objectForKey:@"result"];
                if (res != nil && [res isEqualToString:@"true"]) {
                    DDLogWarn(@"dumpfile upload success");
                    NSString* resName = [dict objectForKey:@"filename"];
                    if(resName == nil){
                        resName = fileName;
                    }
                    [[CommunicatorWithDC sharedDCInterface] commonResponse:YES reqCmd:CMD_REQ_DUMP msg:resName deviceNo:_deviceInfos.deviceNo];
                } else {
                    DDLogError(@"dumpfile upload fail");
                    [[CommunicatorWithDC sharedDCInterface] commonResponse:NO reqCmd:CMD_REQ_DUMP msg:@"DC 리턴 값 false" deviceNo:_deviceInfos.deviceNo];
                }
            }
        }];
        
    } else {
        [[CommunicatorWithDC sharedDCInterface] commonResponse:NO reqCmd:CMD_REQ_DUMP msg:@"" deviceNo:_deviceInfos.deviceNo];
    }
}

/// @brief  자동화 기능. TextInput
- (void)autoInputText:(NSData *)data{
    [_myAgent autoInputText:data];
}

/// @brief  자동화 기능. 객체검색
- (void)automationSearch:(NSData *)data andSelect:(BOOL)bSelect{
    [_myAgent automationSearch:data andSelect:bSelect];
}

/// @brief  자동화 기능. Orientation 설정.
- (void)autoOrientation:(BOOL)bLand {
    [_myAgent autoOrientation:bLand];
}

/// @brief  예전엔 자동화 기능이었는데.. 이제는 메뉴얼에도 사용한다..  입력 받은 BundleID 로 앱을 실행한다.
- (void)autoRunApp:(NSString *)bundleId {
    if(!_myAgent.bLaunchDone ) {
        return;
    }
    
    if( nil == bundleId || 0 == bundleId.length ) {
        DDLogError(@"%s -- BundleID 없음.!!", __FUNCTION__);
        return ;
    }
    
    DDLogInfo(@"Runapp : %@", bundleId);
    
    [self.dicBundleIDs setObject:@YES forKey:bundleId];
    
    //delay좀 줘라..
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0f * NSEC_PER_SEC));
    dispatch_after(time, dispatch_get_main_queue(), ^{
    });
    
    BOOL result = [_myAgent autoRunApp:bundleId];
    if( !result ) {
        [self.dicBundleIDs removeObjectForKey:bundleId];
        [[CommunicatorWithDC sharedDCInterface] commonResponse:NO reqCmd:CMD_RESPONSE msg:@"" deviceNo:_deviceInfos.deviceNo];
    }else{
        [[CommunicatorWithDC sharedDCInterface] commonResponse:YES reqCmd:CMD_RESPONSE msg:@"" deviceNo:_deviceInfos.deviceNo];
    }
}

/// @brief  TextInput 기능
- (void)inputTextByString:(NSString *)string {
    [_myAgent inputTextByString:string];
}

/// @brief  RemoteKeyboard 기능   문제점은 ConnectionInfoItem에 기술해둠..
- (void)inputRemoteKeyboardByKey:(NSData *)key {
    [_myAgent inputRemoteKeyboardByKey:key];
}


#pragma mark -
#pragma mark File installation
/// @brief  ipa파일 Download 성공 결과를 알려주는 Notification이 발생하였을때 호출될 메소드를 지정함.
- (void)registerFileNotificationWithSuccess:(NSString *)sucName andFailed:(NSString *)failName {
    _NAME_DOWN_SUCCESS = sucName;
    _NAME_DOWN_FAIL = failName;
    
    NSNotificationCenter * notiCenter = [NSNotificationCenter defaultCenter];
    [notiCenter addObserver:self selector:@selector(suceessFileDownload:) name:_NAME_DOWN_SUCCESS object:nil];
    [notiCenter addObserver:self selector:@selector(failFileDownload) name:_NAME_DOWN_FAIL object:nil];
}

/// @brief  registerFileNotificationWithSuccess에서 지정한 메소드를 제거함.
- (void) unRegisterFileNotification {
    if( _NAME_DOWN_FAIL && _NAME_DOWN_SUCCESS ) {
        NSNotificationCenter * notiCenter = [NSNotificationCenter defaultCenter];
        [notiCenter removeObserver:self name:_NAME_DOWN_SUCCESS object:nil];
        [notiCenter removeObserver:self name:_NAME_DOWN_FAIL object:nil];
    }
}
/*
- (void)removeInstalledApp
{
    DDLogInfo(@"%s, %d -- bundleID : %@", __FUNCTION__, _deviceInfos.deviceNo, _myAgent.launchBundleId);
    if( !_myAgent.bLaunchBundleID ) {
        DDLogInfo(@"udid = %@",self.deviceInfos.udid);
        if( !_myAgent.launchBundleId )
            return ;
        
        if( 0 == _myAgent.launchBundleId.length )
            return ;
        
        if( [_myAgent.launchBundleId isEqualToString:@"com.onycom.ResourceMornitor2"] )
            return ;
        
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/bin/bash";
        NSString* commandString = [NSString stringWithFormat:@"ideviceinstaller -U %@ -u %@",_myAgent.launchBundleId, _deviceInfos.udid];
        task.arguments  = [NSArray arrayWithObjects:
                           @"-l", @"-c",
                           commandString,
                           nil];
        [task launch];
    }
    
    {
        DDLogInfo(@"udid = %@",self.deviceInfos.udid);
        if( !_myAgent.launchBundleId )
            return ;
        
        if( 0 == _myAgent.launchBundleId.length )
            return ;
        
        if( [_myAgent.launchBundleId isEqualToString:@"com.onycom.ResourceMornitor2"] )
            return ;
        
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/bin/bash";
        NSString* commandString = [NSString stringWithFormat:@"ideviceinstaller -U com.apple.test.WebDriverAgentRunner-Runner -u %@", _deviceInfos.udid];
        task.arguments  = [NSArray arrayWithObjects:
                           @"-l", @"-c",
                           commandString,
                           nil];
        [task launch];
    }
    
    _myAgent.launchBundleId = nil;
    _myAgent.bLaunchBundleID = NO;
}
*/

/// @brief  앱삭제
//- (void)removeInstalledApp
- (void)removeInstalledApp:(BOOL)CMDCLEAR
{
    DDLogDebug(@"%s", __FUNCTION__);
    // 시작했을때 가져온 AppList 에서 현재의 AppList 를 가져와 비교해서 새로 추가된 App 들을 삭제한다.
    NSMutableDictionary * dicAppList = (NSMutableDictionary *)[self getAppListForDevice:YES];
//    DDLogDebug(@"current=%d, start=%d", [[dicAppList allKeys] count],  [_deviceInitAppList count]);
    
    for( NSString *appInfo in _deviceInitAppList ) {
        DDLogVerbose(@"exclude = %@", appInfo);
        [dicAppList removeObjectForKey:appInfo];
    }
    
    NSArray * removeAppList = [dicAppList allKeys];
    DDLogInfo(@"remove apps = %@", removeAppList);
    
    for( NSString * removeAppInfo in removeAppList ) {
        NSString * appId = nil;
        NSString * appName = nil;
        NSArray * component = [removeAppInfo componentsSeparatedByString:@"|"];
        if( 2 == [component count] ) {
            appId = [component objectAtIndex:0];
            appName = [component objectAtIndex:1];      // 필요없지만 그냥 ..
            
            DDLogInfo(@"id = %@ and name = %@",appId, appName);
            
            if([appId isEqualToString:@"kr.co.metlife.mesia.ipad"] || [appId isEqualToString:@"com.metlife.korea.internal.appcenter"]
               || [appId isEqualToString:@"com.metlife.korea.internal.metdo"] || [appId isEqualToString:@"com.interplug.Innisfree"]
               || [appId isEqualToString:@"com.apple.test.OnyAgent-Runner"]//mg//
               || [appId isEqualToString:@"com.apple.test.Don't Touch Me-Runner"]//mg//
               || [appId isEqualToString:@"com.apple.test.WebDriverAgentRunner-Runner"]) {//mg//
                return;
            }
            
            NSRange aRange = [appId rangeOfString:@"com.apple"];
            if (aRange.location != NSNotFound)
            {
                return;
            }
            
//            NSString* commandString = [NSString stringWithFormat:@"ideviceinstaller -U %@ -u %@", appId, _deviceInfos.udid];
            NSString* commandString = [NSString stringWithFormat:@"ideviceinstaller -U %@", appId];
            NSString * output = [Utility launchTaskFromBash:commandString];
//            DDLogInfo(@"[#### Info ####] rmeove output : \n%@", output);
            if([output hasSuffix:@"Complete"]){
                [[CommunicatorWithDC sharedDCInterface] commonResponseClear:NO msg:@"Clear Successed" deviceNo:_deviceInfos.deviceNo];
            }
            DDLogVerbose(@"output = %@", output);
        }
    }
    // ~
    
    {   // WebDriverAgentRunner App 을 삭제 한다.
        DDLogInfo(@"udid = %@",self.deviceInfos.udid);
        if( !_myAgent.launchBundleId )
            return ;
        
        if( 0 == _myAgent.launchBundleId.length )
            return ;
        
        if( [_myAgent.launchBundleId isEqualToString:@"com.onycom.ResourceMornitor2"] )
            return ;
        
//        NSString* commandString = [NSString stringWithFormat:@"ideviceinstaller -U com.apple.test.WebDriverAgentRunner-Runner -u %@", _deviceInfos.udid];
//
//        NSString * output = [Utility launchTaskFromBash:commandString];
        
//        NSLog(@"[#### Info ####] rmeove output : \n%@", output);
        
//        NSString* commandString = [NSString stringWithFormat:@"ideviceinstaller -U com.apple.test.WebDriverAgentRunner-Runner -u %@", _deviceInfos.udid];
//        if( [NSThread isMainThread] ) {
//            system((char *)[commandString UTF8String]);
//        } else {
//            dispatch_sync(dispatch_get_main_queue(), ^{
//                system((char *)[commandString UTF8String]);
//            });
//        }
    }
    
    _myAgent.launchBundleId = nil;
    _myAgent.bLaunchBundleID = NO;
    
//mg//    _myAppList = nil;
    
    //초기 앱 정보 삭제
    if(CMDCLEAR == NO){
        _deviceInitAppList = nil;
    }
    
}

//mg//20180509//app 삭제
- (void)removeApp: (NSString *)appId {
    NSString* commandString = [NSString stringWithFormat:@"ideviceinstaller -U %@ -u %@",  _deviceInfos.udid,appId];
    NSString * output = [Utility launchTaskFromBash:commandString];
    
    //해당 앱이 없어도 complete 표시. 별다른 오류 메시지 없음.
    //return ([output hasSuffix:@"Complete"]);
}

/// @brief  인스톨 파일 다운로드.
/// @brief  하나 Ins 의 요구사항으로 AppStore 을 실행시키는 코드가 들어가 있으나 지금은 사용하지 않음.
/// @brief  사파리 실행 할경우, ResourceMornitor App 을 실행시킨뒤 리소스앱으로 URL 정보를 넣어줘야 함.. 이부분은 정리가 필요함. 필요함.
/// @todo   WebDriverAgent 가 실행된뒤 바로 ResourceMornitor 앱을 실행하고, 성공하면 DC 로 Start 에 대한 성공을 Response 하는걸로 수정하는게 좋음.
- (void)installApplication: (NSString * )strUrl {
    //DDLogInfo(@"######### url = %@ #########",strUrl);
    DDLogDebug(@"%s", __FUNCTION__);
    //사파리의 경우 추후 변경 가능성이 있어서 내비둠
    
    if( [strUrl hasPrefix:@"Safari"] ) {        // 예) Safari|http://naver.com
        NSArray * component = [strUrl componentsSeparatedByString:@"|"];
        if( [component count] == 2 ) {
            _openURL = [component objectAtIndex:1];
        } else {
            _openURL = @"http://";
        }
        
        [_myResource finishResourceMornitor];
        
        
        _myAgent.launchBundleId = @"com.onycom.ResourceMornitor2";
        [self.dicBundleIDs setObject:@YES forKey:_myAgent.launchBundleId];          // 두번실행되지 않게 막아줌...
        _myAgent.nRetryCount = 0;
        [_myAgent launchAppWithBundleID];
        return ;
    }//if : safari
    else if([strUrl isEqualToString:@"appstore"]){
        _myAgent.launchBundleId = @"com.apple.AppStore";
        [self.dicBundleIDs setObject:@YES forKey:_myAgent.launchBundleId];          // 두번실행되지 않게 막아줌...
        _myAgent.nRetryCount = 0;
        [_myAgent launchAppWithBundleID];
        return;
    }
    
    //설치 파일의 종류 확인
//    BOOL bIPA = [strUrl hasSuffix:@"ipa"];        // Zip 파일이 들어올수도 있는거 같음.
    if( [strUrl hasSuffix:@"ipa"] || [strUrl hasSuffix:@"zip"]) {
        NSString *downloadUrl = strUrl;
        NSString *ipaFile = nil;
        //mg//20180508//zip 파일 내에 여러개의 ipa 있을 경우, 설치할 ipa 지정 [xx.zip]\n[xx.ipa] 형태
        NSArray *strParts = [strUrl componentsSeparatedByString:@"\n"];
        NSUInteger strPartsSize = [strParts count];
        if (strPartsSize > 1) {
            downloadUrl = [strParts objectAtIndex:0];
            ipaFile = [strParts objectAtIndex:1];
        }
        
        [AppInstaller asyncDownloadIpaFile:downloadUrl saveFilePath:[self managerDirectoryForDevice] completion:^(BOOL successed, NSString *description) {
            if( successed ) {
                if (ipaFile == nil)
                    [[NSNotificationCenter defaultCenter] postNotificationName:_NAME_DOWN_SUCCESS object:description];
                //mg//20180509//ipa 파일 지정일 경우
                else
                    [[NSNotificationCenter defaultCenter] postNotificationName:_NAME_DOWN_SUCCESS object:[NSString stringWithFormat:@"%@|%@", description, ipaFile]];
            } else {
                DDLogError(@"다운로드 실패 (device no : %d) -- %@", _deviceInfos.deviceNo, description);          // description : Error 정보
                [[NSNotificationCenter defaultCenter] postNotificationName:_NAME_DOWN_FAIL object:description];
            }
        }];
    }//if : ipa, zip
    
    else {
        // bundleID로 실행
        BOOL isInstalledApp = NO;
        

        for(int i = 0; i<_deviceInitAppList.count; i++){
            NSString* temp = [[[_deviceInitAppList objectAtIndex:i] componentsSeparatedByString:@"|"] objectAtIndex:0];
            if([temp isEqualToString:strUrl]){
                isInstalledApp = YES;
                NSLog(@"앱 목록에 있다!! %@",temp);
                break;
            }else{
                NSLog(@"앱 목록에 없다!! %@",temp);
            }
        }
        
        if(isInstalledApp){
            _myAgent.launchBundleId = strUrl;
            
            DDLogWarn(@"launch bundle Id = %@",_myAgent.launchBundleId);
            [self.dicBundleIDs setObject:@YES forKey:_myAgent.launchBundleId];          // 두번실행되지 않게 막아줌...
            _myAgent.bLaunchBundleID = YES;
            _myAgent.nRetryCount = 0;
            [_myAgent launchAppWithBundleID];
        }else{
            DDLogWarn(@"bundle Id is Not Installed");
            [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:NO appId:@"앱 설치오류 = 설치 bundleId" deviceNo:_deviceInfos.deviceNo];
        }
    }//else : id
}//installApplication



/// @brief  파일 다운로드 성공시 설치. (Automation일 경우 Appium실행)
/// @brief  자동화의 경우 예약 테스트 기능이 있는데, 이때 zip 파일을 다운로드함.
- (void)suceessFileDownload:(NSNotification* )noti {
    NSString* strPath = noti.object;
    DDLogDebug(@"%s : %@", __FUNCTION__, strPath);
    //DDLogWarn(@"user info  %@", strPath);
    
    __block __typeof__(self)blockSelf = self;
    dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(globalQueue, ^{
        
        //mg//20180510//[zip file]|[ipa file] 형식 추가. zip 파일 내에 여러개의 ipa 가 있을 경우, 설치할 ipa 지정
        NSRange range;
        range = [strPath rangeOfString:@"|"];
        if (range.location != NSNotFound) {
            NSArray* strParts = [strPath componentsSeparatedByString:@"|"];
            if ([strParts count] <2) {
                [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:NO appId:@"Invalid Request" deviceNo:_deviceInfos.deviceNo];
                return;
            }
            
            NSString* zipFile = [strParts objectAtIndex:0];
            NSString* ipaFile = [strParts objectAtIndex:1];
            
            [blockSelf unzipFile:zipFile];
            NSFileManager* mgr = [NSFileManager defaultManager];

            //mg//20180509//지정된 ipa 설치
            NSString* appPath = [NSString stringWithFormat:@"%@/%@", [blockSelf managerDirectoryForDevice], ipaFile];
            BOOL isAppExist = [mgr fileExistsAtPath:appPath];
            if (isAppExist) {
                _myAgent.installPath = appPath;
            } else {
                [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:NO appId:@"ipa file not exist" deviceNo:_deviceInfos.deviceNo];
                return;
            }
        } //if : ipa 지정
    
        // 확장자가 Zip파일이면 Reservation 테스트. 압축 해제 후, ipa파일 설치.
        else if ([[strPath lowercaseString] hasSuffix:@"zip"]) {
            [blockSelf unzipFile:strPath];
            NSFileManager* mgr = [NSFileManager defaultManager];
            
            NSString *xmlPath = [NSString stringWithFormat:@"%@/TestReservation.xml", [blockSelf managerDirectoryForDevice]];
            BOOL isExist = [mgr fileExistsAtPath:xmlPath];
            BOOL bFind = NO;
                
            //DDLogInfo(@"xmlPath = %@",xmlPath);
            
            if(isExist) {
                NSString *content = [NSString stringWithContentsOfFile:xmlPath encoding:NSUTF8StringEncoding error:NULL];
                NSArray* arrTmp = [content componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                
                //DDLogInfo(@"arrTmp = %@",arrTmp );
                for(NSString* tmp in arrTmp){
                    if ([tmp hasPrefix:@"app"]) {
                        DDLogWarn(@"find key for app");
                        NSString* strApp = [tmp stringByReplacingOccurrencesOfString:@"\"" withString:@""];
                        NSString* strValue = [[strApp componentsSeparatedByString:@"="] lastObject];
                        if([[[[strValue componentsSeparatedByString:@"."] lastObject] lowercaseString] isEqualToString:@"ipa"])
                        {
                            //App정보가 ipa파일 때.
                            //DDLogWarn(@"reservation with ipa=%@", strValue);
                            DDLogInfo(@"install app = %@", strValue);
                            
                            NSString* appPath = [NSString stringWithFormat:@"%@/%@", [blockSelf managerDirectoryForDevice], strValue];
                            BOOL isAppExist = [mgr fileExistsAtPath:appPath];
                            if (isAppExist) {
                                _myAgent.installPath = appPath;
                                bFind = YES;
                            }
                            break;
                        }//if : xml 파일에 ipa 파일명 명시
                        
                        else {
                            // 다운로드 받은 파일이 예약 정보일경우 압축 해제하면 XML 파일이 나오게 되며, 이 파일을 읽었을때 App 정보에 bundleid 가 나온다...
                            // app정보가 bundleId 일 경우
                            DDLogInfo(@"reservation with bundle id =%@", strValue);
                            
                            NSMutableArray* applist = [self getAppListForDevice:NO];
                            NSLog(@"appList = %@",applist);
                            //    NSLog(@"tmep = %@",temp);
                            NSMutableArray* bundleList = [[NSMutableArray alloc] init];
                            for(int i = 0; i<applist.count; i++){
                                NSString* temp = [applist objectAtIndex:i];
                                NSArray* bundleIdTemp = [temp componentsSeparatedByString:@"|"];
                                NSString* bundleId = [bundleIdTemp objectAtIndex:0];
                                [bundleList addObject:bundleId];
                            }
                            ////////////////////////////////////////////////////////////
                            //                            NSArray* temp = [applist componentsSeparatedByString:@"\n"];
                            //                            BOOL bInstalled = [bundleList containsObject:strValue];
                            //                            NSArray* temp = [applist componentsSeparatedByString:@","];
                            
                            BOOL bInstalled = [bundleList containsObject:strValue];
                            if(bInstalled == FALSE){
                                [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:NO appId:@"앱 설치오류 = 미설치 bundleId" deviceNo:_deviceInfos.deviceNo];
                                return;
                            }
                            
                            blockSelf.myAgent.prevBundleId = blockSelf.myAgent.launchBundleId;
                            blockSelf.myAgent.launchBundleId = strValue;
                            [blockSelf.dicBundleIDs setObject:@YES forKey:_myAgent.launchBundleId];          // 두번실행되지 않게 막아줌...
                            _myAgent.nRetryCount = 0;
                            [_myAgent launchAppWithBundleID];
                            return;
                        }//if - else : file/id
                    }//if : app 정보
                } //for(NSString* tmp in arrTmp)
                if (bFind == NO) {
                    DDLogWarn(@"reservation app-key is not find or ipa file is not exist");
                    [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:NO appId:@"예약 정보 오류" deviceNo:_deviceInfos.deviceNo];
                    return;
                }
            } else {
                DDLogWarn(@"reservation TestReservation.xml is not exist");
                [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:NO appId:@"예약 정보 파일 없음" deviceNo:_deviceInfos.deviceNo];
                return;
            }//if - else : xml 파일 확인
        } else {
            _myAgent.installPath = noti.object;
            DDLogInfo(@"install Path = %@",_myAgent.installPath);
        }//if - else : zip/ipa
        
        //swccc
        [self installIDevice];
    });//dispatch_async
}//suceessFileDownload

/// @brief  ipa 파일에서 App 이름을 얻어온다.
-(NSString *) getInstallAppName:(NSString *)path {
    NSString* commandString = [NSString stringWithFormat:@"cd \"%@\" ; unzip -q \"%@\" -d temp ; APP_NAME=$(ls temp/Payload/) ; /usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' \"%@/temp/Payload/$APP_NAME/Info.plist\" ; rm -rf temp",
                               [self managerDirectoryForDevice],
                               path,
                               [self managerDirectoryForDevice]];
    NSTask* iTask =  [[NSTask alloc] init];
    iTask.launchPath = @"/bin/bash";
    
    iTask.arguments  = [NSArray arrayWithObjects:
                        @"-l", @"-c",
                        commandString,
                        nil];
    NSPipe *pipe= [NSPipe pipe];
    [iTask setStandardOutput: pipe];
    
    NSFileHandle *file = [pipe fileHandleForReading];
    
    NSString *output = nil;

    //mg//s
    if( [NSThread isMainThread] ) {
        [iTask launch];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [iTask launch];
        });
    }
    //mg//e

    //mg//[iTask launch];
        
        NSData *data = [file readDataToEndOfFile];
        output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
        
        [file closeFile];
        
        output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        NSRange the_range = [output rangeOfString:@"Exist" options:NSCaseInsensitiveSearch];
        if (the_range.location != NSNotFound) {
            DDLogError(@"Product Name not found:%@", output);
            
            output = nil;
        }
        else {
            DDLogWarn(@"Product Name %@", output);
        }
    
    return output;
}

/// @brief  ipa 파일에서 BundleId 를 얻어온다.
- (NSString*) getBundleID:(NSString*)path
{
    //CFBundleExecutable
    NSString* commandString = [NSString stringWithFormat:@"cd \"%@\" ; unzip -q \"%@\" -d temp ; APP_NAME=$(ls temp/Payload/) ; /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \"%@/temp/Payload/$APP_NAME/Info.plist\" ; rm -rf temp",
                               [self managerDirectoryForDevice],
                               path,
                               [self managerDirectoryForDevice]];
    
    NSTask* iTask =  [[NSTask alloc] init];
    iTask.launchPath = @"/bin/bash";
    
    iTask.arguments  = [NSArray arrayWithObjects:
                        @"-l", @"-c",
                        commandString,
                        nil];
    NSPipe *pipe= [NSPipe pipe];
    [iTask setStandardOutput: pipe];
    
    NSFileHandle *file = [pipe fileHandleForReading];
    
    NSString *output = nil;

    //mg//[iTask launch];
    //mg//s
    if( [NSThread isMainThread] ) {
        [iTask launch];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [iTask launch];
        });
    }
    //mg//e

        NSData *data = [file readDataToEndOfFile];
        output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
        
        [file closeFile];
        
        output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        NSRange the_range = [output rangeOfString:@"Exist" options:NSCaseInsensitiveSearch];
        if (the_range.location != NSNotFound) {
            DDLogError(@"BundleID not found:%@", output);
            DDLogError(@"Use old method");
            output = nil;
        }
        else {
            DDLogWarn(@"BundleID %@", output);
        }
    
    return output;
}

/// @brief  ipa 파일에서 앱이름을 얻는다.
- (NSString*) getBundleName:(NSString*)path
{
    NSString* commandString = [NSString stringWithFormat:@"cd \"%@\" ; unzip -q \"%@\" -d temp ; APP_NAME=$(ls temp/Payload/) ; /usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' \"%@/temp/Payload/$APP_NAME/Info.plist\" ; rm -rf temp",
                               [self managerDirectoryForDevice],
                               path,
                               [self managerDirectoryForDevice]];
    
    NSTask* iTask =  [[NSTask alloc] init];
    iTask.launchPath = @"/bin/bash";
    
    iTask.arguments  = [NSArray arrayWithObjects:
                        @"-l", @"-c",
                        commandString,
                        nil];
    NSPipe *pipe= [NSPipe pipe];
    [iTask setStandardOutput: pipe];
    
    NSFileHandle *file = [pipe fileHandleForReading];
    
    NSString *output = nil;
        //mg//[iTask launch];
    //mg//s
    if( [NSThread isMainThread] ) {
        [iTask launch];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [iTask launch];
        });
    }
    //mg//e
        
        NSData *data = [file readDataToEndOfFile];
        output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
        
        [file closeFile];
        
        output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        NSRange the_range = [output rangeOfString:@"Exist" options:NSCaseInsensitiveSearch];
        if (the_range.location != NSNotFound) {
            DDLogError(@"BundleID not found:%@", output);
            DDLogError(@"Use old method");
            output = nil;
        }
        else {
            DDLogWarn(@"BundleID %@", output);
        }
    
    return output;
}

/// @brief  ipa 파일을 다운로드 성공한뒤 호출되며, idevice 에 앱을 설치하는 과정을 시작한다.
-(void)installIDevice {
    DDLogDebug(@"%s", __FUNCTION__);
    
    __block __typeof__(self) blockSelf = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block NSString * bundleid = [blockSelf getBundleID:blockSelf.myAgent.installPath];
        __block NSString * appName = [blockSelf getBundleName:blockSelf.myAgent.installPath];
        //DDLogWarn(@"=== BUNDLE ID = (%@) ===",bundleid);
        DDLogInfo(@"app id = %@", bundleid);
        
        dispatch_sync(dispatch_get_main_queue(),^ {
            if( bundleid != nil && ![bundleid isEqualToString:@""])
            {
                if( blockSelf.myAgent.bLaunchDone ) {        // App이 실행중이라면...
                    //DDLogVerbose(@"bundle id ? %@", blockSelf.myAgent.launchBundleId);
                    DDLogVerbose(@"current app id = %@", blockSelf.myAgent.launchBundleId);

                    if([blockSelf.myAgent.launchBundleId isEqualToString:@"com.onycom.ResourceMornitor2"]){
                        // Control Agent가 Appium, Instruments 일 때 해당된다.
                        // Control Agent 가 WebDriverAgent 일때 WebDriverAgent 에서 ResourceMornitor 의 BundleID 가 Install 로 들어오지 않는다. (사파리는 touch 로 실행하면 되므로..)
//                        [blockSelf.myAgent finishLaunchedApp:_dicBundleIDs];
                        [blockSelf.myResource launchResourceMornitor];
                    }
                }
                
                blockSelf.myAgent.prevBundleId = self.myAgent.launchBundleId;
                blockSelf.myAgent.launchBundleId = bundleid;
                blockSelf.myAgent.launchAppName = appName;
                
//                [blockSelf.myAgent launchAppWithFilePath];
                [blockSelf.myAgent performSelectorInBackground:@selector(launchAppWithFilePath) withObject:nil];
                return;
            }
        });//dispatch_get_main_queue
    });//dispatch_get_global_queue
}//installIDevice

/// @brief  파일 다운로드 실패시. 실패 리스폰스.
- (void)failFileDownload {
    DDLogError(@"faildownload");
    _myAgent.installPath = nil;
    [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:NO appId:@"앱 설치오류 = 파일 다운로드 실패" deviceNo:_deviceInfos.deviceNo];
}

/// @brief  unzip
- (void)unzipFile : (NSString *)zipPath  {
    
    NSString* dPath = [self managerDirectoryForDevice];
    
    NSTask *theTask = [[NSTask alloc] init];
    theTask.environment = [NSDictionary dictionaryWithObjectsAndKeys:@"/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin", @"PATH", nil];
    theTask.launchPath = @"/usr/bin/unzip";
    theTask.arguments  = [NSArray arrayWithObjects:
                          @"-o", zipPath, @"-d", dPath, nil];
    
    NSPipe *pipe= [NSPipe pipe];
    [theTask setStandardOutput: pipe];
    
    NSFileHandle *file = [pipe fileHandleForReading];
    
        //mg//[theTask launch];
    //mg//s
    if( [NSThread isMainThread] ) {
        [theTask launch];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [theTask launch];
        });
    }
    //mg//e

    NSData *data = [file readDataToEndOfFile];
    [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    
    DDLogWarn(@"===unzip task done ====");
    [file closeFile];
}

/// @brief  디바이스 초기화 (일정,연락처,미디어) 현재 사용하지 않음.
-(void)resetDevice{
    DDLogWarn(@"%s, %d",__FUNCTION__, _deviceInfos.deviceNo);
    
    dispatch_queue_t resourceQueue = dispatch_queue_create("resourceQueue", NULL);
    __block __typeof__(self)blockSelf = self;
    dispatch_async(resourceQueue, ^{
        NSTask *task = [[NSTask alloc] init];
        
        task.environment = [NSDictionary dictionaryWithObjectsAndKeys:@"/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin", @"PATH", nil];
        [task setLaunchPath: @"/usr/local/lib/node_modules/appbuilder/bin/appbuilder.js"];
        [task setArguments: [[NSArray alloc] initWithObjects:@"device",@"run",
                             [NSString stringWithFormat:@"%@",@"com.onycom.ResourceMornitor2"],
                             @"--device", _deviceInfos.udid, nil]];
        
        // 종료되면 taskTerminated:가 호출되다.
        [[NSNotificationCenter defaultCenter] addObserver:blockSelf
                                                 selector:@selector(taskTerminated:)
                                                     name:NSTaskDidTerminateNotification
                                                   object:task];
        // NSTask 파라미터 설정
        @try {
            [task launch];
        } @catch(NSException *e) {
            DDLogError(@"reset error : %@", e.reason);
        }
        
        dispatch_sync(dispatch_get_main_queue(),^ {
            
            if( !_cmtIProxy )
                return ;
            DDLogWarn(@"초기화 실행");
            [_cmtIProxy sendCommand:CMD_RESET autoConnect:false];
        });
    });
}

//mg//
/*- (NSString *)getMyAppListForStart {
    //    NSString* applist = [self getAppListForDevice:NO];
    if(_deviceInitAppList == nil){
        _deviceInitAppList = [((NSArray *)[self getAppListForDevice:NO]) copy];
        return [_deviceInitAppList componentsJoinedByString:@"\n"];
    }
    
    _myAppList = [((NSArray *)[self getAppListForDevice:NO]) copy];
    return [_myAppList componentsJoinedByString:@"\n"];
}*/

/// @brief  rmeove 값에 의해 NSArray 또는 NSDictionary 로 리턴된다.
/// @param  remove 앱을 삭제하기위해 호출 된건지, AppList 정보를 획득하기 위해 호출된건지를 결정한다.
/// @return "번들아이디|앱이름\n번들아이디|앱이름\n번들아이디|앱이름" ...
- (id) getAppListForDevice:(BOOL)remove{
    DDLogDebug(@"%s", __FUNCTION__);
    
    NSTask *task = [[NSTask alloc] init];
    task.environment = [NSDictionary dictionaryWithObjectsAndKeys:@"/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin", @"PATH", nil];
    [task setLaunchPath: @"/usr/local/bin/ideviceinstaller"];
    //하나의 PC에 여러개의 device가 물려있을 경우가 있으므로 self.myDeviceUdid값은 꼭 넣어준다. -u (UDID)
//    [task setArguments: [[NSArray alloc] initWithObjects:@"-l", @"-u", self.deviceInfos.udid, nil]];
    //하나의 PC에 한개의 Device가 물려있을 경우의 명령어
//    [task setArguments: [[NSArray alloc] initWithObjects:@"-l", nil]];
    //해당 시스템앱까지 모두 호출 홈화면 시작에서 수정
    [task setArguments:[[NSArray alloc] initWithObjects:@"-l",@"-o",@"list_all", nil]];
    
    if(![[NSFileManager defaultManager] isExecutableFileAtPath:[task launchPath]] || [[NSWorkspace sharedWorkspace] isFilePackageAtPath:[task launchPath]]){
//        return nil;
        DDLogDebug(@"launchPath Error = %@",[task launchPath]);
        return nil;
    }else{
        NSLog(@"####################");
    }
    
    NSFileHandle *file = nil;
    //출력되는 값
    @try{
        NSPipe *pipe= [NSPipe pipe];
        [task setStandardOutput: pipe];
        file = [pipe fileHandleForReading];
    }
    @catch(NSException * exception){
        DDLogDebug(@"NSException Error = %@ , %@",[exception name], [exception reason]);
        return nil;
    }
    
    if( [NSThread isMainThread] ) {
         DDLogDebug(@"Task Main launch");
         [task launch];
         
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            //exception 발생하면, 이후에 계속 발생하므로, 정상 동작할 수 없음
            //프로그램 재실행하기 위해 공통 예외처리로 넘김
            DDLogDebug(@"Task After launch");
            [task launch];
            
        });
    }//if - else : launch
    
    
    NSData *data = [file readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:data encoding: NSUTF8StringEncoding];
    [file closeFile];
    [task terminate];
    task = nil;
    
//    DDLogVerbose(@"output : %@",output);
    NSArray* list = nil;
    list = [output componentsSeparatedByString:@"\n"];
    
    id appList = nil;
    
    if(list != nil) {
        NSMutableArray * arrAppList = nil;
        NSMutableDictionary * dicAppList = nil;
        
        for(NSString* appId in list) {
            NSArray* tmp = [appId componentsSeparatedByString:@", "];
            if([tmp count] < 3) {
                tmp = [appId componentsSeparatedByString:@" - "];
                if( [tmp count] < 2 )
                    continue;
            }
            NSString * bundleID = [tmp objectAtIndex:0];
            NSString * bundleName;
            if([tmp count] == 2){
                bundleName = [tmp objectAtIndex:1];
            }else{
                bundleName = [tmp objectAtIndex:2];
            }
            
            if( [@"CFBundleIdentifier" isEqualToString:bundleID] )
                continue;
            
            if( [@"com.onycom.ResourceMornitor2" isEqualToString:bundleID] )
                continue;
            
//            [tmpBundleIDs addObject:bundleID];
            NSString* temp = [NSString stringWithFormat:@"%@|%@",bundleID,bundleName];
            
            if( remove ) {
                if( !dicAppList ) {
                    dicAppList = [NSMutableDictionary dictionary];
                    appList = dicAppList;
                }
                [dicAppList setObject:@YES forKey:temp];
            } else {
                if( !arrAppList ) {
                    arrAppList = [NSMutableArray array];
                    appList = arrAppList;
                }
                [arrAppList addObject:temp];
            }
        }
    }
    
//    return [arrAppList componentsJoinedByString:@"\n"];
    return appList;
}//getAppListForDevice


#define XML
/// @brief  idevice 화면 정보를 XML 로 가져와서 최상위 Element 에 "AppiumAUT" 엘리멘트를 추가한뒤 파일로 저장한다.
/// @brief  uploadDumpFile 메소드에서 파일을 읽어서 처리한다... 굳이 파일로 저장할 필요는 없는데.. 디버깅용으로 저장해두는거 같다. (이전담당자가 이렇게 만들어놨음..)
- (NSString *)saveToSourceFile
{
    NSString * page = [_myAgent getPageSource];
    if (page != nil) {
        NSString* appName = [self getAppName];
        NSString* strRotation;

        if([self.myAgent orientation] == SELENIUM_SCREEN_ORIENTATION_PORTRAIT){
            strRotation = @"<AppiumAUT rotation=\"0\">";
        } else {
            strRotation = @"<AppiumAUT rotation=\"1\">";
        }
        
        NSString* editPage = [page stringByReplacingOccurrencesOfString:@"<AppiumAUT>" withString:strRotation];
#ifdef XML
        NSString* path = [NSString stringWithFormat:@"%@/%@.scene.xml", [self managerDirectoryForDevice], @"HomeScreen"];
        [editPage writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        return path;
#endif
        
#ifdef DESCRIPTION
        NSLog(@"================================================================================================");
        //총4번을 거쳐서 띄어쓰기가 있는지 확인해본다.
        NSString* first = [self parseUnderLine:editPage];
        NSString* two = [self parseUnderLine:first];
        NSString* three = [self parseUnderLine:two];
        NSString* output = [self parseUnderLine:three];
        output = [output stringByReplacingOccurrencesOfString:@"(onycom)" withString:@"&#10;"];
        NSLog(@"================================================================================================");
//        NSLog(@"output = %@",output);
        NSLog(@"================================================================================================");
        NSString* path = [NSString stringWithFormat:@"%@/%@.scene.xml", [self managerDirectoryForDevice], @"HomeScreen"];
        [output writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        return path;

#endif
    }
    
    return nil;
}

-(NSString *)parseUnderLine:(NSString *)source{

    NSArray* temp = [source componentsSeparatedByString:@"\n"];
    NSLog(@"count = %d",(int)temp.count);
    int totalCount = (int)temp.count;
    NSString* output = @"";

    if(totalCount > 0){
        for(int i = 0; i<totalCount; i++){
            NSString* line = [NSString stringWithFormat:@"%@",[temp objectAtIndex:i]];
            if([line containsString:@"label:"]){
                output = [output stringByAppendingString:line];
                NSArray* temp2 = [line componentsSeparatedByString:@"label: '"];
                NSString* check = [NSString stringWithFormat:@"%@",[temp2 lastObject]];
                if([check containsString:@"'"]){
                    output = [output stringByAppendingString:@"\n"];
                }else{
                    //                       \n-> &#10;
                    output = [output stringByAppendingString:@"(onycom)"];
                }
            }else{
                output = [output stringByAppendingString:line];
                output = [output stringByAppendingString:@"\n"];
            }
        }
    }

    return output;
}


/// @brief  사용하지 않음.
- (NSString *)getBundleID {
    return @"";
}

/// @brief  앱이름을 리턴한다.
/// @return 앱이름.
- (NSString *)getAppName {
    return _myAgent.launchAppName;
}

/// @brief  앱이름을 리턴한다.
/// @return 앱 이름
-(NSString *)getInstallAppName{
    return _myAgent.launchAppName;
}

/// @brief   앱의 BundleID 를 리턴한다.
/// @return  bundleid
- (NSString *)getLaunchBundleId {
    return _myAgent.launchBundleId;
}

/// @brief  구동 완료 (제어를 할 준비가 완료됨.)
/// @details 중요!! LaunchDone = YES 는 Agent 를 사용할 수 있는 상태가 된 걸 의미 함. Appium(또는 자동화) 과 Instruments 는 App 을 설치하여 실행한뒤, WebDriveragent 는 WebDriverAgentRunner 를 설치하여 실행한 뒤 이며 HomeScreen(springboard) 상태이다.
- (BOOL) getLaunchDone {
    return _myAgent.bLaunchDone;
}

/// @brief  MainViewController 에서 구성한 한글 토큰값을 넣어줌.  RemoteKeyboard 기능에서 사용함.
- (void) setDicKorTokens:(NSDictionary *)tokens {
    _myAgent.dicKorTokens = tokens;
}

/// @brief  관리자 페이지에서 설정앱 실행과 관련 옵션이 있는데 그 값을 DC 로 부터 전달받아 셋팅함..
- (void)lockSetting:(NSData *)packet {
    int nLock = 0;
    const uint8_t * lock = (uint8_t *)packet.bytes;
    if( lock ) {
        nLock = (int)lock[0];
    }
    
    if( !lock || 1 == nLock ) {
        _myAgent.nLockSetting = 1;
    } else {
        _myAgent.nLockSetting = 0;
    }
}

-(BOOL)deviceGetStatus{
    BOOL bStatus = [_myAgent getStatus];
    return bStatus;
//    [_myAgent clearSafari];
    return YES;
}

@end


