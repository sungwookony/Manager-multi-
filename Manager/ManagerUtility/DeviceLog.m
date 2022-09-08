//
//  DeviceLog.m
//  Manager
//
//  Created by Mac0516 on 2015. 7. 23..
//  Copyright (c) 2015년 tomm. All rights reserved.
//


/**
 *  @file       DeviceLog.m
 *  @brief      Device System Log 정보를 획득함.
 *  @details    상당히 중요한 역활을 하는데... System Log 를 분석하다보면 실행되는 앱의 시점과 BundleID 를 알 수 있음. \
                iOS 10.x 는 WebDriverAgent 으로 홈화면(springboard) 에서 Tap 하여 실행한 앱을 제어 할 수 있는 반면,\
                iOS 11.x 버전은 제어가 안됨. 다행히 bundleid 로 실행한 앱은 제어할 수 있어기 때문에 DeviceLog 에서 실행된 앱의 \
                BundleID 로 앱을 재실행하여 제어함.
 * @bug         1. 앱에서 출력한 로그가 (개발자에 의해) 출력되지 않는 경우가 있다고 함. (최성욱 선임에게 확인할 것) \
                2. 로그레벨이 안드로이드 기준이라 iOS 와는 맞지 않아 수정이 필요함.
 * @todo        1. 앱에서 출력하는 로그정보가 안나오는 경우에 대한 분석을 하여 잘 나오도록 예외 처리 해야함.\
                2. 로그레벨을 재정의 하여 안드로이드와 호환이 되도록 수정 해야 함.
 * author       이훈희 (SR_LHH_MAC)
 */


#import "DeviceLog.h"
#import "CommunicatorWithDC.h"
#import "TaskHandler.h"
#import "ConnectionItemInfo.h"
#import "Utility.h"

/// @brief deviceconsole 에서 출력되는 로그 정보를 파싱하기 위한 정규표현식
#define LINE_REGEX "(\\w+\\s+\\d+\\s+\\d+:\\d+:\\d+)\\s+(\\S+|)\\s+(\\S+)\\[(\\d+)\\]\\s+\\<(\\w+)\\>:\\s(.*)"

#define LINE_REGEX13 "(\\w+\\s+\\d+\\s+\\d+:\\d+:\\d+)\\s+(\\S+|)\\[(\\d+)\\]\\s+\\<(\\w+)\\>:\\s(.*)"

/// @brief 사용하지 않음.
#define CLOSE_LOG_TASK     (int64_t)((double)15.0 * NSEC_PER_SEC)

@interface DeviceLog ()<PipeHandlerDelegate>{
    // 220406 swccc 로그 재시작
    NSString* date;
    NSString* prevMinute;
    
    //search keyword

}
@property (nonatomic, strong) PipeHandler   * pipeHandler;
@property (nonatomic, strong) dispatch_queue_t      logQueue;
@property (nonatomic, strong) dispatch_queue_t      deviceLogQueue;
@property (nonatomic, strong) dispatch_semaphore_t  deviceLogSem;

@property (nonatomic, strong) NSTimer* timerChekLog;

@property (nonatomic, strong) NSString* search;
@property (nonatomic, strong) NSString* identifier;
@property (nonatomic, strong) NSString* bundleID;
@property (nonatomic, strong) NSString* searchAppName;

@end


/// @brief  디바이스의 시스템 로그를 분석하여 로그레벨에 맞춰 DC로 전송하거나, 실행되는 앱의 정보를 획득한다.
@implementation DeviceLog
@synthesize customDelegate,myDeviceInfos;;

/// @brief  초기화
//- (id)initWithDeviceNo:(int)argDeviceNo UDID: (NSString* ) argUDID withDelegate:(id<DeviceLogDelegate>)delegate {
- (id)initWithDeviceNo:(int)argDeviceNo UDID: (NSString* ) argUDID deviceVersion:(NSString *)deviceVersion withDelegate:(id<DeviceLogDelegate>)delegate{
    if (self = [super init]) {
        customDelegate = delegate;
        _bLogStarted = NO;
        _udid = argUDID;
        _deviceNo = argDeviceNo;
        _logLevel = 0;
        _logIdentifier = @"*";
        _logSearch = @"";
        
        _osVersion = [deviceVersion intValue];
        
        _deviceLogQueue = dispatch_queue_create("DeviceLogQueue", NULL);
        _deviceLogSem = dispatch_semaphore_create(1);
    }
    return self;
}

- (void) dealloc {
    _deviceLogQueue = nil;
    _deviceLogSem = nil;
}

