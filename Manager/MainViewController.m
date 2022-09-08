//
//  MainViewController.m
//  Manager
//
//  Created by mac_onycom on 2015. 6. 22..
//  Copyright (c) 2015년 tomm. All rights reserved.
//

#import "MainViewController.h"
#import "Selenium.h"
#import "ConnectionItemInfo.h"
#import "CommunicatorWithDC.h"

#import "DeviceLog.h"
#import "Utility.h"
#import "AppDelegate.h"
#import "LogToFile.h"

#import "DeviceInfo.h"

#define TESTDEVICENO 0

#define KEY_UDID        @"udid"
#define KEY_USBNUMBER   @"usbNumber"
#define KEY_OBJECT      @"object"
#define KEY_INDEX       @"index"

#define AGENTINFO_NAME          @"AgentInfo.txt"

typedef NS_ENUM(NSInteger, LOG_TYPE) {
    TYPE_DEVICE = 0,
    TYPE_APPIUM =1,
    TYPE_MANAGER =2
};

//typedef NS_ENUM(NSInteger, DEVICE_INFO) {
//    INFO_DEVICE_NONE = 0,
//    INFO_DEVICE_LIST,
//    INFO_DEVICE_CHANGE
//};

@interface MainViewController () <ConnectionItemInfoDelegate, NSComboBoxDelegate> {
    int nComboNumber;
    NSString* deviceUdid;
}

/// @brief  한글 토큰 RemoteKeyboard 사용시 입력받은 키보드의 문자로 한글 문자를 변환하기 위해 사용함.
@property (nonatomic, strong) NSMutableDictionary   * dicKorTokens;

/// ConnectionItemInfo 의 리스트
@property (nonatomic, strong) NSMutableArray        * arrConnectionItemList;

//swccc test
@property (nonatomic, strong) NSMutableArray        * arrStartAppList;

/// 사용안함.
@property (nonatomic, strong) dispatch_queue_t      listenQueue;

/// 사용안함.
@property (nonatomic, strong) dispatch_semaphore_t  listenSem;

/// UI에 출력중인 로그정보를 일정 시간단위로 삭제하기 위해 서용하는 타이머
@property (nonatomic, strong) NSTimer               * clearLogTimer;

@property (nonatomic, assign) IBOutlet NSComboBox            *comboBox;
@property (nonatomic, assign) IBOutlet NSProgressIndicator   *indicator;

@property (weak) IBOutlet NSBox* boxBuildLoading;
@property (weak) IBOutlet NSImageView* imgView;
@property (weak) IBOutlet NSScrollView *managerField;
@property (assign) IBOutlet NSTextView *txtManagerView;


@property (assign) IBOutlet NSButton *btnLOG;

#ifdef VER_STANDALONE
///사용하지 않음.
@property (nonatomic, strong) NSMutableArray        * arrDeviceUsedList;
//@property (nonatomic, assign) DEVICE_INFO           deviceInfoMode;
#endif

/// AgentInfo.txt 파일에서 읽어 저장하는 변수이며, WebDriverAgent, Instruments, Appium 중 한가지를 선택해서 사용하도록 한다.
/// 멀티 연결되도록 수정이 된다면... 위의 정보를 ConnectionItemInfo 객체 개별적으로 사용할 수 있도록 해야 한다. (Device 마다 설정정보가 다를수 있으므로..)
@property (nonatomic, strong) NSDictionary          * dicAgentInfos;

@property (weak) IBOutlet NSButton *btnRestartManager;
- (IBAction)ResetAll:(id)sender;
- (IBAction)connectDevice:(id)sender;
- (IBAction)getPageSourceByXml:(id)sender;
- (IBAction)removeDeviceLog:(id)sender;
- (IBAction)saveLogFile:(id)sender;
- (IBAction)startLog:(id)sender;
- (IBAction)expandAppLog:(id)sender;

@end

/// @brief 메인뷰 컨트롤러
@implementation MainViewController
/// @brief 초기화..
- (void) awakeFromNib {
    _arrConnectionItemList = [NSMutableArray arrayWithCapacity:20];
    _listenQueue = dispatch_queue_create("ListenQueue", NULL);
    _listenSem = dispatch_semaphore_create(1);
    
    _dicAgentInfos = nil;
    
#ifdef VER_STANDALONE
    _arrDeviceUsedList = [NSMutableArray arrayWithCapacity:9];
    for( int i = 0; i < 9; ++i ) {
        [_arrDeviceUsedList addObject:[NSNumber numberWithBool:NO]];
    }
    
//    _deviceInfoMode = INFO_DEVICE_NONE;
#endif
}

/// @brief 소멸자.. 굳이 필요없음..
- (void) dealloc {
    [_clearLogTimer invalidate];
    _clearLogTimer = nil;
    _dicAgentInfos = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/// @brief  파일에서 정보를 읽어들여 설정하고, 소켓을 생성해서 DC 와 연결하는 동작을 한다.
- (void)viewDidLoad {
	
    [super viewDidLoad];
    
    nComboNumber = 0;
    
    [self.view setAutoresizesSubviews:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceConnect:) name:DEVICE_CONNECT object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceDisConnect:) name:DEVICE_DISCONNECT object:nil];

///////// 로그 출력을 막을 경우 아래 부분을 주석 처리
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceLog:) name:DEVICE_LOG object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appiumLog:) name:APPIUM_LOG object:nil];
    
    //불필요 기능
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appInfo:) name:APP_INFO object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(managerLog:) name:LOG_SEND object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(managerLog:) name:LOG_ERROR_SEND object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(managerLog:) name:LOG_WARN_SEND object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(managerLog:) name:LOG_INFO_SEND object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(managerLog:) name:LOG_DEBUG_SEND object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(managerLog:) name:LOG_VERBOSE_SEND object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dcLog:) name:LOG_DC_SEND object:nil];
    
    [self.comboBox setDelegate:self];
//    [self.indicator setHidden:YES];

    [self.btnRestartManager setState:NSControlStateValueOn];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:MANAGERRESTART];
    [self.managerField.documentView setTextColor:[NSColor whiteColor]];
    [self.managerField.documentView setBackgroundColor:[NSColor blackColor]];
//    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:MANAGERRESTART];
    
    
    //    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(managerErrorLog:) name:LOG_ERROR_SEND object:nil];
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    dateToday=[[NSDateFormatter alloc] init];
    //시간별로 저장할 경우
//    [dateToday setDateFormat:@"yyMMddHH"];
    //일자별로 저장할 경우
    [dateToday setDateFormat:@"yyMMdd"];
    
    dateNow = [[NSDateFormatter alloc] init];
    
    //mg//[dateNow setDateFormat:@"yyMMddHHmmss"];
    [dateNow setDateFormat:@"yy/MM/dd HH:mm:ss"];//mg//
        
    [self makeTokens];

    [self comboBoxItem];
       
    [self showProgressStart:NO];
    
    _dicAgentInfos = [self getAgentInfos];
#ifdef VER_STANDALONE
    [self initConnectionItemList];
#else
    [self __getMappingTableFromFileName:MAPPINGFILE];
#endif
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    int nSlot = (int)[defaults integerForKey:DC_PORTNO];
    nComboNumber = (int)[defaults integerForKey:DC_PORTNO];
//    ConnectionItemInfo* itemInfo = [self connectionItemInfoByDeviceNo:nSlot+1];
    ConnectionItemInfo* itemInfo = [self connectionItemInfoByDeviceNo:nSlot+1];
    deviceUdid = itemInfo.deviceInfos.udid;
    [itemInfo clearProcess:deviceUdid andLog:YES];
//    int nDeviceCount = [self getDeviceCount];
//    DDLogInfo(@"Connected USB Device count : %d", nDeviceCount);
    [self startSocketServer:0];
    // 12시간 단위로 로그를 초기화 한다.
    _clearLogTimer = [NSTimer scheduledTimerWithTimeInterval:(12 * 60 * 60) target:self selector:@selector(onClearLogTimer:) userInfo:nil repeats:YES];
