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
    
}

/// @brief  한글 토큰 RemoteKeyboard 사용시 입력받은 키보드의 문자로 한글 문자를 변환하기 위해 사용함.
@property (nonatomic, strong) NSMutableDictionary   * dicKorTokens;

/// ConnectionItemInfo 의 리스트
@property (nonatomic, strong) NSMutableArray        * arrConnectionItemList;

/// 사용안함.
@property (nonatomic, strong) dispatch_queue_t      listenQueue;

/// 사용안함.
@property (nonatomic, strong) dispatch_semaphore_t  listenSem;

/// UI에 출력중인 로그정보를 일정 시간단위로 삭제하기 위해 서용하는 타이머
@property (nonatomic, strong) NSTimer               * clearLogTimer;

#ifdef VER_STANDALONE
///사용하지 않음.
@property (nonatomic, strong) NSMutableArray        * arrDeviceUsedList;
//@property (nonatomic, assign) DEVICE_INFO           deviceInfoMode;
#endif

/// AgentInfo.txt 파일에서 읽어 저장하는 변수이며, WebDriverAgent, Instruments, Appium 중 한가지를 선택해서 사용하도록 한다.
/// 멀티 연결되도록 수정이 된다면... 위의 정보를 ConnectionItemInfo 객체 개별적으로 사용할 수 있도록 해야 한다. (Device 마다 설정정보가 다를수 있으므로..)
@property (nonatomic, strong) NSDictionary          * dicAgentInfos;

@property (weak) IBOutlet NSTextField* tfUdid;
@property (weak) IBOutlet NSTextField* tfName;
@property (weak) IBOutlet NSTextField* tfVersion;
@property (weak) IBOutlet NSTextField* tfPort;
@property (weak) IBOutlet NSTextField* tfRatio;
@property (weak) IBOutlet NSTextField* tfProxy;

@property (weak) IBOutlet NSScrollView *scrAppLog;

@property (assign) IBOutlet NSTextField *tfLogInfo;
//DeviecLog창
@property (weak) IBOutlet NSScrollView *statusField;
@property (assign) IBOutlet NSTextView *txtView;
//AppiumLog창
@property (weak) IBOutlet NSScrollView *appumField;
@property (assign) IBOutlet NSTextView *txtAppiumView;
//Manager창
@property (weak) IBOutlet NSScrollView *managerField;
@property (assign) IBOutlet NSTextView *txtManagerView;

@property (weak) IBOutlet NSButton *btnRemoveLog;

@property (weak) IBOutlet NSTextField *tfAppLog;
@property (weak) IBOutlet NSButton *btnExpandAppLog;

@property (weak) IBOutlet NSComboBox *cmbLog;

//DCLog
@property (assign) IBOutlet NSTextView *txtDC;
@property (weak) IBOutlet NSScrollView *dcField;

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
    
    [self.view setAutoresizesSubviews:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceConnect:) name:DEVICE_CONNECT object:nil];

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
    
    [self makeSubView];
    
    [self makeTokens];
    
    _dicAgentInfos = [self getAgentInfos];
    
#ifdef VER_STANDALONE
    [self initConnectionItemList];
#else
    [self __getMappingTableFromFileName:MAPPINGFILE];
#endif
    
//    int nDeviceCount = [self getDeviceCount];
//    DDLogInfo(@"Connected USB Device count : %d", nDeviceCount);
    [self startSocketServer:0];
    

    [self initDeviceInfo];
    
    // 12시간 단위로 로그를 초기화 한다.
    _clearLogTimer = [NSTimer scheduledTimerWithTimeInterval:(12 * 60 * 60) target:self selector:@selector(onClearLogTimer:) userInfo:nil repeats:YES];
//    _clearLogTimer = [NSTimer scheduledTimerWithTimeInterval:(10 * 60) target:self selector:@selector(onClearLogTimer:) userInfo:nil repeats:YES];
        
    //mg//불필요한 로그 삭제