#pragma mark - <PipeHandler Delegate>
/// @brief PipeHandler에서 발생하여 호출된 Delegate 메소드
- (void) readData:(NSData *)readData withHandler:(id)handler {
    
//    if( handler == _pipeHandler && _bLogStarted == YES) {
    if(self.bLogStarted){
        
        NSString *outStr = [[NSString alloc] initWithData:readData encoding:NSUTF8StringEncoding];
//        DDLogInfo(@"====== outStr===== %@", outStr);//manage
        [self manageLog:outStr];
    }
}


#pragma mark - <fundtions>

/// @brief deviceconsole 를 실행하여 로그정보를 획득하기 시작한다.
- (void)startLogAtFirst {
    DDLogDebug(@"%s", __FUNCTION__);
    
//    NSString * theManagerDirectory = [Utility managerDirectory];
//    NSString * logCmdPath = [theManagerDirectory stringByAppendingPathComponent:@"deviceconsole"];
//    NSLog(@"###### %@ #######",theManagerDirectory);
      
    if(self.logTask != nil){
//        self.logTask = nil;
    }else{
        self.logTask = [[NSTask alloc] init];
        
        
    //    [self.logTask  setLaunchPath:logCmdPath];
    //    [self.logTask  setArguments: [[NSArray alloc] initWithObjects:
    //                                  @"-u",self.udid, nil]];
        
//        NSString * commandString = [NSString stringWithFormat:@"idevicesyslog -u %@ -K", _udid];
//        NSString * commandString = [NSString stringWithFormat:@"idevicesyslog -u %@ -K -q", _udid];
        NSString * commandString = [NSString stringWithFormat:@"idevicesyslog -u %@", _udid];
        self.logTask.launchPath = @"/bin/sh";
        self.logTask.arguments = @[@"-l", @"-c", commandString];
        
        _pipeHandler = [[PipeHandler alloc] initWithDelegate:self];
        [_pipeHandler setReadHandlerForTask:self.logTask withKind:PIPE_OUTPUT];
        
        //예외 일괄처리
        //mg//[self.logTask launch];
        //mg//s
        NSError* error = nil;
        if( [NSThread isMainThread] ) {
            @autoreleasepool {
                if (@available(macOS 10.13, *)) {
                    [self.logTask launchAndReturnError:&error];
                } else {
                    [self.logTask launch];
                }
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                DDLogDebug(@"start device log task");
                @autoreleasepool {
                    [self.logTask launch];
                }
            });
        }
    }
    [self.logTask suspend];
}//startLogAtFirst

// 210727 swccc 로그 재시작
//-(void)checkLogOutput{
//    if(self.logTask != nil){
//        if(self.bLogStarted){
//            if([self.logTask isRunning]){
//                if(tempMsg != nil && tempProcess != nil){
//                    if(checkMsg.length == 0 || checkProcess.length == 0){
//                        @try {
//                            checkMsg = [NSString stringWithFormat:@"%@",tempMsg];
//                            checkProcess = [NSString stringWithFormat:@"%@",tempProcess];
//                        } @catch (NSException *exception) {
//                            DDLogInfo(@"CRASH 지점 1 %@", exception.description);
//                        }
//                        [self performSelector:@selector(checkLogOutput) withObject:nil afterDelay:5.0];
//                        return;
//                    }
//
//                    if([checkMsg isEqual:tempMsg] && [checkProcess isEqual:tempProcess]){
//                        tempMsg = nil;
//                        tempProcess = nil;
//                        checkMsg = nil;
//                        checkProcess = nil;
//                        [self stopLog];
//                        [self restartLog:keyword];
//                        return;
//                    }else{
//                        DDLogInfo(@"CRASH 지점 2");
//                        @try {
//                            checkMsg = [NSString stringWithFormat:@"%@",tempMsg];
//                            checkProcess = [NSString stringWithFormat:@"%@",tempProcess];
//                        } @catch (NSException *exception) {
//                            DDLogInfo(@"CRASH 지점 2 %@", exception.description);
//                        }
//
//                    }
//                }
//            }else{
//
//            }
//            [self performSelector:@selector(checkLogOutput) withObject:nil afterDelay:5.0];
//        }
//    }
//}

