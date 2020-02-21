//
//  Agent.h
//  Manager
//
//  Created by SR_LHH_MAC on 2017. 7. 31..
//  Copyright © 2017년 tomm. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CommunicatorWithDC.h"
#import "DeviceInfo.h"

typedef NS_ENUM(NSInteger, REMOTE_KEY_TYPE) {
    REMOTE_KEY_NONE = 0,
    REMOTE_KEY_KOR = 1,
    REMOTE_KEY_ENG = 2
};

#pragma mark -
#pragma mark <SelectObject (자동화 엘리먼트 구조)>

@interface SelectObject : NSObject
//20180906//문자열 검색 패턴
@property (nonatomic, strong) NSString *scrollPath;
//20180906//Pattern 검색 추가
@property (nonatomic, strong) NSString *scrollClass;//search type 지정(Text/Class)
@property (nonatomic, strong) NSString *targetValue;
@property (nonatomic, strong) NSString *targetName;
@property (nonatomic, strong) NSString *targetLabel;
@property (nonatomic, strong) NSString *targetPath;
@property (nonatomic, strong) NSString *targetClass;
@property (nonatomic, strong) NSString *inputText;
@property (nonatomic, assign) int8_t longPress;
@property (nonatomic, assign) int8_t scrollType;
@property (nonatomic, assign) int8_t scrollCount;
//mg//@property (nonatomic, assign) int8_t instance;
@property (nonatomic, assign) short instance;//mg//

@end

#pragma mark - <ControlAgent>


@protocol ControlAgentDelegate;

@interface ControlAgent : NSObject {
    __weak id<ControlAgentDelegate> customDelegate;
    
    /// @brief      AppiumDeviceMapping.tx 에서 읽어들인 정보를 담고 있는 객체
    DeviceInfos         * deviceInfos;
    
    /// @brief      Agent 를 사용할 준비 완료 상태
    BOOL                bLaunchDone;
    
    /// @brief      관리자페이지에서 설정한 설정앱 진입
    int                 nLockSetting;
    
    /// @brief      필요없음.
    BOOL                bLaunchBundleID;
    
    NSString            * prevBundleId;
    
    /// @brief      현재 실행 한/할 앱의 BundleID
    NSString            * launchBundleId;
    
    /// @brief      앱이름
    NSString            * launchAppName;
    
    /// @brief      경로.. ios-deploy 로 인스톨 할때 ipa 파일 경로가 필요함.
    NSString            * installPath;
    
    /// @brief      지금 사용안함.
    NSDictionary        * dicKorTokens;
    
    /// @brief      드레그 동작을 위해 사용함.
    NSDate              * touchDate;
}

@property (nonatomic, weak) id<ControlAgentDelegate> customDelegate;
@property (nonatomic, strong) DeviceInfos   * deviceInfos;
@property (nonatomic, assign) BOOL          bLaunchDone;            // 중요!! LaunchDone = YES 는 Agent 를 사용할 수 있는 상태가 된 걸 의미 함. Appium 과 Instruments 는 App 을 설치하여 실행한뒤, WebDriveragent 는 WebDriverAgentRunner 를 설치하여 실행한 뒤 이며 HomeScreen 상태이다.
@property (nonatomic, assign) int           nLockSetting;
@property (nonatomic, assign) BOOL          bLaunchBundleID;
@property (nonatomic, strong) NSString      * prevBundleId;
@property (nonatomic, strong) NSString      * launchBundleId;
@property (nonatomic, strong) NSString      * launchAppName;
@property (nonatomic, strong) NSString      * installPath;
@property (nonatomic, strong) NSDictionary  * dicKorTokens;
@property (nonatomic, strong) NSDate        * touchDate;



@property (nonatomic, assign) int nRetryCount;

//+ (ControlAgent *)createControlAgentWithInfo:(NSString *)agentInfo;

//=== 시작
- (void)settingBeforeLaunch;
- (void)settingBeforeTerminate;
- (void)launchControlAgent;
- (void)launchAppWithBundleID;
//mg//- (BOOL)launchAppWithBundleID:(NSString *)bundleID;
- (void)launchAppWithFilePath;

//=== STOP
- (void)finishControlAgent:(NSDictionary *)dicBundleIds;

- (void)doTouchStartAtX:(int)argX andY:(int)argY;
- (void)doTouchMoveAtX:(int)argX andY:(int)argY;
//자동화인지 매뉴얼인지 체크를 하여서 자동화일 경우에는 Swipe명령어를 타지 않도록 한다.
- (void)doTouchEndAtX:(int)argX andY:(int)argY andAuto:(BOOL)bAuto;
- (void)doMultiTouchStartAtPoint1:(NSPoint)point1 andPoint2:(NSPoint)point2;
- (void)doMultiTouchMoveAtPoint1:(NSPoint)point1 andPoint2:(NSPoint)point2;
- (void)doMultiTouchEndAtPoint1:(NSPoint)point1 andPoint2:(NSPoint)point2;

//==== 무브
- (void)doTapAtX:(float)argX andY:(float)argY;
- (void)doTapAtX2:(float)argX andY:(float)argY;
- (void)doSwipeAtX1:(int)argX1 andY1:(int)argY1 andX2:(int)argX2 andY2:(int)argY2;

//==== 하드키
- (void)hardKeyEvent:(int)nKey longpress:(int)nType;
- (void)homescreen;

//==== Text 입력
- (void)inputTextByString:(NSString *)string;
- (void)inputRemoteKeyboardByKey:(NSData *)string;
- (void)autoInputText:(NSData *)data;

//=== 디바이스 회전
- (void)autoOrientation:(BOOL)bLand;

//=== pageSource
- (NSString *)getPageSource;
- (NSData *)getScreenShot;

- (BOOL)autoRunApp:(NSString *)bundleId;
- (NSDictionary *)executeScript:(NSString *)script;

- (void)automationSearch:(NSData *)data andSelect:(BOOL)bSelect;

- (void)likeSearch:(NSData *)data andSelect:(BOOL)bSelect;

- (int)orientation;

//=== INSTALL
- (void)installDownIPA:(BOOL)bLaunch;
- (void)launchDeviceApplication:(NSString *)bundleID;
//=== Page Source
//- (NSString *)saveToSourceFile;


- (NSString *)safariAddressElemSessionId:(NSString *)url;
- (void)openURL:(NSString *)url;


- (BOOL)getStatus;

//Safari 초기화 테스트
- (void)clearSafari;
- (void)terminateApp:(NSString *)bundleId;
- (void)launchApp:(NSString *)bundleId;

@end

#pragma mark - <ControlAgentDelegate>
@protocol ControlAgentDelegate <NSObject>
@required
- (void) agentCtrlLaunchSuccessed;
- (void) agentCtrlLaunchFailed;

- (void) applicationLaunchSuccessed;
- (void) applicationLaunchFailed:(NSString *)description;

- (void) reLaunchResourceMornitor;          // ResourceMornitor App 을 재실행하기 위해서 호출된다. (iOS 10.x 버전에서 사파리 실행후 종료하게 되면 ResourceMornitor App 이 종료되기 때문에 사파리 종료되면 호출 됨.)

@end