/*    DDLogError(@"Error");
    DDLogWarn(@"Warn");
    DDLogInfo(@"Info");
    DDLogVerbose(@"Verbose");
    DDLogError(@"DD Error");
    DDLogWarn(@"Warn");
    DDLogInfo(@"Info");
    DDLogVerbose(@"Verbose");
    DDLogError(@"DD Error");
    DDLogWarn(@"Warn");
    DDLogInfo(@"Info");
    DDLogVerbose(@"Verbose");
    DDLogError(@"DD Error");
    DDLogWarn(@"Warn");
    DDLogInfo(@"Info");
    DDLogVerbose(@"Verbose");
*/
    DDLogInfo(@"LOG_LEVEL_DEF = %d",LOG_LEVEL_DEF);
    DDLogInfo(@"LOG_LEVEL_VERBOSE = %d",(int)LOG_LEVEL_VERBOSE);

    //
//    DDLogInfo(@"마이로그 %@ and %@",@"에러",@"경고");
//    DDLogInfo(@"헤이");
//    
//    DDLogError(@"에러 로그");
//    
//    DDLogWarn(@"경고 로그");
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

-(void)makeSubView{
//    [self.statusField setBackgroundColor:[NSColor redColor]];

    [[self.txtView textStorage] setFont:[NSFont fontWithName:@"Menlo" size:15]];
    

    
    [self.statusField.documentView setTextColor:[NSColor whiteColor]];
    [self.statusField.documentView setBackgroundColor:[NSColor blackColor]];

    [self.appumField.documentView setTextColor:[NSColor whiteColor]];
    [self.appumField.documentView setBackgroundColor:[NSColor blackColor]];

    [self.managerField.documentView setTextColor:[NSColor whiteColor]];
    [self.managerField.documentView setBackgroundColor:[NSColor blackColor]];

    
    [self.btnRemoveLog setImage:[NSImage imageNamed:@"header_icon_delete_n"]];
    [self.btnRemoveLog setBordered:NO];
    
    //초기화면 Manager로그로 설정
    [self.cmbLog selectItemAtIndex:2];//0//mg//device log가 기본으로 표시돼서, manager log로 변경
    [self showLogField:2];//0//mg//device log가 기본으로 표시돼서, manager log로 변경
}

-(void)initDeviceInfo{
    [self.tfUdid setStringValue:@"입력된 값이 없습니다."];
    [self.tfName setStringValue:@"입력된 값이 없습니다."];
    [self.tfVersion setStringValue:@"입력된 값이 없습니다."];
    [self.tfPort setStringValue:@"입력된 값이 없습니다."];
    [self.tfRatio setStringValue:@"입력된 값이 없습니다."];
    [self.tfProxy setStringValue:@"입력된 값이 없습니다."];
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
    [self performSelectorOnMainThread:@selector(saveLogData:)
                           withObject:msg
                        waitUntilDone:YES];
}