// 210727 swccc 로그 재시작
-(void)restartLog:(NSString *)search{
    dispatch_async(dispatch_get_main_queue(), ^{
       
        if(self.logTask != nil){
            self.logTask = nil;
        }
        self.logTask = [[NSTask alloc] init];
        NSString * commandString = [NSString stringWithFormat:@"idevicesyslog -u %@ -K -q", _udid];
        if([search isEqualToString:@"*"]){
            
        }else{
            if(search != nil){
                if(search.length > 0){
                    commandString = [NSString stringWithFormat:@"%@ | grep %@",commandString,search];
                }
            }
        }
        self.logTask.launchPath = @"/bin/sh";
        self.logTask.arguments = @[@"-l", @"-c", commandString];
        
    //        NSPipe* pipe = [NSPipe pipe];
        if(self.pipe != nil){
            self.pipe = nil;
        }
        self.pipe = [NSPipe pipe];
        [self.logTask setStandardOutput:self.pipe];
        
        if(self.bLogStarted == NO){
            self.bLogStarted = YES;
        }
        // 210727 swccc 로그 재시작
//        [self checkLogOutput];
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
                    }
                }
            }];
        }];
        __block typeof(self) weakSelf = self;
        __block dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [self.logTask setTerminationHandler:^(NSTask *task) {
            // do your stuff on completion
            if(semaphore){
                dispatch_semaphore_signal(semaphore);
            }
            
            @try {
                [weakSelf.logTask.standardOutput fileHandleForReading].readabilityHandler = nil;
            } @catch (NSException *exception) {
                NSLog(@"standardOutput except = %@",exception.description);
            }
            
            [weakSelf killLog];
//
//            @try {
//                [weakSelf.logTask.standardError fileHandleForReading].readabilityHandler = nil;
//            } @catch (NSException *exception) {
//                NSLog(@"standardOutput except = %@",exception.description);
//            }
        }];
    });
}

-(void)checkLogStatus{
    NSLog(@"%s",__FUNCTION__);
    if(self.logTask){
        NSLog(@"log not nil");
        if([self.logTask isRunning]){
            NSLog(@"log running (%@)",date);
            if(date != nil && date.length > 0){
                NSArray* arrayTemp;
                @try {
                    arrayTemp = [date componentsSeparatedByString:@":"];
                } @catch (NSException *exception) {
                    NSLog(@"%@",exception.description);
                    arrayTemp = nil;
                }
                
                if(arrayTemp != nil){
                    if([arrayTemp count] == 3){
                        
//                        NSString* minute = [arrayTemp objectAtIndex:1]; //<--ㅎㅕㄴㅈㅐㅅㅣㄱㅏㄴㅇㅡㄹㅂㅣㄱㅛ
                        
                        time_t t;
                        struct tm * timeinfo;
                        time (&t);
                        timeinfo = localtime (&t);
                        NSString* minute;
                        if(timeinfo->tm_min < 10){
                            minute = [NSString stringWithFormat:@"0%d",timeinfo->tm_min];
                        }else{
                            minute = [NSString stringWithFormat:@"%d",timeinfo->tm_min];
                        }
                        
                        
                        NSLog(@"log = %@ and system = %@",[arrayTemp objectAtIndex:1],minute);
                        prevMinute = [arrayTemp objectAtIndex:1];
                        if(prevMinute == nil || prevMinute.length == 0){
                            prevMinute = [arrayTemp objectAtIndex:1];
                        }else{
                            if(![minute isEqualToString:prevMinute]){
                                NSLog(@"log restart %@ and %@ ",minute, prevMinute);
                                [self stopCheckLogStatus];
                                [self stopLog];
                                sleep(1);
                                prevMinute = [arrayTemp objectAtIndex:1];
                                char theLogLevel ='V';
                                [self startLog:self.search identifier:self.identifier level:theLogLevel bundleID:self.bundleID appName:self.appName];
                                return;
                            }
//                            prevMinute = [arrayTemp objectAtIndex:1];
                        }
                    }
                }
            }
        }else{
            [self stopCheckLogStatus];
            [self stopLog];
            sleep(1);
            char theLogLevel ='V';
            [self startLog:self.search identifier:self.identifier level:theLogLevel bundleID:self.bundleID appName:self.appName];
            return;

        }
    }
}

-(void)stopCheckLogStatus{
    if(_timerChekLog){
        [_timerChekLog invalidate];
        _timerChekLog = nil;
    }
}