//    _clearLogTimer = [NSTimer scheduledTimerWithTimeInterval:(10 * 60) target:self selector:@selector(onClearLogTimer:) userInfo:nil repeats:YES];
        
    DDLogInfo(@"LOG_LEVEL_DEF = %d",LOG_LEVEL_DEF);
    DDLogInfo(@"LOG_LEVEL_VERBOSE = %d",(int)LOG_LEVEL_VERBOSE);

    //
//    DDLogInfo(@"마이로그 %@ and %@",@"에러",@"경고");
//    DDLogInfo(@"헤이");
//    
//    DDLogError(@"에러 로그");
//    
//    DDLogWarn(@"경고 로그");.
//    NSString* bundleURL = [[NSBundle mainBundle] bundlePath];
}

/// @brief RemoteKeyboard 동작시 문자가 들어오는게 아니라.. 아스키코드값이 들어와서 아스키코드와 매칭되는 한글 문자를 변환하기 위한 값들을 저장한다.
/// @brief 문자가들어와서 문자를 전달하면 정말 빠르게 동작을 시킬수 있는데.... 아스키코드값이 들어옴... DC 와 Android 가 연괄되어있어 수정해주지 않음..
/// @brief 현재 일부 안드로이드 에서 리모트 키값이 영문자로만 들어간다고 해서.. 이 기능을 사용하지 않고, 영문자를 그대로 폰에 넣어주고 있음.
- (void) makeTokens {
    _dicKorTokens = [NSMutableDictionary dictionaryWithCapacity:27];
    NSArray * tokens = @[@"ㅁ", @"ㅠ", @"ㅊ", @"ㅇ", @"ㄷ", @"ㄹ", @"ㅎ", @"ㅗ", @"ㅑ", @"ㅓ", @"ㅏ", @"ㅣ", @"ㅁ", @"ㅜ", @"ㅐ", @"ㅔ", @"ㅂ", @"ㄱ", @"ㄴ", @"ㅅ", @"ㅕ", @"ㅍ", @"ㅈ", @"ㅌ", @"ㅛ", @"ㅋ"];
    for(int i = 65, j = 0; i < 91; ++i, ++j ) {
        NSData * key = [NSData dataWithBytes:&i length:4];
        [_dicKorTokens setObject:tokens[j] forKey:key];
    }
}


-(void)createDirectory:(NSString *)directoryName atFilePath:(NSString *)filePath
{
    NSString *filePathAndDirectory = [filePath stringByAppendingPathComponent:directoryName];
    NSError *error;
    
    if (![[NSFileManager defaultManager] createDirectoryAtPath:filePathAndDirectory
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&error])
    {
        DDLogError(@"Create directory error: %@", error);
    }
}

/// @brief 예외 발생시 로그 파일 저장
-(void)logToFile:(NSString * )msg
{
    //get path to Documents/*.txt
//    NSLog(@"### LOG ###");
//    NSLog(@"%@",msg);
//    NSLog(@"### LOG ###");
    [self performSelectorOnMainThread:@selector(saveLogData:)
                           withObject:msg
                        waitUntilDone:YES];
}

/// @brief 예외 발생시 로그 파일 저장
//-(void)saveLogData:(id)logData{
//    const NSString* directory = [NSString stringWithFormat:@"%@/LOG", [Utility managerDirectory]];
//    if(![[NSFileManager defaultManager] fileExistsAtPath:(NSString *)directory]){
//        //mg//[self createDirectory:@"LOG" atFilePath:(NSString *)directory];
//        [self createDirectory:@"LOG" atFilePath:[Utility managerDirectory]];//mg//
//    }
//
////    NSDateFormatter *date = [[NSDateFormatter alloc] init];
////    [date setDateFormat:@"yyMMdd"];
//
////    NSString* dateDir = [NSString stringWithFormat:@"%@/LOG/%@",managerDirectory(),[date stringFromDate:[NSDate date]]];
////    if(![[NSFileManager defaultManager] fileExistsAtPath:dateDir]){
////        [self createDirectory:[date stringFromDate:[NSDate date]] atFilePath:directory];
////    }
//
////    NSString* path = [NSString stringWithFormat:@"%@/LOG/%@/%@.manaul.log.txt",managerDirectory(),[date stringFromDate:[NSDate date]],[dateToday stringFromDate:[NSDate date]]];
//    NSString* path = [NSString stringWithFormat:@"%@/%@.manaul.log.txt", directory, [dateToday stringFromDate:[NSDate date]]];
//    // create file
//    if(![[NSFileManager defaultManager] fileExistsAtPath:path]){
//        fprintf(stderr, "Creating file at %s",[path UTF8String]);
//        [[NSData data] writeToFile:path atomically:YES];
//    }
//
//    // append
//    NSFileHandle* handle = [NSFileHandle fileHandleForWritingAtPath:path];
//    [handle truncateFileAtOffset:[handle seekToEndOfFile]];
//    [handle writeData:[logData dataUsingEncoding:NSUTF8StringEncoding]];
//    [handle closeFile];
//}


-(void)saveLogData:(id)logData{
    const NSString* directory = [NSString stringWithFormat:@"%@/LOGM", [Utility managerDirectory]];
    if(![[NSFileManager defaultManager] fileExistsAtPath:(NSString *)directory]){
        [self createDirectory:@"LOGM" atFilePath:[Utility managerDirectory]];
    }
    NSString* path = [NSString stringWithFormat:@"%@/%@(%d).log.txt", directory, [dateToday stringFromDate:[NSDate date]],nComboNumber];
    // create file
    if(![[NSFileManager defaultManager] fileExistsAtPath:path]){
        fprintf(stderr, "Creating file at %s",[path UTF8String]);
        [[NSData data] writeToFile:path atomically:YES];
    }
    
    // append
    NSFileHandle* handle = [NSFileHandle fileHandleForWritingAtPath:path];
    [handle truncateFileAtOffset:[handle seekToEndOfFile]];
    [handle writeData:[logData dataUsingEncoding:NSUTF8StringEncoding]];
    [handle closeFile];
}

/// @brief Manager UI Log 출력
-(void)managerLog:(NSNotification* )noti
{
//    NSString* log;
    NSString* log;
    //info
    if([noti.name isEqualToString:@"LOG_INFO_SEND"]){
        log = [NSString stringWithFormat:@"\n%@ [I] : %@",[dateNow stringFromDate:[NSDate date]],noti.object];
        [self appendStringValue:log mode:3 type:TYPE_MANAGER];
    }
    //warning
    else if([noti.name isEqualToString:@"LOG_WARN_SEND"]){
        log = [NSString stringWithFormat:@"\n%@ [W] : %@",[dateNow stringFromDate:[NSDate date]],noti.object];
        [self appendStringValue:log mode:2 type:TYPE_MANAGER];
    }
    //error
    else if([noti.name isEqualToString:@"LOG_ERROR_SEND"]){
        log = [NSString stringWithFormat:@"\n%@ [E] : %@",[dateNow stringFromDate:[NSDate date]],noti.object];
        [self appendStringValue:log mode:1 type:TYPE_MANAGER];
    }
//    [NSString stringWithFormat:@"\n%@ [I] : %@",[dateNow stringFromDate:[NSDate date]],noti.object];;
    [self logToFile:log];
}//managerLog