/// @brief 예외 발생시 로그 파일 저장
-(void)saveLogData:(id)logData{
    const NSString* directory = [NSString stringWithFormat:@"%@/LOG", [Utility managerDirectory]];
    if(![[NSFileManager defaultManager] fileExistsAtPath:(NSString *)directory]){
        //mg//[self createDirectory:@"LOG" atFilePath:(NSString *)directory];
        [self createDirectory:@"LOG" atFilePath:[Utility managerDirectory]];//mg//
    }
    
//    NSDateFormatter *date = [[NSDateFormatter alloc] init];
//    [date setDateFormat:@"yyMMdd"];
    
//    NSString* dateDir = [NSString stringWithFormat:@"%@/LOG/%@",managerDirectory(),[date stringFromDate:[NSDate date]]];
//    if(![[NSFileManager defaultManager] fileExistsAtPath:dateDir]){
//        [self createDirectory:[date stringFromDate:[NSDate date]] atFilePath:directory];
//    }
    
//    NSString* path = [NSString stringWithFormat:@"%@/LOG/%@/%@.manaul.log.txt",managerDirectory(),[date stringFromDate:[NSDate date]],[dateToday stringFromDate:[NSDate date]]];
    NSString* path = [NSString stringWithFormat:@"%@/%@.manaul.log.txt", directory, [dateToday stringFromDate:[NSDate date]]];
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
//    [self performSelectorOnMainThread:@selector(appendManagerLog:)
//                           withObject:msg
//                        waitUntilDone:YES];
//    NSString* log = [NSString stringWithFormat:@"\n%@ : [MANAGER] : %@",[dateNow stringFromDate:[NSDate date]],noti.object];
    
    //mg//if( [NSThread isMainThread] ) {
        NSString* log;
        
        //mg//info 이상만 화면에 표시, debug 추가
        //verbose
        /*if([noti.name isEqualToString:@"LOG_VERBOSE_SEND"]){
            log = [NSString stringWithFormat:@"\n%@ : [MANAGER_VERBOSE] : %@",[dateNow stringFromDate:[NSDate date]],noti.object];
            [self appendStringValue:log mode:0 type:TYPE_MANAGER];
        }
        
        else if([noti.name isEqualToString:@"LOG_DEBUG_SEND"]){
            log = [NSString stringWithFormat:@"\n%@ : [MANAGER_DEBUG] : %@",[dateNow stringFromDate:[NSDate date]],noti.object];
            [self appendStringValue:log mode:4 type:TYPE_MANAGER];
        }
         */
    
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
        
        //mg//로그 파일 수정//
    [self logToFile:log];
        
        //mg//appendStringValue 내에서 dispatch_async 처리함
    /*} else {
        dispatch_async(dispatch_get_main_queue(), ^{
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
            
            [self logToFile:log];
        });//dispatch_async
    }//if - else : main thread
     */
    
//    [self appendStringValue:log mode:0 type:TYPE_MANAGER];
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
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self.txtDC textStorage] appendAttributedString:stringToAppend];
            NSPoint bottom = NSMakePoint(0.0, NSMaxY([[self.dcField documentView] frame]) - NSHeight([[self.dcField contentView] bounds]));
            [[self.statusField documentView] scrollPoint:bottom];
            
            [self.txtDC setNeedsDisplay:YES];
        });
        
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
    DDLogInfo(@"%s",__FUNCTION__);
    DDLogInfo(@"%@",[noti userInfo]);
    
    NSString* udid = [[noti userInfo] valueForKey:@"UDID"];
    NSString* name = [[noti userInfo] valueForKey:@"NAME"];
    NSString* version = [[noti userInfo] valueForKey:@"VERSION"];
    NSString* port = [[noti userInfo] valueForKey:@"PORT"];
    NSString* ratio = [[noti userInfo] valueForKey:@"RATIO"];
    NSString* proxy = [[noti userInfo] valueForKey:@"PROXY"];
    
    if( !port )
        port = @"";
    
    if( !proxy )
        proxy = @"";
    
    [self.tfUdid setStringValue:udid];
    [self.tfName setStringValue:name];
    [self.tfVersion setStringValue:version];
    [self.tfPort setStringValue:port];
    [self.tfRatio setStringValue:ratio];
    [self.tfProxy setStringValue:proxy];
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