/// @brief D.C에서 로그출력 시작 수신시.
- (void)startLog:(NSString *)search identifier:(NSString* )identifier level: (char)level bundleID:(NSString *)bundleID appName:(NSString *)appName{
    
    dispatch_async(dispatch_get_main_queue(), ^{
       
        self.search = search;
        self.identifier = identifier;
        self.bundleID = bundleID;
        self.appName = appName;
        
        if(_timerChekLog != nil){
            _timerChekLog = nil;
        }
//        _timerChekLog = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(checkLogStatus) userInfo:nil repeats:YES];
        
        if(self.logTask != nil){
            self.logTask = nil;
        }
        self.logTask = [[NSTask alloc] init];
        NSLog(@"search = %@ and idtf = %@",search,identifier);
        NSString * commandString = [NSString stringWithFormat:@"idevicesyslog -u %@ -K -q", _udid];
        if([search isEqualToString:@"*"]){
            
        }else{
            if(search != nil){
                if(search.length > 0){
                    commandString = [NSString stringWithFormat:@"%@ | grep %@",commandString,search];
                }
            }
        }
        NSString *cpu = [Utility cpuHardwareName];
        if([cpu isEqualToString:@"x86_64"]){
            self.logTask.launchPath = @"/bin/sh";
            self.logTask.arguments = @[@"-l", @"-c", commandString];
        }else{
            self.logTask.launchPath = @"/opt/homebrew/bin/idevicesyslog";
            self.logTask.arguments = @[@"-u",
                                       _udid,
                                       ];
        }
        
        
    //        NSPipe* pipe = [NSPipe pipe];
        if(self.pipe != nil){
            self.pipe = nil;
        }
        self.pipe = [NSPipe pipe];
        [self.logTask setStandardOutput:self.pipe];
        
        if(self.bLogStarted == NO){
            self.bLogStarted = YES;
        }
        // 210727 swccc 로그 재시작
//        [self checkLogOutput];
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
//                        [[self.pipe fileHandleForReading] waitForDataInBackgroundAndNotify];
                    }
                }
            }];
        }];
        __block typeof(self) weakSelf = self;
        __block dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [self.logTask setTerminationHandler:^(NSTask *task) {
            // do your stuff on completion
            if(semaphore){
                dispatch_semaphore_signal(semaphore);
            }
            
            
            @try {
                [weakSelf.logTask.standardOutput fileHandleForReading].readabilityHandler = nil;
            } @catch (NSException *exception) {
                NSLog(@"standardOutput except = %@",exception.description);
            }
            
            [weakSelf killLog];
//
//            @try {
//                [weakSelf.logTask.standardError fileHandleForReading].readabilityHandler = nil;
//            } @catch (NSException *exception) {
//                NSLog(@"standardOutput except = %@",exception.description);
//            }
        }];
    });
}



- (void)startLog2:(NSString *)search identifier:(NSString* )identifier level: (char)level bundleID:(NSString *)bundleID appName:(NSString *)appName
{
    DDLogDebug(@"%s",__FUNCTION__);
    DDLogVerbose(@"bundle ID = %@ & name = %@",bundleID,appName);
//    BOOL bLogStart = [self.logTask resume];
//    if([self.logTask isRunning] == NO){
//        //mg//s
//        if( [NSThread isMainThread] ) {
//            [self.logTask launch];
//        } else {
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [self.logTask launch];
//            });
//        }
//        //mg//e
//
//        //mg//[self.logTask launch];
//    }
    @try{
        
        BOOL bLogStart = [self.logTask resume];
        if(self.bLogStarted == NO){
            self.bLogStarted = YES;
        }
        if(_pipeHandler != nil){
            _pipeHandler = nil;
            _pipeHandler = [[PipeHandler alloc] initWithDelegate:self];
            [_pipeHandler setReadHandlerForTask:self.logTask withKind:PIPE_OUTPUT];

        }

        NSLog(@"b = %d",bLogStart);
    }@catch(NSException* ex){
        
    }
    
    [self setLogFilterSearch:search identifier:identifier level:level];
    if(self.bLogStarted == YES){
        return;
    }
    self.bLogStarted = YES;
    self.bundleId = bundleID;
    self.appName = appName;
}

/// @brief 문제의 로그 레벨 설정.
- (void)setLogFilterSearch:(NSString *)search identifier:(NSString* )identifier level: (char)level
{
    self.logIdentifier = identifier;
    //    self.logLevel = level;
    self.logSearch = search;
    
    if(level == 'V'){
        self.logLevel = 0;
    } else if(level == 'D'){
        self.logLevel = 1;
    } else if(level == 'I'){
        self.logLevel = 2;
    } else if(level == 'N'){
        self.logLevel = 2;
    } else if(level == 'W'){
        self.logLevel = 3;
    } else if(level == 'E'){
        self.logLevel = 4;
    } else {
        self.logLevel = 0;
    }
}

