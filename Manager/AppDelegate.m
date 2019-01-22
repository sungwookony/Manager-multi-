//
//  AppDelegate.m
//  Manager
//
//  Created by mac_onycom on 2015. 6. 22..
//  Copyright (c) 2015년 tomm. All rights reserved.
//

#import "AppDelegate.h"
#import "MainViewController.h"
#import "LogToFile.h"

#import "DDLog.h"
#import "DDTTYLogger.h"
#import "DDASLLogger.h"

#import "Utility.h"
#import "ManagerLogFileFormat.h"

@interface AppDelegate ()
@property (nonatomic, strong) IBOutlet MainViewController *mainVC;
@end

/// @brief Application Delegate
@implementation AppDelegate

#pragma mark - <App Delegate>

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
//    [self deduplicateRunningInstances];

    //DDLOG 설정
//    [DDLog addLogger:[DDASLLogger sharedInstance]]; //sends log statements to Apple System Logger, so they show up on Console.app
    [DDLog addLogger:[DDTTYLogger sharedInstance]]; //sends log statements to Xcode console - if available
    
    //mg//file logger
    //log directory
    /*
    NSString * logDirectory = [NSString stringWithFormat:@"%@/LOG", [Utility managerDirectory]];
    if(![[NSFileManager defaultManager] fileExistsAtPath:(NSString *)logDirectory]) {
        NSError *error;
        
        if (![[NSFileManager defaultManager] createDirectoryAtPath:logDirectory
                                       withIntermediateDirectories:YES attributes:nil error:&error])
            DDLogError(@"Failed to create log directory : %@", error);
    }
    
    DDLogFileManagerDefault *documentsFileManager = [[DDLogFileManagerDefault alloc]
                                                     initWithLogsDirectory:logDirectory];
    DDFileLogger *fileLogger = [[DDFileLogger alloc]
                                initWithLogFileManager:documentsFileManager];
    
    fileLogger.logFormatter = [[ManagerLogFileFormat alloc] init];
    fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
    fileLogger.logFileManager.maximumNumberOfLogFiles = 30;//7;//to keep a week's worth of log files on the system.
    //fileLogger.maximumFileSize = 1024*1024*30;//30M
    
    [DDLog addLogger:fileLogger];
     */
    //DDLogInfo(@"log file at: %@", [[fileLogger currentLogFileInfo] filePath]);

    //Crush발생시에 로그 발생
    NSSetUncaughtExceptionHandler(&uncauthExceptionHandler);
    
        
     self.mainVC = [[MainViewController alloc] initWithNibName:@"MainViewController" bundle:nil];
    
    [self.window setFrame:NSMakeRect(100.0, 100.0, 900.0, 700.0) display:YES];
    
    [self.window.contentView addSubview:self.mainVC.view];
    [self.window setContentMinSize:NSMakeSize(700, 500)];

    NSString* version = [NSString stringWithFormat:@"ONYCOM iOS DEP Manager [%@]",[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
    
    [self.window setTitle:version];
    
    self.mainVC.view.frame =((NSView*)self.window.contentView).bounds;
    
//    [self.mainVC.dcView.window setFrame:NSMakeRect(1020, 100, 300, 700) display:YES];
//    [self.mainVC.dcView.window setTitle:@"DC"];
    [self.mainVC.dcView.window setIsVisible:NO];
    
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    DDLogInfo(@"%s",__FUNCTION__);
    return YES;
}

/**
 * @brief   Manager종료시 ConnectionItemInfo 에 Notification 을 보내 정리하는 과정을 거친다. connectionItemInfo 는 AppiumDeviceMapping.txt 정보에 의해 결정된다.
 */
- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    DDLogInfo(@"-=applicationWillTerminate=");
//    [self.mainVC killProcess];
    
    //mg//s
    NSString * output = [Utility launchTaskFromBash:[NSString stringWithFormat:@"ps -ef | grep idevicedebug"]];
    output = [output stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    NSArray* arrOut = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    NSMutableArray * arrPid = [NSMutableArray array];

    for( NSString * outputProcessInfos in arrOut ) {
        if( 0 == outputProcessInfos.length )
            continue;
        
        if( [outputProcessInfos containsString:@"grep "] )
            continue;
        
        NSArray * component = [outputProcessInfos componentsSeparatedByString:@" "];
        [arrPid addObject:[component objectAtIndex:3]];
    }
    
    if( arrPid.count ) {
        NSString * strPids = [arrPid componentsJoinedByString:@" "];
        NSString * command = [NSString stringWithFormat:@"kill -9 %@", strPids];
        int result = system([command cStringUsingEncoding:NSUTF8StringEncoding]);
        DDLogVerbose(@"kill process result = %d", result);
    }
    //mg//e
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ApplicationWillTerminateNotification object:nil];
    
//    restartManager();
}

#pragma mark - <User Functions>
/**
 * @brief   예외 발생시 콜스택정보를 파일에 저장함. 경로는 /Document
 */
void uncauthExceptionHandler(NSException *exception)
{
    DDLogError(@"오류 CRASH : %@",exception);
    DDLogError(@"Stack Trace : %@",[exception callStackSymbols]);
    LogToFile(exception.description);
    LogToFile([exception callStackSymbols].description);
    
    restartManager();
}

/**
 * @brief   메니져가 동시에 2개 실행되지 않도록 체크하여 알림창을 띄워줌.
 */
- (void)deduplicateRunningInstances {
    int nCount = (int)[[NSRunningApplication runningApplicationsWithBundleIdentifier:[[NSBundle mainBundle] bundleIdentifier]] count];
    if ( nCount > 1) {
        [[NSAlert alertWithMessageText:[NSString stringWithFormat:@"Another copy of %@ is already running.", [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey]]
                         defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"This copy will now quit."] runModal];
        
        [NSApp terminate:nil];
    }
}

void restartManager() {
    DDLogDebug(@"1%s", __FUNCTION__);
    
    NSString *mgr = [NSString stringWithFormat:@"%@Manager.app", [Utility managerDirectory]];
    [[NSWorkspace sharedWorkspace] launchApplication:mgr];
//    exit(0);
    DDLogInfo(@"%s", __FUNCTION__);
//
//    NSString *path = [[NSBundle mainBundle] executablePath];
//
//    NSLog(@"path = %@",path);
//
//    NSTask * restartTask = [[NSTask alloc] init];
//    restartTask.launchPath = path;
//    [restartTask launch];
//
//    [[NSApplication sharedApplication] terminate:nil];
}

@end