/// @brief AppiumDeviceMapping.txt 에서 정보를 읽어들여 ConnectionItemInfo 객체리스트를 생성하며, 각각의 객체에 정보를 넣어준다.
- (void)__getMappingTableFromFileName:(NSString *)argFileName {
// DeviceNo |-|   UDID   |-| devicename |-| device version |-| appium port |-| device ratio |-| ios-webkit port
//   8      |-|udid123abh|-|  version   |-|     9,3,2      |-|    4730     |-|       2      |-| 27760
    NSString *thePath = [NSString stringWithFormat:@"%@/%@", [Utility managerDirectory], argFileName];
    NSString *content = [NSString stringWithContentsOfFile:thePath encoding:NSUTF8StringEncoding error:NULL];
    
	NSArray *theContentList = [content componentsSeparatedByString:@"\n"];
    
    DDLogWarn(@"content swccc = %@",theContentList);
    
	for (NSString *theItemInfo in theContentList) {
        
		NSArray *theItemList = [theItemInfo componentsSeparatedByString:@"|-|"];
		NSString *theDeviceId = [theItemList objectAtIndex:0];
		NSString *theUdid = [theItemList objectAtIndex:1];
        
        NSString *theDeviceName = [theItemList objectAtIndex:2];
        NSString *theDeviceVersion = [theItemList objectAtIndex:3];
        
        NSString *thePortNo = [theItemList objectAtIndex:4];
        
        NSString *theRatio = [theItemList objectAtIndex:5];
        NSString *theProxyNo = [theItemList objectAtIndex:6];
        
        NSString * theMirrorPortNo = [theItemList objectAtIndex:7];
        NSString * theControlPortNo = [theItemList objectAtIndex:8];
        
        
        
        ConnectionItemInfo *theConnectionItemInfo = [[ConnectionItemInfo alloc] init];
        CommunicatorWithDC *theSharedDCInterface = [CommunicatorWithDC sharedDCInterface];
        theConnectionItemInfo.dicAgentInfos = _dicAgentInfos;
        
        DeviceInfos * deviceInfo = [[DeviceInfos alloc] init];
        deviceInfo.deviceNo = [theDeviceId intValue];
        deviceInfo.udid = theUdid;
        deviceInfo.deviceName = theDeviceName;          // 이 값에 의해 해상도와 비율이 결정된다..
        deviceInfo.productVersion = theDeviceVersion;
        deviceInfo.appiumPort = thePortNo.intValue;
        deviceInfo.ratio = theRatio.floatValue;
        deviceInfo.appiumProxyPort = theProxyNo .intValue;
        deviceInfo.mirrorPort = theMirrorPortNo.intValue;
        deviceInfo.controlPort = theControlPortNo.intValue;
        
        theConnectionItemInfo.deviceInfos = deviceInfo;
        [theConnectionItemInfo initialize];                     // ControlAgent 객체가 생성된뒤 Tokens 를 넣어야 한다.
        
        theConnectionItemInfo.dicKorTokens = _dicKorTokens;
        [theConnectionItemInfo registerFileNotificationWithSuccess:[NSString stringWithFormat:@"FAIL_FILEDOWN_%@",theDeviceId] andFailed:[NSString stringWithFormat:@"SUCCESS_FILEDOWN_%@",theDeviceId]];
        [theConnectionItemInfo clearProcess];           // 전에 실행했던 프로세스가 남아있는지 확인하여 정리한다.
        [theConnectionItemInfo initUSBConnect];         // DeviceInfo 정보가 들어가 있는 상태에서 호출해야 함.
        [theConnectionItemInfo startDetachTimer];       // 남아있는 정보가 실재로 사용가능한 정보인지 확인함..
        
        NSMutableDictionary * dicItem = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:deviceInfo.deviceNo], KEY_INDEX, deviceInfo.udid, KEY_UDID, theConnectionItemInfo, KEY_OBJECT, nil];
        
//        [self.myConnectionItemList setObject:theConnectionItemInfo forKey:theDeviceId];
        [self.arrConnectionItemList addObject:dicItem];
    }
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

/// @brief 서버 소켓을 생성하여 DC 와의 연결을 기다린다.
- (void)startSocketServer:(int)deviceCount {
	CommunicatorWithDC *theSharedDCInterface = [CommunicatorWithDC sharedDCInterface];
	theSharedDCInterface.mainController = self;
	[theSharedDCInterface startInterfaceWithDC];
}

- (ConnectionItemInfo *)firstConnectionItemInfo {
    if( ![_arrConnectionItemList count] )
        return nil;
    
    NSDictionary * dicFirstItem = [_arrConnectionItemList firstObject];
    return [dicFirstItem objectForKey:KEY_OBJECT];
}