/// @brief DC에서 전달받은 Command 를 UI 에 출력함.
-(void)dcLog:(NSNotification* )noti
{
    NSLog(@"%s",__FUNCTION__);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* log;
//        log = [NSString stringWithFormat:@"\n%@ : \n[DC] : %@",[dateNow stringFromDate:[NSDate date]],noti.object];
//        NSDate* date = [NSDate date];
//        NSCalendar *calendar = [NSCalendar currentCalendar];
//        NSUInteger flags = NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay;
//        NSDateComponents *comps =[calendar components:flags fromDate:date];
//        NSString* dateTimeString = [NSString stringWithFormat:@"%d/%d %d:%d:%d",comps.month,comps.day,comps.hour,comps.minute,comps.second];
        
        
        NSDate *date = [NSDate date];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"M/d H:mm:ss"];
        NSString *dateString = [dateFormatter stringFromDate:date];
        
        
        
        log = [NSString stringWithFormat:@"[%@] : %@\n",dateString,noti.object];
        
        
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = NSTextAlignmentLeft;
        NSFont * labelFont = [NSFont fontWithName:@"Helvetica-Light" size:12];
        NSColor* labelColor = [NSColor blackColor];

        NSShadow *shadow = [[NSShadow alloc] init];
        [shadow setShadowColor : [NSColor blackColor]];
        [shadow setShadowOffset : CGSizeMake (0.1, 0.1)];
        [shadow setShadowBlurRadius : 1];
        
        
        NSAttributedString* stringToAppend = [[NSAttributedString alloc] initWithString:log attributes:@{
                                                                                                            NSParagraphStyleAttributeName : paragraphStyle,
                                                                                                            NSKernAttributeName : @2.0,
                                                                                                            NSFontAttributeName : labelFont,
                                                                                                            NSForegroundColorAttributeName : labelColor,
                                                                                                            NSShadowAttributeName : shadow }];
    });
}



/// @brief Manager Error Log
-(void)managerErrorLog:(NSNotification* )noti
{
    NSString* log = [NSString stringWithFormat:@"\n[MANAGER_ERROR] : %@",noti.object];
    [self appendStringValue:log mode:1 type:TYPE_MANAGER];
}

/// @brief App 정보 얻어오기
-(void)appInfo:(NSNotification *)noti
{
    DDLogInfo(@"%s",__FUNCTION__);
    ConnectionItemInfo* itemInfo = [self connectionItemInfoByDeviceNo:1];
    appName = [itemInfo getInstallAppName];
    appName2 = [itemInfo getAppName];
    DDLogInfo(@"appName = %@",appName);
    
}

/// @brief 디바이스 연결 정보를 View 에 보여준다.
-(void)deviceConnect:(NSNotification* )noti
{
    [self.imgView setImage:[NSImage imageNamed:@"connect.jpeg"]];
}

-(void)deviceDisConnect:(NSNotificationCenter*)noti{
    [self.imgView setImage:[NSImage imageNamed:@"wait.jpeg"]];
}

/// @brief 디바이스 로그 정보
-(void)deviceLog:(NSNotification *)noti
{
//    NSString* date = [[noti userInfo] valueForKey:@"DATE"];
//    NSString* process = [[noti userInfo] valueForKey:@"PROCESS"];
//    NSString* tag = [[noti userInfo] valueForKey:@"TAG"];
//    NSString* log = [[noti userInfo] valueForKey:@"LOG"];
//    
//    NSMutableDictionary* dictLog = [[NSMutableDictionary alloc] init];
//    [dictLog setObject:date forKey:@"DATE"];
//    [dictLog setObject:process forKey:@"PROCESS"];
//    [dictLog setObject:tag forKey:@"TAG"];
//    [dictLog setObject:log forKey:@"LOG"];
//    
//    NSString* appLog = [NSString stringWithFormat:@"[%@] %@",process,log];
//    date = [NSString stringWithFormat:@"\n%@ [%@] ",date,tag];
    
//    [self appendStringValue:date mode:0 type:TYPE_DEVICE];
//    if([tag isEqualToString:@"Error"]){
////        [self logToFile:appLog];
//        [self appendStringValue:appLog mode:1 type:TYPE_DEVICE];
//    }else{
////        [self logToFile:appLog];
//        [self appendStringValue:appLog mode:2 type:TYPE_DEVICE];
//    }

    NSDate *date = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"M/d H:mm:ss"];
    NSString *dateString = [dateFormatter stringFromDate:date];
    NSString* log = [NSString stringWithFormat:@"[%@] : %@\n",dateString,noti.object];
    
    [self appendStringValue:log mode:0 type:TYPE_DEVICE];
}

-(void)appiumLog:(NSNotification *)noti
{
    NSString* log = [NSString stringWithFormat:@"%@",noti.object];
    [self appendStringValue:log mode:0 type:TYPE_APPIUM];
}

- (void) initCache {
    DDLogWarn(@"\n\n######  Cache Info  ######################################");
    NSURLCache * pre_cache = [NSURLCache sharedURLCache];
    [pre_cache removeAllCachedResponses];
    
    DDLogWarn(@"CurrentDiskUsage : %u", (unsigned int)pre_cache.currentDiskUsage);
    DDLogWarn(@"diskCapacity : %d", pre_cache.diskCapacity);
    DDLogWarn(@"currentMemoryUsage : %d", (int)pre_cache.currentMemoryUsage);
    DDLogWarn(@"memoryCapacity : %d\n\n\n\n", (int)pre_cache.memoryCapacity);
    
    NSURLCache * cache = [[NSURLCache alloc] initWithMemoryCapacity:(1024 * 1024 * 2)  diskCapacity:(1024 * 1024 * 40) diskPath:@"URLCache"];
    [NSURLCache setSharedURLCache:cache];
}

/// @brief AgentInfo.txt 에서 정보를 읽어들인다. 추후 멀티제어하기 위해 이 정보는 AppiumDeviceMapping.txt 에 들어가 디바이스 개별적으로 설정하도록 해야 한다.
- (NSDictionary *)getAgentInfos{
    
    NSString *thePath = [NSString stringWithFormat:@"%@/%@", [Utility managerDirectory], AGENTINFO_NAME];
    
    DDLogInfo(@"name Path : %@", thePath);
    NSFileManager * fileManager = [NSFileManager defaultManager] ;
    
    if (![fileManager fileExistsAtPath:thePath]) {        // 파일이 없음.
        DDLogError(@"######## AgentInfo 파일이 없음 ###########");
        return nil;
    }
    
    NSError * error = nil;
    NSData * content = [NSData dataWithContentsOfFile:thePath];
    NSDictionary *dicContent = [NSJSONSerialization JSONObjectWithData:content
                                                               options: NSJSONReadingMutableContainers & NSJSONReadingMutableLeaves
                                                                 error: &error];
    
    DDLogInfo(@"file content to dictionary : %@", dicContent);
    
    //    return [dicContent objectForKey:AGENT_MODE_KEY];
    return dicContent;
}

//-(void)comboBoxItem{
//    NSString *thePath = [NSString stringWithFormat:@"%@/%@", [Utility managerDirectory], MAPPINGFILE];
//    NSString *content = [NSString stringWithContentsOfFile:thePath encoding:NSUTF8StringEncoding error:NULL];
//    NSArray *theContentList = [content componentsSeparatedByString:@"\n"];
//    for (NSString *theItemInfo in theContentList) {
//        NSArray *theItemList = [theItemInfo componentsSeparatedByString:@"|-|"];
//        NSString *deviceNo = [theItemList objectAtIndex:0];
//        [self.comboBox addItemWithObjectValue:deviceNo];
//    }
//    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
//    int nPort = (int)[defaults integerForKey:DC_PORT];
//
////    [self.comboBox selectItemAtIndex:0];
//    [self.comboBox selectItemAtIndex:nPort];
//}
-(void)comboBoxItem{
    NSString *thePath = [NSString stringWithFormat:@"%@/%@", [Utility managerDirectory], MAPPINGFILE];
    NSString *content = [NSString stringWithContentsOfFile:thePath encoding:NSUTF8StringEncoding error:NULL];
    NSArray *theContentList = [content componentsSeparatedByString:@"\n"];
    for (NSString *theItemInfo in theContentList) {
        NSArray *theItemList = [theItemInfo componentsSeparatedByString:@"|-|"];
        NSString *deviceNo = [theItemList objectAtIndex:0];
        NSLog(@"%@",deviceNo);
        [self.comboBox addItemWithObjectValue:deviceNo];
    }
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
//    int nPort = (int)[defaults integerForKey:DC_PORT];
    int prevPortNo = (int)[defaults integerForKey:DC_PORTNO];
//    NSLog(@"port = %d",nPort);
    NSLog(@"port = %d",prevPortNo);
    int nIndex = 0;
    for(int i = 0; i<self.comboBox.numberOfItems; i++){
        NSString* temp = [self.comboBox itemObjectValueAtIndex:i];
        NSLog(@"temp = %@",temp);
        if(prevPortNo == [temp intValue] - 1){
            NSLog(@"######## index = %d",i );
            nIndex = i;
        }
    }
    [self.comboBox selectItemAtIndex:nIndex];

//    NSLog(@"%@",[self.comboBox objectValues]);
//    [self.comboBox selectItemAtIndex:0];
//    [self.comboBox selectItemAtIndex:0];
    
}