/// @brief D.C에서 로그출력 종료 수신시.
- (void)stopLog2
{
    self.bLogStarted = NO;
    [self setLogFilterSearch:@"*" identifier:@"" level:'V'];
    if([self.logTask isRunning]){
//        [self.logTask suspend];
    }
}

-(void)stopLog{
//    dispatch_async(dispatch_get_main_queue(), ^{
    //test
    [self stopCheckLogStatus];
    
    
    self.bLogStarted = NO;
    [self setLogFilterSearch:@"*" identifier:@"" level:'V'];
//[self killLogProcess];
    if(self.pipe != nil){
        [[self.pipe fileHandleForReading] closeFile];

        sleep(2);
        
        @try {
           
            [[NSNotificationCenter defaultCenter] removeObserver:self.pipeNotiObserver];
            [[NSNotificationCenter defaultCenter] removeObserver:NSFileHandleDataAvailableNotification name:nil object:[self.pipe fileHandleForReading]];
            [[NSNotificationCenter defaultCenter] removeObserver:NSFileHandleDataAvailableNotification];
        } @catch (NSException *exception) {
            NSLog(@"=== %@ ###",exception.description);
        }
        
        self.pipeNotiObserver = nil;
        self.pipe = nil;
        if(self.logTask != nil){
//            [self.logTask suspend];

            for(int i = 0; i< 30; i++){
                [self.logTask terminate];
            }
        }
        [self killLog];
//        [self.logTask terminate];
    }
}

-(void)killLog{
    NSString * output = [Utility launchTaskFromSh:[NSString stringWithFormat:@"ps -ef | grep %@", _udid]];

    NSLog(@"KILL SWCCC %s -> output (%@)",__FUNCTION__,output);
    output = [output stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    NSArray* arrOut = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    NSMutableArray * arrPid = [NSMutableArray array];
    for( NSString * outputProcessInfos in arrOut ) {
       if( 0 == outputProcessInfos.length )
           continue;

       if( [outputProcessInfos containsString:@"grep "] ) {
           continue;
       }

       NSArray * component = [outputProcessInfos componentsSeparatedByString:@" "];
       NSMutableArray* tempArray = [NSMutableArray array];
       for(NSString* temp in component){
           if(temp.length > 0){
               [tempArray addObject:temp];
           }else{
           }
       }
       if((int)tempArray.count > 3){
           NSString* strPid = [tempArray objectAtIndex:2];
           NSLog(@"strPid = %@",strPid);
           if([strPid isEqualToString:@"1"]){
               strPid = [tempArray objectAtIndex:1];
           }
           if([[tempArray objectAtIndex:7] isEqualToString:@"idevicesyslog"] ){
               strPid = [tempArray objectAtIndex:1];
               NSString * command = [NSString stringWithFormat:@"kill -9 %@", strPid];
               int result = system([command cStringUsingEncoding:NSUTF8StringEncoding]);

               NSLog(@"Kill Device LOG - (%d) ",result);
           }
       }
    }
}

/// @brief Agent (Appium, WebDriverAgent) 종료 시에 로그 출력 종료.
- (void)killLogProcess
{
    self.bLogStarted = NO;
    if([self.logTask isRunning]) {

        __block __typeof__(self) blockSelf = self;
        __block dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

        [self.logTask setTerminationHandler:^(NSTask * task) {
            if( semaphore ) {
                dispatch_semaphore_signal(semaphore);
            }
        }];

        [self.logTask terminate];

//        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, CLOSE_LOG_TASK));
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0f * NSEC_PER_SEC)));
        semaphore = nil;

        if( _pipeHandler ) {
            [_pipeHandler closeHandler];
            _pipeHandler = nil;
        }

        _logTask = nil;
    }
    [self.logTask terminate];
}