- (ConnectionItemInfo* )connectionItemInfoByDeviceNo:(int)argDeviceNo{
    
    NSString * temp = [NSString stringWithFormat:@"%@ == %d", KEY_INDEX, argDeviceNo];
    NSPredicate * predicate = [NSPredicate predicateWithFormat:temp];
    NSArray * results = [_arrConnectionItemList filteredArrayUsingPredicate:predicate];

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

- (IBAction)ResetAll:(id)sender {
    /*
     [self.myConnectionItemList enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent
                                   usingBlock:^(id key, id object, BOOL *stop) {
                                       DDLogInfo(@"%@ = %@", key, object);
                                       if(object != nil)
                                           [(ConnectionItemInfo*)object resetAppium];
                                   }];
    
    [self.myConnectionItemList removeAllObjects];
    [self __getMappingTableFromFileName:MAPPINGFILE];
     */
  
    DDLogWarn(@"test");
    
//    [self performSelector:@selector(restartManager2) withObject:nil afterDelay:5.0];
    
    /*
    for( NSDictionary * dicItem in _arrConnectionItemList ) {
        ConnectionItemInfo * itemInfo = [dicItem objectForKey:KEY_OBJECT];
        [itemInfo resetAppium];
    }
    
    [_arrConnectionItemList removeAllObjects];
#ifdef VER_STANDALONE
    [self initConnectionItemList];
#else
    [self __getMappingTableFromFileName:MAPPINGFILE];
#endif
*/
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

- (IBAction)connectDevice:(id)sender
{
    ConnectionItemInfo* itemInfo = [self connectionItemInfoByDeviceNo:1];      //
    if (itemInfo == nil) {
        return;
    } else {
//        
//        // modiby by leehh  아래는 자동화 시작시 devicelog 실행한다고 되어있기에 분기처리함.
//        //        if( !manual ) {//swccc Log출력 확인
//        if(manual){
//            //(Log를 시작할 때마다 로그를 출력하면 로그가 중복되어, 디바이스 연결시에 로그 출력을 시작하고 로그 출력 커맨드가 왔을 때 로그를 D.C로 전송)
//            if(itemInfo.myDeviceLog == nil)
//                itemInfo.myDeviceLog = [[DeviceLog alloc] initWithDeviceNo:itemInfo.deviceNo UDID:itemInfo.myDeviceUdid];
//            [itemInfo.myDeviceLog startLogAtFirst];
//        }
        
        NSString* ratio = [NSString stringWithFormat:@"%.1f",itemInfo.deviceInfos.ratio];

        NSDictionary* dict = [[NSDictionary alloc] initWithObjectsAndKeys:itemInfo.deviceInfos.udid,@"UDID"
                              ,itemInfo.deviceInfos.deviceName,@"NAME"
                              ,itemInfo.deviceInfos.productVersion,@"VERSION"
                              ,ratio,@"RATIO"
                              , nil];
        
        
        [[NSNotificationCenter defaultCenter] postNotificationName:DEVICE_CONNECT object:self userInfo:dict];
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

-(IBAction)saveLogFile:(id)sender
{
    DDLogWarn(@"%s",__FUNCTION__);
    // resign as first responder the other controls
    AppDelegate *appDelegate = (AppDelegate *)[NSApp delegate];
    [appDelegate.window makeFirstResponder: nil];
    
    NSSavePanel* saveDlg = [NSSavePanel savePanel];
    [saveDlg setTitle:@"로그 저장"];
    [saveDlg setCanCreateDirectories:YES];


    [saveDlg setAllowedFileTypes:@[@"txt",@"TXT"]];
    [saveDlg beginSheetModalForWindow:appDelegate.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton)
        {
            NSURL*  theFile = [saveDlg URL];
            DDLogWarn(@"%@",theFile);
            // Write the contents in the new format.
            NSString* path = [theFile path];

            [[NSData data] writeToFile:path atomically:YES];

            
            NSFileHandle* handle = [NSFileHandle fileHandleForWritingAtPath:path];
            [handle truncateFileAtOffset:[handle seekToEndOfFile]];
            NSString* log = @"";
            int nIndex = (int)[self.cmbLog indexOfSelectedItem];
            if(nIndex == 0){
                log = [[self.txtView textStorage] string];
            }else if(nIndex == 1){
                log = [[self.txtAppiumView textStorage] string];
            }else if(nIndex == 2){
                log = [[self.txtManagerView textStorage] string];
            }
            [handle writeData:[log dataUsingEncoding:NSUTF8StringEncoding]];
            [handle closeFile];

        }
    }];
}

-(IBAction)startLog:(id)sender
{
    DDLogInfo(@"%s",__FUNCTION__);
    ConnectionItemInfo* itemInfo = [self connectionItemInfoByDeviceNo:2];
    if(itemInfo.myDeviceLog == nil)
        itemInfo.myDeviceLog = [[DeviceLog alloc] initWithDeviceNo:itemInfo.deviceInfos.deviceNo UDID:itemInfo.deviceInfos.udid withDelegate:itemInfo];
    
    [itemInfo.myDeviceLog startLogAtFirst];

}

-(IBAction)expandAppLog:(id)sender
{
    DDLogWarn(@"%s",__FUNCTION__);
    DDLogWarn(@"%f and %f",self.view.frame.size.width,self.view.frame.size.height);
    
    
    DDLogWarn(@"%f and %f",self.tfAppLog.frame.origin.x,self.tfAppLog.frame.origin.y);
    DDLogWarn(@"%f and %f",self.btnExpandAppLog.frame.origin.x,self.btnExpandAppLog.frame.origin.y);
    DDLogWarn(@"%f and %f",self.scrAppLog.frame.origin.x,self.scrAppLog.frame.origin.y + self.scrAppLog.frame.size.height);
    
    
    if([self.scrAppLog isHidden]){
        [self.scrAppLog setHidden:NO];
        
        [self.tfAppLog setFrame:NSMakeRect(18, 233, 198, 17)];
        [self.btnExpandAppLog setFrame:NSMakeRect(104, 235, 13, 13)];
        

        [self.statusField setFrame:NSMakeRect(self.statusField.frame.origin.x, self.statusField.frame.origin.y + 225
                                              , self.statusField.frame.size.width
                                              , self.statusField.frame.size.height - 225)];
        
        [self.appumField setFrame:NSMakeRect(self.appumField.frame.origin.x, self.appumField.frame.origin.y + 225
                                              , self.appumField.frame.size.width
                                              , self.appumField.frame.size.height - 225)];

        
        [self.managerField setFrame:NSMakeRect(self.managerField.frame.origin.x, self.managerField.frame.origin.y + 225
                                              , self.managerField.frame.size.width
                                              , self.managerField.frame.size.height - 225)];
        
        [self.btnRemoveLog setFrame:NSMakeRect(self.btnRemoveLog.frame.origin.x, self.btnRemoveLog.frame.origin.y + 225
                                               , self.btnRemoveLog.frame.size.width
                                               , self.btnRemoveLog.frame.size.height)];


    }else{
        [self.scrAppLog setHidden:YES];
        [self.tfAppLog setFrame:NSMakeRect(18, 233 - 225, 198, 17)];
        [self.btnExpandAppLog setFrame:NSMakeRect(104, 235 - 225, 13, 13)];

        [self.statusField setFrame:NSMakeRect(self.statusField.frame.origin.x, self.statusField.frame.origin.y - 225
                                              , self.statusField.frame.size.width
                                              , self.statusField.frame.size.height + 225)];
        
        [self.appumField setFrame:NSMakeRect(self.appumField.frame.origin.x, self.appumField.frame.origin.y - 225
                                              , self.appumField.frame.size.width
                                              , self.appumField.frame.size.height + 225)];

        
        [self.managerField setFrame:NSMakeRect(self.managerField.frame.origin.x, self.managerField.frame.origin.y - 225
                                              , self.managerField.frame.size.width
                                              , self.managerField.frame.size.height + 225)];


        [self.btnRemoveLog setFrame:NSMakeRect(self.btnRemoveLog.frame.origin.x, self.btnRemoveLog.frame.origin.y - 225
                                               , self.btnRemoveLog.frame.size.width
                                               , self.btnRemoveLog.frame.size.height)];

    }
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
        labelFont = [NSFont fontWithName:FONT_HELVETICA size:13];
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
            [[self.txtView textStorage] appendAttributedString:stringToAppend];
            NSPoint bottom = NSMakePoint(0.0, NSMaxY([[self.statusField documentView] frame]) - NSHeight([[self.statusField contentView] bounds]));
            [[self.statusField documentView] scrollPoint:bottom];
        }else if(nType == 1){
            [[self.txtAppiumView textStorage] appendAttributedString:stringToAppend];
            NSPoint bottom = NSMakePoint(0.0, NSMaxY([[self.appumField documentView] frame]) - NSHeight([[self.appumField contentView] bounds]));
            [[self.appumField documentView] scrollPoint:bottom];
        }else if(nType == 2){
            [[self.txtManagerView textStorage] appendAttributedString:stringToAppend];
            NSPoint bottom = NSMakePoint(0.0, NSMaxY([[self.managerField documentView] frame]) - NSHeight([[self.managerField contentView] bounds]));
            [[self.managerField documentView] scrollPoint:bottom];
        }
    });
    // scrolls to the bottom
}//appendStringValue