/// @brief AppiumDeviceMapping.txt 에서 정보를 읽어들여 ConnectionItemInfo 객체리스트를 생성하며, 각각의 객체에 정보를 넣어준다.
- (void)__getMappingTableFromFileName:(NSString *)argFileName{
// DeviceNo |-|   UDID   |-| devicename |-| device version |-| appium port |-| device ratio |-| ios-webkit port
//   8      |-|udid123abh|-|  version   |-|     9,3,2      |-|    4730     |-|       2      |-| 27760
    NSString *thePath = [NSString stringWithFormat:@"%@/%@", [Utility managerDirectory], argFileName];
    NSString *content = [NSString stringWithContentsOfFile:thePath encoding:NSUTF8StringEncoding error:NULL];
    
	NSArray *theContentList = [content componentsSeparatedByString:@"\n"];
    
    DDLogWarn(@"content swccc = %@",theContentList);
    DeviceInfos* info = [DeviceInfos shareDeviceInfos];
    NSLog(@"%d",(int)_comboBox.indexOfSelectedItem);
    
    if(self.arrConnectionItemList != nil){
        self.arrConnectionItemList = nil;
    }
    
    self.arrConnectionItemList = [NSMutableArray arrayWithCapacity:20];
    
    
    for(NSString* item in theContentList){
//        NSLog(@"item = %@",item);
        NSArray *theItemList = [item componentsSeparatedByString:@"|-|"];
        NSString *deviceNo = [theItemList objectAtIndex:0];
        NSString *deviceUdid = [theItemList objectAtIndex:1];
        NSString *deviceRatio = [theItemList objectAtIndex:2];
        
        NSMutableDictionary* dic = [[NSMutableDictionary alloc ] init];
        [dic setObject:deviceNo forKey:DEVICENO];
        [dic setObject:deviceUdid forKey:DEVICEUDID];
        [dic setObject:deviceRatio forKey:DEVICERATIO];
//        [dic setObject:[info buildWDAResult:deviceUdid] forKey:DEVICEBUILD];
        

        ConnectionItemInfo *theConnectionItemInfo = [[ConnectionItemInfo alloc] init];
//        theConnectionItemInfo.agentBuild = [info buildWDAResult:deviceUdid];
        
        DeviceInfos * deviceInfo = [[DeviceInfos alloc] init];
        deviceInfo.deviceNo = [deviceNo intValue];
        deviceInfo.udid = deviceUdid;
        deviceInfo.ratio = deviceRatio.floatValue;
//        deviceInfo.buildVersion = [info buildWDAResult:deviceUdid];
        
        
        theConnectionItemInfo.deviceInfos = deviceInfo;
        [theConnectionItemInfo initialize];
        [theConnectionItemInfo registerFileNotificationWithSuccess:[NSString stringWithFormat:@"FAIL_FILEDOWN_%@",deviceNo] andFailed:[NSString stringWithFormat:@"SUCCESS_FILEDOWN_%@",deviceNo]];

        [theConnectionItemInfo initUSBConnect];
        [info.arrayDeivce addObject:dic];
        
        NSMutableDictionary * dicItem =
        [NSMutableDictionary dictionaryWithObjectsAndKeys:
         [NSNumber numberWithInt:[deviceNo intValue]], KEY_INDEX,
         deviceUdid, KEY_UDID,
         theConnectionItemInfo, KEY_OBJECT, nil];
        
        NSLog(@"dicItem(%@(%d)) = %@",KEY_INDEX,[deviceNo intValue],dicItem);
        [self.arrConnectionItemList addObject:dicItem];
    }
    
    
    
    
    
//	for (NSString *theItemInfo in theContentList) {
//
//		NSArray *theItemList = [theItemInfo componentsSeparatedByString:@"|-|"];
//        NSString *deviceNo = [theItemList objectAtIndex:0];
//        NSString *deviceUdid = [theItemList objectAtIndex:1];
//        NSString *deviceRatio = [theItemList objectAtIndex:2];
//
//        NSMutableDictionary* dic = [[NSMutableDictionary alloc ] init];
//        [dic setObject:deviceNo forKey:DEVICENO];
//        [dic setObject:deviceUdid forKey:DEVICEUDID];
//        [dic setObject:deviceRatio forKey:DEVICERATIO];
//        [dic setObject:[info buildWDAResult:deviceUdid] forKey:DEVICEBUILD];
//
//        [info.arrayDeivce addObject:dic];
//
//
//        ConnectionItemInfo *theConnectionItemInfo = [[ConnectionItemInfo alloc] init];
//        CommunicatorWithDC *theSharedDCInterface = [CommunicatorWithDC sharedDCInterface];
//        theConnectionItemInfo.agentBuild = [info buildWDAResult:deviceUdid];
//        theConnectionItemInfo.deviceInfos = info;
//        [theConnectionItemInfo initialize];                     // ControlAgent 객체가 생성된뒤 Tokens 를 넣어야 한다.
//
//        theConnectionItemInfo.dicKorTokens = _dicKorTokens;
//    //        [theConnectionItemInfo registerFileNotificationWithSuccess:[NSString stringWithFormat:@"FAIL_FILEDOWN_%@",theDeviceId] andFailed:[NSString stringWithFormat:@"SUCCESS_FILEDOWN_%@",theDeviceId]];
//        [theConnectionItemInfo clearProcess:deviceUdid];           // 전에 실행했던 프로세스가 남아있는지 확인하여 정리한다.
//        [theConnectionItemInfo initUSBConnect];         // DeviceInfo 정보가 들어가 있는 상태에서 호출해야 함.
//        [theConnectionItemInfo startDetachTimer];       // 남아있는 정보가 실재로 사용가능한 정보인지 확인함..
//
//        NSMutableDictionary * dicItem = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:deviceInfo.deviceNo], KEY_INDEX, deviceInfo.udid, KEY_UDID, theConnectionItemInfo, KEY_OBJECT, nil];
//
//    //        [self.myConnectionItemList setObject:theConnectionItemInfo forKey:theDeviceId];
//        [self.arrConnectionItemList addObject:dicItem];
//    }
}

- (void) initConnectionItemList {
    /*  // 기존의 정보를 가져오진 않는다.. 실행하면.. 무조건 첫번째로 Attach 되는 Device 를 사용한다.  요구사항이 변경됨.
    NSArray * deviceInfos = [[NSUserDefaults standardUserDefaults] objectForKey:DeviceInfo];
    for( DeviceInfos * deviceInfo in deviceInfos ) {
        ConnectionItemInfo * itemInfo = [[ConnectionItemInfo alloc] init];
        itemInfo.deviceInfos = deviceInfo;
        itemInfo.dicKorTokens = _dicKorTokens;
        [itemInfo registerFileNotificationWithSuccess:[NSString stringWithFormat:@"FAIL_FILEDOWN_%d", deviceInfo.deviceNo] andFailed:[NSString stringWithFormat:@"SUCCESS_FILEDOWN_%d", deviceInfo.deviceNo]];
        
        [itemInfo clearProcess];                        // 전에 실행했던 프로세스가 남아있는지 확인하여 정리한다.
        [itemInfo initUSBConnect];                      // DeviceInfo 정보가 들어가 있는 상태에서 호출해야 함.
        [itemInfo startDetachTimer];                    // 남아있는 정보가 실재로 사용가능한 정보인지 확인함..
        
        NSDictionary * dicItem = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:deviceInfo.deviceNo], @"index", deviceInfo.udid, @"udid", itemInfo, @"object", nil];
        [_arrConnectionItemList addObject:dicItem];
        
        [_arrDeviceUsedList replaceObjectAtIndex:deviceInfo.deviceNo withObject:[NSNumber numberWithBool:YES]];
        
        _deviceInfoMode = INFO_DEVICE_CHANGE;
    }
    */
//    if( _deviceInfoMode != INFO_DEVICE_CHANGE )
//        _deviceInfoMode = INFO_DEVICE_LIST;
}