/// @brief DeviceConsole 타스크에서 출력된 로그 정보를 파싱함
/// @brief launchedAppInfos Delegate 메소드가 호출 되는데 이 메소드에 수정사항이 있는데.. 아주 중요함 !!!!!
- (void)manageLog : (NSString* )log
{
    __block __typeof__(self) blockSelf = self;
    dispatch_async(_deviceLogQueue, ^{
    
        dispatch_semaphore_wait(_deviceLogSem, DISPATCH_TIME_FOREVER);
        
        NSError * error = nil;
        
        NSString * replaceLog = [log stringByReplacingOccurrencesOfString:@"\r" withString:@""];

        NSArray * logComponents = [replaceLog componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
       
        NSRegularExpression *regex = nil;
        regex = [NSRegularExpression regularExpressionWithPattern:@LINE_REGEX13 options:NSRegularExpressionCaseInsensitive error:&error];

        for( NSString * oneLineLog in logComponents ) {
            
            if( 0 == oneLineLog.length )
                continue;
            
            NSArray *matches = [regex matchesInString:oneLineLog options:0 range:NSMakeRange(0, [oneLineLog length])];
            
//            NSString * date = @"", *device = @"", *process = @"", *pid = @"", *type = @"", *msg = @"";
            NSString  *device = @"", *process = @"", *pid = @"", *type = @"", *msg = @"";
            
            if ([matches count] <= 0){
                type = @"Error";
                msg = oneLineLog;
            } else {
                NSTextCheckingResult * match = [matches lastObject];
//                NSLog(@"log = %@",oneLineLog);
//                NSLog(@"match count = %d",(int)[match numberOfRanges]);
////                NSLog(@"0 = %@",[oneLineLog substringWithRange:[match rangeAtIndex:0]]);
//                NSLog(@"1 = %@",[oneLineLog substringWithRange:[match rangeAtIndex:1]]);
//                NSLog(@"2 = %@",[oneLineLog substringWithRange:[match rangeAtIndex:2]]);
//                NSLog(@"3 = %@",[oneLineLog substringWithRange:[match rangeAtIndex:3]]);
//                NSLog(@"4 = %@",[oneLineLog substringWithRange:[match rangeAtIndex:4]]);
//                NSLog(@"5 = %@",[oneLineLog substringWithRange:[match rangeAtIndex:5]]);
//                NSLog(@"6 = %@",[oneLineLog substringWithRange:[match rangeAtIndex:6]]);
                
//                if ([match numberOfRanges] < 6) {
//                    NSLog(@"##################################");
//                    // 로그 정보를 DC 로 전송한다.
//                    [blockSelf sendLogDataByDate:@"" device:@"" process:@"" pid:@"" type:@"" text:oneLineLog];
//                    continue;
//                }
                NSRange dateRange,deviceRange,processRange,pidRange,typeRange,logRange;
                dateRange    =  [match rangeAtIndex:1];
                processRange =  [match rangeAtIndex:2];
                pidRange     =  [match rangeAtIndex:3];
                typeRange    =  [match rangeAtIndex:4];
                logRange     =  [match rangeAtIndex:5];
                
                date       =  [oneLineLog substringWithRange:dateRange];
                process    =  [oneLineLog substringWithRange:processRange];
                pid        =  [oneLineLog substringWithRange:pidRange];
                type       =  [oneLineLog substringWithRange:typeRange];
                msg        =  [oneLineLog substringWithRange:NSMakeRange(logRange.location, [oneLineLog length] - logRange.location)];
                
//                NSRange dateRange    =  [match rangeAtIndex:1];
//                NSRange deviceRange  =  [match rangeAtIndex:2];
//                NSRange processRange =  [match rangeAtIndex:3];
//                NSRange pidRange     =  [match rangeAtIndex:4];
//                NSRange typeRange    =  [match rangeAtIndex:5];
//                NSRange logRange     =  [match rangeAtIndex:6];
                
//                date       =  [oneLineLog substringWithRange:dateRange];
//                device     =  [oneLineLog substringWithRange:deviceRange];
//                process    =  [oneLineLog substringWithRange:processRange];
//                pid        =  [oneLineLog substringWithRange:pidRange];
//                type       =  [oneLineLog substringWithRange:typeRange];
//                msg        =  [oneLineLog substringWithRange:NSMakeRange(logRange.location, [oneLineLog length] - logRange.location)];
                
                
//                NSRange range = [msg rangeOfString:@"Uncaptured runtime issue reported"];
//
//                if(range.location != NSNotFound){
//                    NSLog(@"SSI BAL CRASH LOG");
//                    // command log restart after 10 seconds
//                    continue;
//                }
                
                if( [msg hasPrefix:@"<private>"] ) {            // <private> 로 시작하는 로그는 로그 메시지가 없어서 걸러줌.
                    continue;
                }
                
                if([process hasPrefix:@"testmanagerd"] || [process hasPrefix:@"com.apple.WebKit.Networking"]){
                    continue;
                }
                
                if([process hasPrefix:@"rtcreportingd"]){
                    continue;
                }
                
                if([process hasPrefix:@"DTServiceHub(DVTInstrumentsFoundation)"]){
                    continue;
                }
                
                if([process hasPrefix:@"WebDriverAgentRunner-Runner(WebDriverAgentLib)"] || [process hasPrefix:@"locationd"]){
                    continue;
                }
                
                if([process hasPrefix:@"SuperPlatform(XCTAutomationSupport)"] || [process hasPrefix:@"duetexpertd(libxpc.dylib)"] || [process hasPrefix:@"dasd(DuetActivitySchedulerDaemon)"]){
                    continue;
                }
                
                if([process hasPrefix:@"ClientResourceMornitor"] || [process hasPrefix:@"backboardd(CoreBrightness)"]){
                    continue;
                }
            
                if([process hasPrefix:@"SuperPlatform"] || [process hasPrefix:@"XCTAutomationSupport"] || [process hasPrefix:@"SpringBoard(XCTAutomationSupport)"] || [process hasPrefix:@"CommCenter"]){
                    continue;
                }
                
                if([process hasPrefix:@"nfcd(libnfshared.dylib)"] || [process hasPrefix:@"bluetoothd"] || [process hasPrefix:@"locationd"] || [process hasPrefix:@"mDNSResponder"] || [process hasPrefix:@"dasd(DuetActivitySchedulerDaemon)"]){
                    continue;
                }
//                Uncaptured runtime issue reported

                
                 if([match numberOfRanges] > 5 && self.bLogStarted == YES){
                     // 로그 정보를 DC 로 전송한다.
//                     NSLog(@"type = %@, msg = %@",type,msg);
//                     NSLog(@"search = %@",self.logSearch);
                     if([self.logSearch isEqualToString:@"*"] ||
                        self.logSearch.length < 1){
                         [blockSelf sendLogDataByDate:date device:device process:process pid:pid type:type text:msg];
                     }else{
                         if([process containsString:self.logSearch] == YES || [msg containsString:self.logSearch] == YES)
                             [blockSelf sendLogDataByDate:date device:device process:process pid:pid type:type text:msg];
//                         if([process containsString:@"testmanagerd"] == NO){
//                             if([process containsString:@"WebDriverAgent"] == NO && [process containsString:self.logSearch] && [msg containsString:self.logSearch]){
//
//                             }
//                         }
                     }
                     // 210727 swccc 로그 재시작
//                     tempMsg = [NSString stringWithFormat:@"%@",msg];
//                     tempProcess = [NSString stringWithFormat:@"%@",process];
                         
                     continue;
                 }
            }
            
            if( 0 == pid.intValue ) {
                continue;
            }

            NSArray * arrMsg = [msg componentsSeparatedByString:@" "];
            if( arrMsg.count < 3 )
                continue;
            
            /// @code 앱이 실행된 시점을 판단하여 전달함.
            if( NSOrderedSame == [@"Activating" compare:[arrMsg objectAtIndex:1]] ) {
                if( NSOrderedSame == [@"<FBProcessWatchdog:" compare:[arrMsg objectAtIndex:2]] ) {
                    if( [blockSelf.customDelegate respondsToSelector:@selector(launchedAppInfos:)] ) {
                        NSLog(@"[#### Info ####] %@", [arrMsg description]);
                        
                        [blockSelf.customDelegate launchedAppInfos:arrMsg];
                    }
                }
            }
            /// @endcode
            
//            NSLog(@"[!!!Debug!!!] %@\t%@\t%@\t%@\t%@\t%@", date, device, process, pid, type, msg);
        }
        dispatch_semaphore_signal(_deviceLogSem);
    });
}

/// @brief DC 로 로그정보를 전달함.
- (void)sendLogDataByDate:(NSString *)date device:(NSString *)device process:(NSString *)process pid:(NSString *)pid type:(NSString *)type text:(NSString *)text {
    
//    DDLogInfo(@"==log(%d) %@, %@, %@, %@, %@, %@==", self.deviceNo, date, device, process, pid, type, text);
    
    if(self.bLogStarted == NO) return;
    
    if (text == nil) {
        return;
    }
    
    if ((([self.logSearch length] == 1) && [self.logSearch isEqualToString:@"*"])
        || [self.logSearch length] == 0) {
        //
    } else {
        if( self.logSearch ) {
//            DDLogInfo(@"==log(%d) %@, %@, %@, %@, %@, %@ , (%@)==", self.deviceNo, date, device, process, pid, type, text , self.logSearch);
            if([text containsString:@"####"]){
                NSLog(@"zzzz");
            }
            //프로세스명과 메시지명을 둘다 검색하여 없을경우 리턴시켜준다.
            @try {
                NSRange the_range = [text rangeOfString:self.logSearch options:NSCaseInsensitiveSearch];
                if (the_range.location == NSNotFound) {
                    if(process != nil && process.length > 0){
                        @try {
                            the_range = [process rangeOfString:self.logSearch options:NSCaseInsensitiveSearch];
                        } @catch (NSException *exception) {
                            NSLog(@"%@",exception.description);
                        }
                        
                        if (the_range.location == NSNotFound) {
                            return;
                        }
                    }
                }
            } @catch (NSException *exception) {
                NSLog(@"%@",exception.description);
            }
           
        }
    }
    
// ========= 순차적 로그레벨.
    char logLevel = 'V';
    int theLogLevel = 0;
    if([type isEqualToString:@"Debug"]){
        theLogLevel = 1;
        logLevel = 'D';
    } else if([type isEqualToString:@"Notice"]){
        theLogLevel = 2;
        logLevel = 'N';
    } else if([type isEqualToString:@"Warning"]){
        theLogLevel = 3;
        logLevel = 'W';
    } else if([type isEqualToString:@"Error"]){
        theLogLevel = 4;
        logLevel = 'E';
    } else {
        theLogLevel = 1;
        logLevel = 'V';
    }
    
    NSString *cut_date = [self stringCutForSize:date size:18];
    NSString *cut_pid = [self stringCutForSize:pid size:5];
    NSString *cut_tid = [self stringCutForSize:@" " size:5];
    NSString *cut_tag = [self stringCutForSize:process size:128];
    NSData* logPacket = [self makeLogPacket:cut_date pid:cut_pid tid:cut_tid level:logLevel tag:cut_tag text:text];
    
    if (logPacket == nil) {
        return;
    }
    if(self.logLevel == theLogLevel || self.logLevel == 0){
        NSData* logPacket = [self makeLogPacket:cut_date pid:cut_pid tid:cut_tid level:logLevel tag:cut_tag text:text];
        
        if (logPacket == nil) {
            return;
        }
        CommunicatorWithDC *theCommDC = [CommunicatorWithDC sharedDCInterface];

        if([self.logIdentifier isEqualToString:@"*"] || (self.logIdentifier.length == 0)){
            //로그 출력이 패키지가 ALL 일 경우 (현재 앱선택 부분이 없으므로 해당 루트를 무조건 탐)
            
            [theCommDC sendLogData:logPacket deviceNo:self.deviceNo];
        } else if([cut_tag hasPrefix:self.logIdentifier] || [self.logIdentifier isEqualToString:@"Safari"]){
            DDLogWarn(@"앱선택하여 로그 출력1 tag = %@ , name = %@",cut_tag,self.appName);
            //로그 출력이 App을 선택하였을 경우
            [theCommDC sendLogData:logPacket deviceNo:self.deviceNo];
        } else{
            DDLogError(@"%@ and %@",self.logIdentifier,self.bundleId);
        }
    }else{
        return;
        
    }
//    CommunicatorWithDC *theCommDC = [CommunicatorWithDC sharedDCInterface];
//    [theCommDC sendLogData:logPacket deviceNo:self.deviceNo];
}

/// @brief 로그 데이터에 들어갈 패킷 만들기.
- (NSData *)makeLogPacket:(NSString *)date pid:(NSString *)pid tid:(NSString *)tid level:(char)level tag:(NSString *)tag text:(NSString *)text {
    
    if ([text length] > 0) {
        
        NSMutableData *temp = [[NSMutableData alloc] init];
        [temp appendData:[date dataUsingEncoding:NSUTF8StringEncoding]];
        [temp appendData:[pid dataUsingEncoding:NSUTF8StringEncoding]];
        [temp appendData:[tid dataUsingEncoding:NSUTF8StringEncoding]];
        [temp appendBytes:&level length:1];
        [temp appendData:[tag dataUsingEncoding:NSUTF8StringEncoding]];
        [temp appendData:[text dataUsingEncoding:NSUTF8StringEncoding]];
        
        NSData *logData = [NSData dataWithData:temp];
        //DDLogInfo(@"==== %d %d====", (int)[logData length], (int)[text length]);
        return logData;
    }
    
    return nil;
}

/// @brief size에 맞게 텍스트 만들기.
- (NSString *)stringCutForSize:(NSString *)str size:(NSInteger)size {
    
    if ([str length] > size) {
        str = [str substringToIndex:size];
    } else if ([str length] < size){
        while ([str length] <size) {
            str = [str stringByAppendingString:@" "];
        }
    }
    
    return str;
}


@end