- (void)setStringValue:(NSString*)string
{
    NSTextView *textfield = (NSTextView*)self.statusField.documentView;
    [textfield setString:string];
    
    // scrolls to the bottom
    NSPoint bottom = NSMakePoint(0.0, NSMaxY([[self.statusField documentView] frame]) - NSHeight([[self.statusField contentView] bounds]));
    [[self.statusField documentView] scrollPoint:bottom];
}

- (void) processClearLogs {
    int nIndex = (int)[self.cmbLog indexOfSelectedItem];
    NSLog(@"%s(%d)",__FUNCTION__,nIndex);
    
    [self.txtView setString:@""];
    [self.txtView.textStorage.mutableString setString:@""];
    [self.txtView setNeedsDisplay:YES];
    
    [self.txtAppiumView setString:@""];
    [self.txtAppiumView.textStorage.mutableString setString:@""];
    [self.txtAppiumView setNeedsDisplay:YES];
    
    [self.txtManagerView setString:@""];
    [self.txtManagerView.textStorage.mutableString setString:@""];
    [self.txtManagerView setNeedsDisplay:YES];
    
    [self.txtDC setString:@""];
    [self.txtDC.textStorage.mutableString setString:@""];
    [self.txtDC setNeedsDisplay:YES];
}


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
    // Show a critical alert
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"CANCEL"];
    [alert setMessageText:title];
    [alert setInformativeText:message];
    [alert setAlertStyle:style];
    
    NSModalResponse responseTag = [alert runModal];
    if(responseTag == NSAlertFirstButtonReturn){
        [self processClearLogs];
    } else {
        
    }
}