-(BOOL)connectCheckDevice{
    
    NSString * output = [Utility launchTaskFromSh:[NSString stringWithFormat:@"idevice_id -l | grep %@", @"5099243099b114d9b73eddf078020adc674c1a46"]];
    NSLog(@"output = %@",output);
    if(output.length == 0){
        NSLog(@"NO");
        return NO;
    }
    NSLog(@"YES");
    return YES;
}

/// @brief 지금은 사용하지 않음..
- (int) getDeviceCount {
    int nCount = 0;
    NSString * result = [Utility launchTask:@"/usr/local/bin/idevice_id" arguments:@[@"-l"]];
    
    if( 0 == result.length )
        return nCount;
    
    NSArray * datas = [result componentsSeparatedByString:@"\n"];
    for( NSString * keyValue in datas ) {
        if( 0 == keyValue.length )
            continue;
        
        ++nCount;
    }
    
    return nCount;
}


// Slot번호|UDID|빌드정보|화면비율
- (void)deviceInfoList{
    
    NSError* error = nil;
    NSString* path = [NSString stringWithFormat:@"%@/%@",[Utility ManualDirectory],MAPPINGFILE];
    NSString* content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    DeviceInfos* info = [DeviceInfos shareDeviceInfos];
    
    if(error != nil){
        NSLog(@"%@",error.description);
    }else{
        NSArray* contentList = [content componentsSeparatedByString:@"\n"];
        for(NSString* item in contentList){
            NSArray* itemList = [item componentsSeparatedByString:@"|-|"];
            NSString *deviceNo = [itemList objectAtIndex:0];
            NSString *deviceUdid = [itemList objectAtIndex:1];
            NSString *deviceRatio = [itemList objectAtIndex:2];

            NSMutableDictionary* dic = [[NSMutableDictionary alloc ] init];
            [dic setObject:deviceNo forKey:DEVICENO];
            [dic setObject:deviceUdid forKey:DEVICEUDID];
            [dic setObject:deviceRatio forKey:DEVICERATIO];
//            [dic setObject:[info buildWDAResult:deviceUdid] forKey:DEVICEBUILD];
            
            [info.arrayDeivce addObject:dic];
        }
        NSLog(@"info = %@",info.arrayDeivce);
    }
    ConnectionItemInfo *theConnectionItemInfo = [[ConnectionItemInfo alloc] init];
//    [theConnectionItemInfo initUSBConnect];         // DeviceInfo 정보가 들어가 있는 상태에서 호출해야 함.
//    [theConnectionItemInfo clearProcess];
}

/// @brief 서버 소켓을 생성하여 DC 와의 연결을 기다린다.
- (void)startSocketServer:(int)deviceCount {
	CommunicatorWithDC *theSharedDCInterface = [CommunicatorWithDC sharedDCInterface];
	theSharedDCInterface.mainController = self;
    theSharedDCInterface.devUdid = deviceUdid;    
    
    BOOL bDCSetting = [theSharedDCInterface startInterfaceWithDC];
    if(!bDCSetting){
        dispatch_async(dispatch_get_main_queue(), ^{
            sleep(10);
            [self performSelectorOnMainThread:@selector(appliyPort:) withObject:nil waitUntilDone:NO];
        });
    }
}

- (ConnectionItemInfo *)firstConnectionItemInfo {
    if( ![_arrConnectionItemList count] )
        return nil;
    
    NSDictionary * dicFirstItem = [_arrConnectionItemList firstObject];
    return [dicFirstItem objectForKey:KEY_OBJECT];
}

- (ConnectionItemInfo* )connectionItemInfoByDeviceNo:(int)argDeviceNo{
    
//    NSString * temp = [NSString stringWithFormat:@"%@ == %d", KEY_INDEX, argDeviceNo];
//    NSDictionary* dictTemp = [_arrConnectionItemList objectAtIndex:argDeviceNo];
//    NSString* index = [dictTemp objectForKey:KEY_INDEX];
//    ConnectionItemInfo* itemInfo = nil;
//    itemInfo = [dictTemp objectForKey:KEY_OBJECT];
    
    NSString * temp = [NSString stringWithFormat:@"%@ = %d", KEY_INDEX, argDeviceNo];
    NSPredicate * predicate = [NSPredicate predicateWithFormat:temp];
    NSArray * results = [_arrConnectionItemList filteredArrayUsingPredicate:predicate];
//
    ConnectionItemInfo * itemInfo = nil;
    if( results && [results count] ) {
        NSDictionary * dicItem = [results objectAtIndex:0];
        itemInfo = [dicItem objectForKey:KEY_OBJECT];
    }

    return itemInfo;
}

- (NSString *)udidByDeviceNo:(int)argDeviceNo {
    NSString * temp = [NSString stringWithFormat:@"%@ == %d", KEY_INDEX, argDeviceNo];
    NSPredicate * predicate = [NSPredicate predicateWithFormat:temp];
    NSArray * results = [_arrConnectionItemList filteredArrayUsingPredicate:predicate];
    
    NSString * udid = nil;
    if( results && [results count] ) {
        NSDictionary * dicItem = [results objectAtIndex:0];
        udid = [dicItem objectForKey:KEY_UDID];
    }
    
    return udid;
}



/// @brief  ipa 파일에서 BundleId 를 얻어온다.
- (NSString*) getBundleID:(NSString*)path
{
    //CFBundleExecutable
    NSString* commandString = [NSString stringWithFormat:@"cd \"%@\" ; unzip -q \"%@/install.ipa\" -d temp ; APP_NAME=$(ls temp/Payload/) ; /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \"%@/temp/Payload/$APP_NAME/Info.plist\" ; rm -rf temp",
                               [Utility managerDirectory],
                               [Utility managerDirectory],
                               [Utility managerDirectory]];
    
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
//    NSLog(@"PATH = %@",commandString);
    //mg
//    [iTask launch];
//    [iTask waitUntilExit];
//    mg//s
    if( [NSThread isMainThread] ) {
        @autoreleasepool {
            [iTask launch];
            [iTask waitUntilExit];
        }
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            @autoreleasepool {
//                [iTask launch];
//                [iTask waitUntilExit];
                NSError* error = nil;
                if (@available(macOS 10.13, *)) {
                    BOOL bSuccess = [iTask launchAndReturnError:&error];
                    if(bSuccess){
                        NSLog(@"성공");
                    }else{
                        NSLog(@"실패");
                    }
                    if(error){
                        NSLog(@"%s %@",__FUNCTION__,error.description);
                    }
                }else{
                    [iTask launch];
                    [iTask waitUntilExit];
                }
            }
        });
    }
//    NSError* error;
//    if (@available(macOS 10.13, *)) {
//        BOOL bSuccess = [iTask launchAndReturnError:&error];
//        if(bSuccess){
//            NSLog(@"성공");
//        }else{
//            NSLog(@"실패");
//        }
//        if(error){
//            NSLog(@"%s %@",__FUNCTION__,error.description);
//        }
//    }else{
//        [iTask launch];
//        [iTask waitUntilExit];
//    }

    //mg//e
    NSData *data = [file readDataToEndOfFile];
    if(data == nil){
        return nil;
    }else{
        output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
        if(output == nil || output.length == 0){
            return nil;
        }
    }
    
    
    [file closeFile];
    
    output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSRange the_range = [output rangeOfString:@"Exist" options:NSCaseInsensitiveSearch];
    if (the_range.location != NSNotFound) {
        DDLogError(@"BundleID not found:%@", output);
        DDLogError(@"Use old method");
        output = nil;
    }
    else {
        DDLogWarn(@"BundleID = %@", output);
    }
    
    return output;
}