#pragma mark - <Timer Delegate>
- (void) onClearLogTimer:(NSTimer *)theTimer {
    [self processClearLogs];
}

#pragma mark - ComboBox Delegate

- (void)comboBoxSelectionIsChanging:(NSNotification *)notification
{
    DDLogWarn(@"%d",(int)[self.cmbLog indexOfSelectedItem]);
    int nIndex = (int)[self.cmbLog indexOfSelectedItem];
    [self showLogField:nIndex];
}

-(void)showLogField:(int)index
{
    if(index == 0){
        [self.statusField setHidden:NO];
        [self.appumField setHidden:YES];
        [self.managerField setHidden:YES];
        
        [self.txtView setNeedsDisplay:YES];
        
        [self.tfLogInfo setStringValue:@"DC Log"];
    }else if(index == 1){
        [self.statusField setHidden:YES];
        [self.appumField setHidden:NO];
        [self.managerField setHidden:YES];
        
        [self.tfLogInfo setStringValue:@"Appum Log"];
        
        [self.appumField setNeedsDisplay:YES];
    }else if(index == 2){
        [self.statusField setHidden:YES];
        [self.appumField setHidden:YES];
        [self.managerField setHidden:NO];
        
        [self.tfLogInfo setStringValue:@"Manager Log"];
        [self.appumField setNeedsDisplay:YES];
    }
}

-(IBAction)clearDCLog:(id)sender{
    DDLogInfo(@"%s",__FUNCTION__);
    [self.txtDC setString:@""];
    [self.txtDC.textStorage.mutableString setString:@""];
    [self.txtDC setNeedsDisplay:YES];

}


@end