- (IBAction)ResetAll:(id)sender {

    DDLogWarn(@"test");
//    NSString* temp = [Utility cpuHardwareName];
//    NSLog(@"hardware = %@",temp);

//    NSString *path = [[NSBundle mainBundle] executablePath];
////
////    NSLog(@"path = %@",path);
////    NSString *mgr = [NSString stringWithFormat:@"%@Manager2.app", [Utility managerDirectory]];
////    NSLog(@"path = %@",mgr);
////    [[NSWorkspace sharedWorkspace] launchApplication:mgr];
////    exit(0);
////    NSTask * restartTask = [[NSTask alloc] init];
////    restartTask.launchPath = path;
////    [restartTask launch];
////
////    [[NSApplication sharedApplication] terminate:nil];
//    NSArray * array =
//    array = [NSArray arrayWithObjects: @"one", @"two", @"three", @"four", nil];
//
//    [array objectAtIndex:8];
//    [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:];
//    NSHTTPCookie *cookie;
//
//    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
//
//    for (cookie in [storage cookies]) {
//        NSLog(@"1");
//        [storage deleteCookie:cookie];
//
//    }
//    NSString * output = [Utility launchTaskFromBash:[NSString stringWithFormat:@"ps -ef | grep %@", @"lsof"]];
//    NSLog(@"output = %@",output);
//    if(output.length > 0){
//        output = [output stringByReplacingOccurrencesOfString:@"\r" withString:@""];
//        NSArray* arrOut = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
//
//        NSMutableArray * arrPid = [NSMutableArray array];
//        for( NSString * outputProcessInfos in arrOut ) {
//            if( 0 == outputProcessInfos.length )
//                continue;
//
//            if( [outputProcessInfos containsString:@"grep "] ) {
//                continue;
//            }
//
//            NSArray * component = [outputProcessInfos componentsSeparatedByString:@" "];
////            NSLog(@"compoment = %@",component);
//
//            NSMutableArray* tempArray = [NSMutableArray array];
//            for(NSString* temp in component){
//                if(temp.length > 0){
//                    [tempArray addObject:temp];
//                }else{
//                }
//            }
////            NSLog(@"tempArray = %@",tempArray);
//
//            if((int)tempArray.count > 3){
//                NSString* strPid = [tempArray objectAtIndex:2];
//                NSLog(@"strPid = %@",strPid);
//                if([strPid isEqualToString:@"1"]){
//                    strPid = [tempArray objectAtIndex:1];
//                }
//                NSString * command = [NSString stringWithFormat:@"kill -9 %@", strPid];
//                int result = system([command cStringUsingEncoding:NSUTF8StringEncoding]);
//                DDLogWarn(@"Kill Process Result : %d", result);
//            }
//        }
//    }
}

-(void) restartManager2 {
    DDLogDebug(@"1%s", __FUNCTION__);
    
    //    NSString *mgr = [NSString stringWithFormat:@"%@Manager.app", [Utility managerDirectory]];
    //    [[NSWorkspace sharedWorkspace] launchApplication:mgr];
    //    exit(0);
    DDLogInfo(@"%s", __FUNCTION__);
    
    NSString *path = [[NSBundle mainBundle] executablePath];
    
    NSLog(@"path = %@",path);
    
    NSTask * restartTask = [[NSTask alloc] init];
    restartTask.launchPath = path;
    [restartTask launch];
    
    [[NSApplication sharedApplication] terminate:nil];
}

- (IBAction)restartDevice:(id)sender
{
    NSString* temp = [Utility cpuHardwareName];
    NSLog(@"hardware = %@ %@",temp,deviceUdid);
    
//    [self connectCheckDevice];
    

    NSString * commandString = [NSString stringWithFormat:@"idevicediagnostics -u %@ restart",deviceUdid];

    NSTask * launchTask = [[NSTask alloc] init];
    launchTask.launchPath = @"/bin/bash";
    launchTask.arguments = @[@"-l", @"-c", commandString];

    NSPipe * outputPipe = [[NSPipe alloc] init];
    [launchTask setStandardOutput:outputPipe];
    NSFileHandle * outputHandle = [outputPipe fileHandleForReading];

    if( [NSThread isMainThread] ) {
        [launchTask launch];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [launchTask launch];
        });
    }
}


-(void)killManagePort:(int)port{
    @try
    {
        NSString *script = [NSString stringWithFormat:@"kill `lsof -t -i:%d`", port];
        system([script UTF8String]);
        system([@"killall -z lsof" UTF8String]);
    }
    @catch (NSException *exception)
    {
        NSLog(@"########################################################################");
        NSLog(@"%@", exception.description);
        NSLog(@"########################################################################");
    }

}


- (IBAction)getPageSourceByXml:(id)sender {
    /*
    ConnectionItemInfo* itemInfo = [self connectionItemInfoByDeviceNo:1];      //
    
    
    NSString * pageXml = [itemInfo getPageSouece];
    
    DDLogInfo(@"######################## \n\n\n%@\n\n\n ###########################", pageXml);
     */
    
    
//    dispatch_queue_t    tempQueue = dispatch_queue_create(@"testQueu", NULL);
    dispatch_queue_t    tempQueue = nil;
    dispatch_async(tempQueue, ^{
        NSLog(@"Fire");
    });
}


-(IBAction)removeDeviceLog:(id)sender
{
    [self showAlertOfKind:NSWarningAlertStyle WithTitle:@"로그삭제" AndMessage:@"해당 로그를 삭제 하시겠습니까?"];
}


//not used
- (void)killProcess {
    for( NSDictionary * dicItem in _arrConnectionItemList ) {
        DDLogWarn(@"========kill ====");
        ConnectionItemInfo * itemInfo = [dicItem objectForKey:KEY_OBJECT];
        [itemInfo stopAgent];
    }
}

#define FONT_SIZE 15
#define FONT_HELVETICA @"Helvetica-Light"
#define BLACK_SHADOW [NSColor colorWithRed:40.0f/255.0f green:40.0f/255.0f blue:40.0f/255.0f alpha:0.4f]

// mode = 0 흰색, mode = 1 빨강색 mode = 2 노란색 mode = 3 파란색

- (void)appendStringValue:(NSString*)string mode:(int)nMode type:(int)nType
{
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentLeft;
//    paragraphStyle.lineSpacing = FONT_SIZE/2;
    NSFont * labelFont = [NSFont fontWithName:FONT_HELVETICA size:FONT_SIZE];
    if(nType == TYPE_MANAGER){
        labelFont = [NSFont fontWithName:FONT_HELVETICA size:8];
    }
//    NSColor * labelColor = [NSColor colorWithWhite:1 alpha:1];
    NSColor* labelColor;
    if(nMode == 0){
        labelColor = [NSColor whiteColor];//verbose
    }else if(nMode == 1){
        labelColor = [NSColor redColor];//error
    }else if(nMode == 2){
        labelColor = [NSColor yellowColor];//warning
    }else if(nMode == 3){
        labelColor = [NSColor lightGrayColor];//mg//글씨가 잘 안보여서 수정//blueColor];//info
    }
    
    //mg//debug용 추가
    else if(nMode == 4){
        labelColor = [NSColor cyanColor];
    }
    
    NSShadow *shadow = [[NSShadow alloc] init];
    [shadow setShadowColor : BLACK_SHADOW];
    [shadow setShadowOffset : CGSizeMake (1.0, 1.0)];
    [shadow setShadowBlurRadius : 1];
    
    NSAttributedString* stringToAppend = [[NSAttributedString alloc] initWithString:string attributes:@{
                                                                                                        NSParagraphStyleAttributeName : paragraphStyle,
                                                                                                        NSKernAttributeName : @2.0,
                                                                                                        NSFontAttributeName : labelFont,
                                                                                                        NSForegroundColorAttributeName : labelColor,
                                                                                                        NSShadowAttributeName : shadow }];


    dispatch_async(dispatch_get_main_queue(), ^{
        if(nType == 0){
        }else if(nType == 1){
        }else if(nType == 2){
            [[self.txtManagerView textStorage] appendAttributedString:stringToAppend];
            NSPoint bottom = NSMakePoint(0.0, NSMaxY([[self.managerField documentView] frame]) - NSHeight([[self.managerField contentView] bounds]));
            [[self.managerField documentView] scrollPoint:bottom];
        }
    });
    // sc
    // scrolls to the bottom
}//appendStringValue

- (void) saveCoSTEPMappingFile:(DeviceInfos *)deviceInfo {
// DeviceNo |-|   UDID   |-| devicename |-| device version |-| appium port |-| device ratio |-| ios-webkit port
//   8      |-|udid123abh|-|  version   |-|     9,3,2      |-|    4730     |-|       2      |-| 27760
    
    dispatch_queue_t fileQueue = dispatch_queue_create("FileQueue", NULL);
    dispatch_async(fileQueue, ^{
        NSMutableArray * arrTemp = [[NSMutableArray alloc] init];
        [arrTemp addObject:[NSNumber numberWithInt:deviceInfo.deviceNo]];
        [arrTemp addObject:deviceInfo.udid];
        [arrTemp addObject:deviceInfo.deviceName];
        [arrTemp addObject:deviceInfo.productVersion];
        [arrTemp addObject:[NSNumber numberWithInt:DEFAULT_APPIUM_PORT]];
        [arrTemp addObject:[NSNumber numberWithFloat:(float)deviceInfo.ratio]];
        [arrTemp addObject:[NSNumber numberWithInt:DEFAULT_WEBKIT_PORT]];
        
        NSString * strMappingInfo = [arrTemp componentsJoinedByString:@"|-|"];
        
        NSString * managerDir = [Utility managerDirectory];
        NSString * strCoSTEPMappingFile = [managerDir stringByAppendingPathComponent:[NSString stringWithFormat:@"../%@", MAPPINGFILE]];
        
        
        DDLogWarn(@"name Path : %@", strCoSTEPMappingFile);
        NSFileManager * fileManager = [NSFileManager defaultManager] ;
        NSError *error = nil;
        
        if (![fileManager fileExistsAtPath:strCoSTEPMappingFile]) {
            if( ![fileManager createFileAtPath:strCoSTEPMappingFile contents:nil attributes:nil] ) {
                DDLogError(@"로그 파일 생성 실패 !!");
            }
        } else {
            if( ![@"" writeToFile:strCoSTEPMappingFile atomically:YES encoding:NSUTF8StringEncoding error:&error] ) {
                DDLogError(@"로그 파일 초기화 실패 !!");
            }
        }
        NSFileHandle * fileHandle = [NSFileHandle fileHandleForWritingAtPath:strCoSTEPMappingFile];
        
//        dispatch_async(dispatch_get_main_queue(), ^{
            [fileHandle truncateFileAtOffset:[fileHandle seekToEndOfFile]];
            [fileHandle writeData:[strMappingInfo dataUsingEncoding:NSUTF8StringEncoding]];
            [fileHandle synchronizeFile];
            [fileHandle closeFile];
//        });
    });
}

#pragma mark - NSTableView DataSource
//## NSTableView DataSource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return 0;
}


- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSTableCellView *result = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
//    Item *item = [self.items objectAtIndex:row];
//    result.imageView.image = item.itemIcon;
//    result.textField.stringValue = item.itemDisplayName;
    
//    NSDictionary* dict;
    
//    dict = [_arrayLog objectAtIndex:row];
//    if([tableColumn.title isEqualToString:@"Time"]){
//        result.textField.stringValue = [dict objectForKey:@"DATE"];
//        result.textField.textColor = [NSColor blueColor];
//    } else if([tableColumn.title isEqualToString:@"Process"]){
//        result.textField.stringValue = [dict objectForKey:@"PROCESS"];
//    } else if([tableColumn.title isEqualToString:@"Type"]){
//        result.textField.stringValue = [dict objectForKey:@"TAG"];
//        result.textField.textColor = [NSColor redColor];
//    } else if([tableColumn.title isEqualToString:@"Log"]){
//        result.textField.stringValue = [dict objectForKey:@"LOG"];
////        [self appendStringValue:[dict objectForKey:@"LOG"]];
//    }
    
    return result;
}


- (nullable NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    return nil;
}

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
}

- (void)tableView:(NSTableView *)tableView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
    
}

#pragma mark - <ConnectionItemInfoDelegate>
- (void) didCompletedGetDeviceInfos:(NSString *)udid {
    if( 0 == [_arrConnectionItemList count] ) {
        DDLogError(@"%s -- 데이터가 없음.", __FUNCTION__);
        return ;
    }
    
    NSDictionary * dicItem = [_arrConnectionItemList firstObject];
    NSString * objectUDID = [dicItem objectForKey:KEY_UDID];
    
    if( [objectUDID isEqualToString:udid] ) {       // 첫번째 아이폰에 대한 정보를 가져왔으면, DC 에 Device Change(추가) 값을 보내준다.
        
        ConnectionItemInfo * itemInfo = [dicItem objectForKey:KEY_OBJECT];
        
        CommunicatorWithDC *theSharedDCInterface = [CommunicatorWithDC sharedDCInterface];
        [theSharedDCInterface sendDeviceChange:1 withInfo:itemInfo.deviceInfos andDeviceNo:itemInfo.deviceInfos.deviceNo];
        
        [self saveCoSTEPMappingFile:itemInfo.deviceInfos];
    }
}

- (void) didCompletedDetachDevice:(NSNumber *)usbNumber {
#ifdef VER_STANDALONE
    if( 0 == [_arrConnectionItemList count] ) {
        DDLogError(@"%s -- 데이터가 없음.", __FUNCTION__);
        return ;
    }
    
    NSString * temp = [NSString stringWithFormat:@"%@ == %d", KEY_USBNUMBER, usbNumber.intValue];
    NSPredicate * predicate = [NSPredicate predicateWithFormat:temp];
    NSArray * result = [_arrConnectionItemList filteredArrayUsingPredicate:predicate];
    if( result && [result count] ) {                // 디바이스 정보를 삭제 한후 DC 에 Device Change(삭제) 값을 보내준다.
        NSDictionary * dicItem = [result objectAtIndex:0];
        
        ConnectionItemInfo * itemInfo = [dicItem objectForKey:KEY_OBJECT];
        
        NSDictionary * dicFirstItem = [_arrConnectionItemList firstObject];
        [_arrConnectionItemList removeObject:dicItem];
        [_arrDeviceUsedList replaceObjectAtIndex:itemInfo.deviceInfos.deviceNo withObject:[NSNumber numberWithBool:NO]];
        
        
        NSString * firstObjectUDID = [dicFirstItem objectForKey:KEY_UDID];
        if( [firstObjectUDID isEqualToString:itemInfo.deviceInfos.udid] ) {
            CommunicatorWithDC *theSharedDCInterface = [CommunicatorWithDC sharedDCInterface];
            [theSharedDCInterface sendDeviceChange:0 withInfo:itemInfo.deviceInfos andDeviceNo:itemInfo.deviceInfos.deviceNo];
            
            if( [_arrConnectionItemList count] ) {  // 아직 리스트에 디바이스가 존재함..
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    NSDictionary * newFirstItem = [_arrConnectionItemList firstObject];
                    [self didCompletedGetDeviceInfos:[newFirstItem objectForKey:KEY_UDID]];
                });
            }
        }
        
        [itemInfo resetAppium];
    }
#endif
}

#pragma mark - Alert Methods

- (void)showAlertOfKind:(NSAlertStyle)style WithTitle:(NSString *)title AndMessage:(NSString *)message
{
}

#pragma mark - <Timer Delegate>
- (void) onClearLogTimer:(NSTimer *)theTimer {
}

-(IBAction)appliyPort:(id)sender{

    NSLog(@"%s -- %d",__FUNCTION__,(int)self.comboBox.indexOfSelectedItem);
    [self showProgressStart:YES];
    int nIndex = (int)self.comboBox.indexOfSelectedItem;
    int nValue = [self.comboBox intValue];
    
    ConnectionItemInfo* itemInfo = [self connectionItemInfoByDeviceNo:nIndex+1];
    CommunicatorWithDC *theSharedDCInterface = [CommunicatorWithDC sharedDCInterface];
    if([theSharedDCInterface disconnectSocket]){
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(queue, ^{
            [self showProgressStart:YES];
            NSLog(@"==%@",itemInfo.deviceInfos.udid);
            deviceUdid = itemInfo.deviceInfos.udid;
            NSLog(@"udid = %@",deviceUdid);
            [itemInfo clearProcess:deviceUdid andLog:YES];
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSThread sleepForTimeInterval:5];
                [theSharedDCInterface connectSocket:nIndex andPort:(nValue-1)];
                [self showProgressStart:NO];
            });
        });
    }
}

-(IBAction)restartManager:(id)sender{
//    [Utility restartManager];
    [self getBundleID:@"test"];
}


#pragma mark - ComboBox Delegate

- (void)comboBoxSelectionIsChanging:(NSNotification *)notification
{
    nComboNumber = (int)self.comboBox.indexOfSelectedItem;
}

-(void)showProgressStart:(BOOL)bShow{
     if( [NSThread isMainThread] ) {
       if(bShow){
           [self.comboBox setEditable:NO];
           [self.boxBuildLoading setHidden:NO];
           [self.indicator startAnimation:nil];
       }else{
           [self.boxBuildLoading setHidden:YES];
           [self.indicator stopAnimation:nil];
           [self.comboBox setEditable:YES];
       }
     }else{
        dispatch_async(dispatch_get_main_queue(), ^{
            if(bShow){
                [self.comboBox setEditable:NO];
                [self.boxBuildLoading setHidden:NO];
                [self.indicator startAnimation:nil];
            }else{
                [self.boxBuildLoading setHidden:YES];
                [self.indicator stopAnimation:nil];
                [self.comboBox setEditable:YES];
            }
        });
     }
}



-(void)showLogField:(int)index
{

}

-(IBAction)clickRestart:(id)sender{
    NSLog(@"%d",(int)[self.btnRestartManager state]);
    BOOL boolValue = YES;
    if((int)[self.btnRestartManager state] == 0){
        boolValue = NO;
    }
    [[NSUserDefaults standardUserDefaults] setBool:boolValue forKey:MANAGERRESTART];
    [[NSUserDefaults standardUserDefaults] synchronize];

    
}

- (void) readData:(NSData *)readData withHandler:(id)handler {
    NSString *outStr = [[NSString alloc] initWithData:readData encoding:NSUTF8StringEncoding];
//    DDLogInfo(@"====== outStr===== %@", outStr);//manage

//    [self manageLog:outStr];
}

-(void)startDeviceLog:(NSString *)udid{
    
}

//-(void)logStart:(NSString *)udid
-(void)logStart:(NSString *)udid logSearch:(NSString *)search identifier:(NSString* )identifier level: (char)level
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        if(self.logTask != nil){
            self.logTask = nil;
        }
        self.logTask = [[NSTask alloc] init];
        
        NSString * commandString;
        if(identifier)
        commandString = [NSString stringWithFormat:@"idevicesyslog -u %@ -K", udid];
        
        
        self.logTask.launchPath = @"/bin/bash";
        self.logTask.arguments = @[@"-l", @"-c", commandString];
        
//        NSPipe* pipe = [NSPipe pipe];
        if(self.pipe != nil){
            self.pipe = nil;
        }
        self.pipe = [NSPipe pipe];
        [self.logTask setStandardOutput:self.pipe];
        
        
        [self.logTask launch];
        
        // BlockSelf 를 사용하면 setReadabilityHandler 안으로 들어가지 못함.. 왜 그런지는 확인해봐야 함..
        [[self.pipe fileHandleForReading] waitForDataInBackgroundAndNotify];
        self.pipeNotiObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleDataAvailableNotification object:[self.pipe fileHandleForReading] queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            
            DDLogVerbose(@"addObserverForName");

            [[self.pipe fileHandleForReading] setReadabilityHandler:^(NSFileHandle *file) {
                NSData * output = [file availableData];
                if( [self respondsToSelector:@selector(readData:withHandler:)] ) {
                    if(output.length > 0){
                        [self readData:output withHandler:self];
                        [[self.pipe fileHandleForReading] waitForDataInBackgroundAndNotify];
                    }else{
                        [[NSNotificationCenter defaultCenter] removeObserver:self.pipeNotiObserver];
                                                
                        [self.pipe removeObserver:self.pipeNotiObserver];
                        [self.pipe closeFile];
                        self.pipeNotiObserver = nil;
                        
                    }
                }
            }];
        }];
        
        [self.logTask setTerminationHandler:^(NSTask *task) {
            // do your stuff on completion
            __weak typeof(self) weakSelf = self;
            @try {
                [weakSelf.logTask.standardOutput fileHandleForReading].readabilityHandler = nil;
            } @catch (NSException *exception) {
                NSLog(@"standardOutput except = %@",exception.description);
            }

            @try {
                [weakSelf.logTask.standardError fileHandleForReading].readabilityHandler = nil;
            } @catch (NSException *exception) {
                NSLog(@"standardOutput except = %@",exception.description);
            }
        }];
    });
}

-(void)logStop{
    [[self.pipe fileHandleForReading] closeFile];
    
    for(int i = 0; i< 20; i++){
        [self.logTask terminate];
    }
    
//        sleep(2);
    
    [[NSNotificationCenter defaultCenter] removeObserver:NSFileHandleDataAvailableNotification];
    [[NSNotificationCenter defaultCenter] removeObserver:self.pipeNotiObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:NSFileHandleDataAvailableNotification name:nil object:[self.pipe fileHandleForReading]];
    self.pipeNotiObserver = nil;
    self.pipe = nil;
    self.logTask = nil;
}


-(IBAction)startDeviceList:(id)sender{
    if(_arrStartAppList != nil){
        _arrStartAppList = nil;
    }
    _arrStartAppList = [self deviceList];
    NSLog(@"%@",_arrStartAppList);
}

-(NSMutableArray *)deviceList{
    NSTask *task = [[NSTask alloc] init];
    NSString* cpu = [Utility cpuHardwareName];
    
    if([cpu isEqualToString:@"x86_64"]){
        [task setLaunchPath: @"/usr/local/bin/ios-deploy"];
        [task setArguments: [[NSArray alloc] initWithObjects:@"-i",@"00008110-000E4CA83E82801E" ,@"-B", nil]];
    }else{
        [task setLaunchPath: @"/opt/homebrew/bin/ios-deploy"];
        [task setArguments: [[NSArray alloc] initWithObjects:@"-i",@"00008110-000E4CA83E82801E" ,@"-B", nil]];
    }
    if(![[NSFileManager defaultManager] isExecutableFileAtPath:[task launchPath]] || [[NSWorkspace sharedWorkspace] isFilePackageAtPath:[task launchPath]]){
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

    __block NSError* error = nil;
    __block BOOL bTask = YES;

    bTask = [task launchAndReturnError:&error];
    [task waitUntilExit];

    if(error){
         DDLogError(@"DEVICE LIST ERROR = %@",error.description);
        return nil;
     }else{
         DDLogDebug(@"DEVICE LIST SUCCESS = %d",bTask);
         NSData *data = [file readDataToEndOfFile];
         NSString *output = [[NSString alloc] initWithData:data encoding: NSUTF8StringEncoding];
         [file closeFile];
         [task terminate];
         task = nil;

         NSArray* list = nil;
         list = [output componentsSeparatedByString:@"\n"];
         NSMutableArray * arrAppList = [[NSMutableArray alloc] init];
         if(list != nil) {
             for(NSString* appId in list) {
                 if([appId hasPrefix:@"Skipping"] == NO && [appId hasPrefix:@"[." ] == NO){
                     if(appId.length > 0 && ![appId containsString:@"com.apple"]){
                        [arrAppList addObject:appId];
                     }

                 }
             }

         }
         
         NSLog(@"arr app list = %@",arrAppList);
         return arrAppList;
     }
    
}

-(IBAction)endDeviceList:(id)sender{
    
    NSMutableArray* arrLastAppList = [self deviceList];
    NSLog(@"%@",arrLastAppList);
    for(NSString* bundleId in arrLastAppList){
        if([_arrStartAppList containsObject:bundleId]){
//            NSLog(@"앱이 있네용");
        }else{
            NSLog(@"앱이 없네용 %@",bundleId);
        }
    }
}

@end
