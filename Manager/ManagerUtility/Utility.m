//
//  Utility.m
//  Appium
//
//  Created by Dan Cuellar on 3/3/13.
//  Copyright (c) 2013 Appium. All rights reserved.
//

#import "Utility.h"
#import "AppDelegate.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>
#include <assert.h>

#define READ 0
#define WRITE 1

void _BlackHoleTestLogger(NSString *format, ...) {
    
}

/// @brief NSTask 대신 CommandLineTools 를 실행하는 방법
pid_t
popen3(const char *command, int *infp, int *outfp)
{
    int p_stdin[2], p_stdout[2];
    pid_t pid;
    
    if (pipe(p_stdin) != 0 || pipe(p_stdout) != 0)
        return -1;
	
    pid = fork();

    NSLog(@"#%s#",__FUNCTION__);
    NSLog(@"%d",pid);
    NSLog(@"%d",pid);
    NSLog(@"#%s#",__FUNCTION__);
	
    if (pid < 0)
        return pid;
    else if (pid == 0)
    {
        close(p_stdin[WRITE]);
        dup2(p_stdin[READ], READ);
        close(p_stdout[READ]);
        dup2(p_stdout[WRITE], WRITE);
		close(p_stdout[READ]);
		close(p_stdin[WRITE]);
        
        NSLog(@"############");
        NSLog(@"%d",p_stdin[WRITE]);
        NSLog(@"command = %s",command);
        NSLog(@"############");
		
        execl("/bin/sh", "sh", "-c", command, NULL);
        perror("execl");
        exit(1);
    }
	
    if (infp == NULL)
        close(p_stdin[WRITE]);
    else
        *infp = p_stdin[WRITE];
	
    if (outfp == NULL)
        close(p_stdout[READ]);
    else
        *outfp = p_stdout[READ];
	
	close(p_stdin[READ]);
	close(p_stdout[WRITE]);
    return pid;
}


/// @brief  공통으로 사용하는 메소드 모음.
@implementation Utility

/// @brief COSTEP 에서 만든건데 중요하지 않음.
+(NSString*) pathToAndroidBinary:(NSString*)binaryName atSDKPath:(NSString*)sdkPath
{
	NSString *androidHomePath = sdkPath;
	// get the path to $ANDROID_HOME if an sdk path is not supplied
	if (!androidHomePath)
	{
		NSTask *androidHomeTask = [NSTask new];
		[androidHomeTask setLaunchPath:@"/bin/bash"];
		[androidHomeTask setArguments: [NSArray arrayWithObjects: @"-l",
									@"-c", @"echo $ANDROID_HOME", nil]];
		NSPipe *pipe = [NSPipe pipe];
		[androidHomeTask setStandardOutput:pipe];
		[androidHomeTask setStandardError:[NSPipe pipe]];
		[androidHomeTask setStandardInput:[NSPipe pipe]];
		[androidHomeTask launch];
		[androidHomeTask waitUntilExit];
		NSFileHandle *stdOutHandle = [pipe fileHandleForReading];
		NSData *data = [stdOutHandle readDataToEndOfFile];
		[stdOutHandle closeFile];
		androidHomePath = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
	}
	
	// check platform-tools folder
	NSString *androidBinaryPath = [[androidHomePath stringByAppendingPathComponent:@"platform-tools"] stringByAppendingPathComponent:binaryName];
	if ([[NSFileManager defaultManager] fileExistsAtPath:androidBinaryPath])
	{
		return androidBinaryPath;
	}

	// check tools folder
	androidBinaryPath = [[androidHomePath stringByAppendingPathComponent:@"tools"] stringByAppendingPathComponent:binaryName];
	if ([[NSFileManager defaultManager] fileExistsAtPath:androidBinaryPath])
	{
		return androidBinaryPath;
	}
	
	
	
	// check build-tools folders
	NSString *buildToolsDirectory = [androidHomePath stringByAppendingPathComponent:@"build-tools"];
	NSEnumerator* enumerator = [[[[NSFileManager defaultManager] enumeratorAtPath:buildToolsDirectory] allObjects] reverseObjectEnumerator];
	NSString *buildToolsSubDirectory;
	while (buildToolsSubDirectory = [enumerator nextObject])
	{
		buildToolsSubDirectory = [buildToolsDirectory stringByAppendingPathComponent:buildToolsSubDirectory];
		BOOL isDirectory = NO;
		if ([[NSFileManager defaultManager] fileExistsAtPath:buildToolsSubDirectory isDirectory: &isDirectory])
		{
			if (isDirectory) {
				androidBinaryPath = [buildToolsSubDirectory stringByAppendingPathComponent:binaryName];
				if ([[NSFileManager defaultManager] fileExistsAtPath:androidBinaryPath])
				{
					return androidBinaryPath;
				}
			}
		}
	}

	// try using the which command
	NSTask *whichTask = [NSTask new];
    [whichTask setLaunchPath:@"/bin/bash"];
    [whichTask setArguments: [NSArray arrayWithObjects: @"-l",
							  @"-c", [NSString stringWithFormat:@"which %@", binaryName], nil]];
	NSPipe *pipe = [NSPipe pipe];
    [whichTask setStandardOutput:pipe];
	[whichTask setStandardError:[NSPipe pipe]];
    [whichTask setStandardInput:[NSPipe pipe]];
    [whichTask launch];
	[whichTask waitUntilExit];
	NSFileHandle *stdOutHandle = [pipe fileHandleForReading];
    NSData *data = [stdOutHandle readDataToEndOfFile];
	[stdOutHandle closeFile];
    androidBinaryPath = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
	if ([[NSFileManager defaultManager] fileExistsAtPath:androidBinaryPath])
	{
		return androidBinaryPath;
	}

	return nil;
}

/// @brief 타스크를 실행시켜 Output 문자열 리스트를 리턴한다.
/// @return Output 문자열 리스트
+(NSString*) runTaskWithBinary:(NSString*)binary arguments:(NSArray*)args path:(NSString*)path
{
    NSTask *task = [NSTask new];
    if (path != nil)
    {
        [task setCurrentDirectoryPath:path];
    }

    [task setLaunchPath:binary];
    [task setArguments:args];
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    [task setStandardInput:[NSPipe pipe]];

//    MLog(@"Launching %@", binary);
    
    @try {
        [task launch];
    } @catch (NSException *e) {
        DDLogError(@"task error : %@", e.reason);
        
        return nil;//mg//
    }
    
    NSFileHandle *stdOutHandle = [pipe fileHandleForReading];
    NSData *data = [stdOutHandle readDataToEndOfFile];
	[stdOutHandle closeFile];
    NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
	
//    MLog(@"%@ exited with output: %@", binary, output);
	
    return output;
}

/// @brief 중요하지 않음.
+(NSString*) runTaskWithBinaryEnv:(NSString*)binary arguments:(NSArray*)args path:(NSString*)path
{
	NSTask *task = [NSTask new];
	if (path != nil)
	{
		[task setCurrentDirectoryPath:path];
	}
	
	//[task setLaunchPath:binary];
	[task setLaunchPath:@"/bin/bash"];
	
	NSMutableString *commandString = [NSMutableString string];
	[commandString appendFormat:@"cd \"%@\" ; %@", path, binary];

	for( NSString *arg in args) {
		[commandString appendFormat:@" %@", arg];
	}
	
	[task setArguments:[NSArray arrayWithObjects:
						@"-l", @"-c",
						commandString,
						nil]];
	 
	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	[task setStandardInput:[NSPipe pipe]];
	
//    MLog(@"Launching %@", binary);
	
    @try {
        [task launch];
    } @catch (NSException *e) {
        DDLogError(@"task error : %@", e.reason);
        return nil;//mg//
    }
    
	NSFileHandle *stdOutHandle = [pipe fileHandleForReading];
	NSData *data = [stdOutHandle readDataToEndOfFile];
	[stdOutHandle closeFile];
	NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
	
//    MLog(@"%@ exited with output: %@", binary, output);
	
    return output;
}

+(NSString*) runTaskWithBinary:(NSString*)binary arguments:(NSArray*)args
{
    return [self runTaskWithBinary:binary arguments:args path:nil];
}

/// @brief lsof 로 특정 port 번호를 사용하고 있는 Task 의 pid 를 획득 하여 강제로 종료 시킨다.
+(NSNumber*) getPidListeningOnPort:(NSNumber*)port
{
    int fpIn, fpOut;
    char line[1035];
    NSString *lsofCmd = [NSString stringWithFormat: @"/usr/sbin/lsof -t -i :%d", [port intValue]];
    NSLog(@"######################### %s #####################",__FUNCTION__);
    NSLog(@"#### %@ ####",lsofCmd);
    NSLog(@"######################### %s #####################",__FUNCTION__);
    NSNumber *pid = nil;
	pid_t lsofProcPid;

    // open the command for reading
    lsofProcPid = popen3([lsofCmd UTF8String], &fpIn, &fpOut);
    if (lsofProcPid > 0)
    {
        // read the output line by line
        
	    read(fpOut, line, 1035);
        //NSString *lineString = [[NSString stringWithUTF8String:line] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        NSString *readString = [NSString stringWithUTF8String:line];
        NSLog(@"######################### %s #####################",__FUNCTION__);
        NSLog(@"#### %d ####",(int)lsofProcPid);
        NSLog(@"#### %@ ####",readString);
        NSLog(@"######################### %s #####################",__FUNCTION__);

        NSRange range = [readString rangeOfString:@"\n"];
        
        NSString *lineString;
        if( range.length > 0)
            lineString = [readString substringToIndex:range.location];
        else
            lineString = readString;
        
        NSNumberFormatter *f = [NSNumberFormatter new];
        [f setNumberStyle:NSNumberFormatterDecimalStyle];
        NSNumber * myNumber = [f numberFromString:lineString];
        pid = myNumber != nil ? myNumber : pid;
		kill(lsofProcPid, 9);
	}
    return pid;
}

/// @brief 중요하지 않음..
+(NSString*) pathToVBoxManageBinary
{
	NSTask *vBoxManageTask = [NSTask new];
    [vBoxManageTask setLaunchPath:@"/bin/bash"];
    [vBoxManageTask setArguments: [NSArray arrayWithObjects: @"-l",
								   @"-c", @"which vboxmanage", nil]];
	NSPipe *pipe = [NSPipe pipe];
    [vBoxManageTask setStandardOutput:pipe];
	[vBoxManageTask setStandardError:[NSPipe pipe]];
    [vBoxManageTask setStandardInput:[NSPipe pipe]];
    
    @try {
        [vBoxManageTask launch];
    } @catch (NSException *e) {
        DDLogError(@"task error : %@", e.reason);
        return nil;//mg//
    }
    
	[vBoxManageTask waitUntilExit];
	NSFileHandle *stdOutHandle = [pipe fileHandleForReading];
    NSData *data = [stdOutHandle readDataToEndOfFile];
	[stdOutHandle closeFile];
    NSString *vBoxManagePath = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    return vBoxManagePath;
}

/// @brief 원래는 Manager 하나만 있었는데.. COSTEP 업체에 자동화 메니져를 맡기면서 자동화 와 메뉴얼 기능별로 Manager 가 분리됨...  각각의 환경설정을 위해 Manual 폴더를 생성하여 관리함.
+ (NSString *)managerDirectory {
    const char *theHomeDir = getenv("HOME");
	NSString *theManagerDirectory = [NSString stringWithFormat:@"%s/OnycomManager/Manual/", theHomeDir];
	return theManagerDirectory;
}

+ (NSString *)ManualDirectory {
    struct passwd *pw = getpwuid(getuid());
    assert(pw);
    NSString *theManagerDirectory = [NSString stringWithFormat:@"%@/OnycomManager/Manual/", [NSString stringWithUTF8String:pw->pw_dir]];
    return theManagerDirectory;
}

/// @brief  ios-deploy 는 ideviceinstaller 처럼 mac 에서 idevice 에 앱을 설치, 삭제, 정보획득 등의 작업을 할 수 있는 툴임.
+ (NSString *)pathToInstaller {
//    NSString * installerPath = @"/usr/local/bin/ideviceinstaller";
    //NSString *installerPath = [NSString stringWithFormat:@"%@/node_modules/appium/build/libimobiledevice-macosx/ideviceinstaller", [Utility managerDirectory]];
    NSString* installerPath = @"/usr/local/bin/ios-deploy";
    if(![[self cpuHardwareName] isEqualToString:@"x86_64"]){
        installerPath = @"/opt/homebrew/bin/ios-deploy";
    }
    return installerPath;
}

/// @brief 중요하지 않음... idevicesyslog 를 사용하지 않고, deviceconsole 를 사용함.. 근데 둘이 같음..
+ (NSString *)pathToLogger {
    //const char *theHomeDir = getenv("HOME");
    //NSString *loggerPath = [NSString stringWithFormat:@"%s/OnycomManager/deviceconsole", theHomeDir];

    NSString * loggerPath = @"/usr/local/bin/idevicesyslog";
    if(![[self cpuHardwareName] isEqualToString:@"x86_64"]){
        loggerPath = @"/opt/homebrew/bin/ios-deploy";
    }
    return loggerPath;
}

/// @brief WebDriverAgent 의 기본경로.
+ (NSString *) pathToWebDriverAgent {
    return @"/usr/local/lib/node_modules/appium/node_modules/appium-xcuitest-driver/WebDriverAgent/";
//    return @"/Users/onycom/Downloads/WebDriverAgent-master";
//    return @"/Users/mac0516/OnycomManager/WebDriverAgent";
}

/// @brief lsof 로 특정 port 번호를 사용하고 있는 Task 의 pid 를 획득 하여 강제로 종료 시킨다. 이 클래스 메소드를 주로 사용함..
+ (void) killListenPort:(int)port exceptPid:(int)exceptPid {
    // /bin/bash -l -c "PID=`lsof -t -i TCP:4724` kill -9 '$PID'"
    NSLog(@"########################################################################");
    NSLog(@"%s and %d and exception = %d",__FUNCTION__,port,exceptPid);
    NSLog(@"########################################################################");
    // kill any processes using the appium server port
    {
        NSNumber *procPid;
        int nMax = 8;
//        while( nMax-- > 0 && (procPid = [Utility getPidListeningOnPort:[NSNumber numberWithInt:port]]) != nil)
        while( nMax-- > 0 )
        {
            procPid = [Utility getPidListeningOnPort:[NSNumber numberWithInt:port]];
            if (procPid != nil && exceptPid != [procPid intValue])
            {
                NSLog(@"########################################################################");
                NSLog(@"Listen port(%d) is already occupied.:PID(%d)",port, [procPid intValue]);
                NSLog(@"Killing previous listen process");
                NSLog(@"########################################################################");
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
        }
    }
    
}

/// @brief 프로세스 이름으로 프로세스를 종료함.
+ (void) killProcessByName:(NSString*)processName
{
//    MVLog(@"killProcess:%@", processName);
    @try
    {
        NSString *script = [NSString stringWithFormat:@"killall -SIGKILL -z %@", processName];
        system([script UTF8String]);
    }
    @catch (NSException *exception)
    {
//        MVLog(@"%@", exception.description);
    }
}

/*
 level:
 #define LOG_APPIUM          0x01
 #define LOG_APPIUM_ERR      0x02
 #define LOG_APPIUM_VERBOSE  0x04
 #define LOG_MANAGER         0x08
 #define LOG_MANAGER_ERR     0x10
 #define LOG_MANAGER_VERBOSE 0x20
 #define LOG_IOS             0x40
 #define LOG_UNKNOWN1        0x80
 
    30: whiteColor
    31: redColor
    32: greenColor
    33: yellowColor
    34: blueColor
    35: magentaColor
    36: cyanColor
    37: whiteColor
    39: whiteColor
 */


/// @brief COSTEP에서 만든 로그 함수
+(void) MLog:(int)level formats:(NSString*)format, ...
{
    if( format == nil || [format length] == 0)
        return;
    
    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyMMddHHmmss"];

    
    NSString* logTitle;
    if( level == LOG_APPIUM)  // Appium log
    {
        logTitle = [NSString stringWithFormat:@"%@:\x1b[34m[APPIUM] %@\x1b[39m", [dateFormatter stringFromDate:[NSDate date]], format];
    }
    else if( level == LOG_APPIUM_ERR) // Appium error log
    {
        logTitle = [NSString stringWithFormat:@"%@:\x1b[31m[APPIUM_ERR] %@\x1b[39m", [dateFormatter stringFromDate:[NSDate date]], format];
    }
    else if( level == LOG_APPIUM_VERBOSE) // manager log verbose
    {
        logTitle = [NSString stringWithFormat:@"%@:\x1b[37m[APPIUM_VERBOSE] %@\x1b[39m", [dateFormatter stringFromDate:[NSDate date]], format];
    }
    else if( level == LOG_MANAGER) // manager log
    {
        logTitle = [NSString stringWithFormat:@"%@:\x1b[33m[MANAGER] %@\x1b[39m", [dateFormatter stringFromDate:[NSDate date]], format];
    }
    else if( level == LOG_MANAGER_ERR) // manager error
    {
        logTitle = [NSString stringWithFormat:@"%@:\x1b[31m[MANAGER_ERR] %@\x1b[39m", [dateFormatter stringFromDate:[NSDate date]], format];
    }
    else if( level == LOG_MANAGER_VERBOSE) // manager log verbose
    {
        logTitle = [NSString stringWithFormat:@"%@:\x1b[37m[MANAGER_VERBOSE] %@\x1b[39m", [dateFormatter stringFromDate:[NSDate date]], format];
    }
    else if( level == LOG_IOS) // IOS LOG
    {
        logTitle = [NSString stringWithFormat:@"%@:\x1b[35m[IOS] %@\x1b[39m", [dateFormatter stringFromDate:[NSDate date]], format];
    }
    else if( level == LOG_SOCKET) // SCOKET
    {
        logTitle = [NSString stringWithFormat:@"%@:\x1b[34m[SOCKET] %@\x1b[39m", [dateFormatter stringFromDate:[NSDate date]], format];
    }
    else { // UNKNOWN
        logTitle = [NSString stringWithFormat:@"%@:\x1b[37m[ETC] %@\x1b[39m", [dateFormatter stringFromDate:[NSDate date]], format];
    }
    
    va_list args;
    va_start(args, format);
    NSString* logString = [[NSString alloc] initWithFormat:logTitle arguments:args];
    va_end(args);
    
    AppDelegate *appDel = [[NSApplication sharedApplication]delegate];
    
//    if( appDel.mainVC != nil)
//    {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [[appDel mainVC] appendToLogNormal:level log:logString];
//        });
//    }
}

/// @brief 중요하지 않음.
+ (NSString *)GetBuildString {
    NSString *buildDate;
    
    // Get build date and time, format to 'yyMMddHHmm'
    NSString *dateStr = [NSString stringWithFormat:@"%@ %@", [NSString stringWithUTF8String:__DATE__], [NSString stringWithUTF8String:__TIME__]];
    
    // Convert to date
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"LLL d yyyy HH:mm:ss"];
    [dateFormat setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US"]];
    NSDate *date = [dateFormat dateFromString:dateStr];
    
    // Set output format and convert to string
    [dateFormat setDateFormat:@"yyMMddHHmm"];
    buildDate = [dateFormat stringFromDate:date];
    
    return buildDate;
}

/// @brief 중요하지 않음.
+ (NSDate *)GetBuildDate {
    
    // Get build date and time, format to 'yyMMddHHmm'
    NSString *dateStr = [NSString stringWithFormat:@"%@ %@", [NSString stringWithUTF8String:__DATE__], [NSString stringWithUTF8String:__TIME__]];
    
    // Convert to date
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"LLL d yyyy HH:mm:ss"];
    [dateFormat setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US"]];
    NSDate *date = [dateFormat dateFromString:dateStr];
    
    return date;
}

/// @brief 중요하지 않음.
+ (NSString *)getSerialNumber
{
    NSString *serial = nil;
    io_service_t platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                              IOServiceMatching("IOPlatformExpertDevice"));
    if (platformExpert) {
        CFTypeRef serialNumberAsCFString =
        IORegistryEntryCreateCFProperty(platformExpert,
                                        CFSTR(kIOPlatformSerialNumberKey),
                                        kCFAllocatorDefault, 0);
        if (serialNumberAsCFString) {
            serial = CFBridgingRelease(serialNumberAsCFString);
        }
        
        IOObjectRelease(platformExpert);
    }
    return serial;
}


+ (NSString *)deviceVersion{
    NSString* output;
    @try
    {
        // Set up the process
        NSTask *t = [[NSTask alloc] init];
        [t setLaunchPath:@"/usr/local/bin/ideviceinfo"];
        [t setArguments:[NSArray arrayWithObjects:@"-k", @"ProductVersion", nil]];
        
        // Set the pipe to the standard output and error to get the results of the command
        NSPipe *p = [[NSPipe alloc] init];
        [t setStandardOutput:p];
        [t setStandardError:p];
        
        // Launch (forks) the process
        [t launch]; // raises an exception if something went wrong
        
        // Prepare to read
        NSFileHandle *readHandle = [p fileHandleForReading];
        NSData *inData = nil;
        NSMutableData *totalData = [[NSMutableData alloc] init];
        
        while ((inData = [readHandle availableData]) &&
               [inData length]) {
            [totalData appendData:inData];
        }
        
        // Polls the runloop until its finished
        [t waitUntilExit];
        
        
        NSLog(@"Terminationstatus: %d", [t terminationStatus]);
        NSLog(@"Data recovered: %@", totalData);
        
        output = [[NSString alloc] initWithData:totalData encoding: NSUTF8StringEncoding];
        [readHandle closeFile];
        
    }
    @catch (NSException *e)
    {
        NSLog(@"2 Expection occurred %@", [e reason]);
        
    }
    output = [output stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    
    return output;
}

/// @brief 문자열을 토큰단위로 분쇄함.. TextInput 에 사용함.  iOS 9.x 이하 버전에서 TextInput 을 할때 한글은 문자로 입력하면 들어가지 않았음..
+ (NSString *)getHangulDecomposition:(NSString *)hangul{
    NSString *countryCode = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    
    if( NSOrderedSame == [countryCode compare:@"KR"] ) {
        
        NSArray * chosung  = [[NSArray alloc] initWithObjects:@"ㄱ",@"ㄲ",@"ㄴ",@"ㄷ",@"ㄸ",@"ㄹ",@"ㅁ",@"ㅂ",@"ㅃ",@"ㅅ",@" ㅆ",@"ㅇ",@"ㅈ",@"ㅉ",@"ㅊ",@"ㅋ",@"ㅌ",@"ㅍ",@"ㅎ",nil] ;
        NSArray * jungsung = [[NSArray alloc] initWithObjects:@"ㅏ",@"ㅐ",@"ㅑ",@"ㅒ",@"ㅓ",@"ㅔ",@"ㅕ",@"ㅖ",@"ㅗ",@"ㅘ",@" ㅙ",@"ㅚ",@"ㅛ",@"ㅜ",@"ㅝ",@"ㅞ",@"ㅟ",@"ㅠ",@"ㅡ",@"ㅢ",@"ㅣ",nil] ;
        NSArray * jongsung = [[NSArray alloc] initWithObjects:@"",@"ㄱ",@"ㄲ",@"ㄳ",@"ㄴ",@"ㄵ",@"ㄶ",@"ㄷ",@"ㄹ",@"ㄺ",@"ㄻ",@" ㄼ",@"ㄽ",@"ㄾ",@"ㄿ",@"ㅀ",@"ㅁ",@"ㅂ",@"ㅄ",@"ㅅ",@"ㅆ",@"ㅇ",@"ㅈ",@"ㅊ",@"ㅋ",@" ㅌ",@"ㅍ",@"ㅎ",nil] ;
        
        NSMutableString * textResult = [NSMutableString stringWithString:@""] ;
        for (int i=0; i<[hangul length]; i++) {
            NSInteger code = [hangul characterAtIndex:i] ;
            if (code >= 44032 && code <= 55203) {
                NSInteger uniCode = code - 44032 ;
                NSInteger chosungIndex = uniCode / 21 / 28 ;
                NSInteger jungsungIndex = uniCode % (21 * 28) / 28 ;
                NSInteger jongsungIndex = uniCode % 28 ;
                [textResult appendString:[NSString stringWithFormat:@"%@%@%@",
                                          [chosung objectAtIndex:chosungIndex],
                                          [jungsung objectAtIndex:jungsungIndex],
                                          [jongsung objectAtIndex:jongsungIndex]]] ;
            } else {
                if( [hangul length] < i) {
                    DDLogInfo(@"hangul data length is small");
                    break;
                }
                [textResult appendString:[hangul substringWithRange:NSMakeRange(i, 1)]] ;
            }
        }
        return textResult ;
    }
    
    return hangul;
}

/// @brief 타스크를 실행하여 Output 문자열리스트를 얻어서 리턴함.. 그닥 중요하지않음.. 초창기 코드는 사용했던거 같은데.. 타스크에 environment 를 설정해서 사용하느게 좋은방법은 아님.. \
/// @brief 타스크를 사용하는 다른 방법이 launchTaskFromBash 메소드에 있으니 참고하시길..
+ (NSString *)launchTask:(NSString *)launchPath arguments:(NSArray *)arguments {
    __block NSTask * taskIdevice = [[NSTask alloc] init];
    taskIdevice.environment = [NSDictionary dictionaryWithObjectsAndKeys:@"/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin", @"PATH", nil];
    [taskIdevice setLaunchPath:launchPath];
    [taskIdevice setArguments:arguments];
    
    NSPipe *pipe= [NSPipe pipe];
    [taskIdevice setStandardOutput: pipe];
    
    NSFileHandle *file = [pipe fileHandleForReading];
    
    if( [NSThread isMainThread] ) {
        [taskIdevice launch];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^(void){
            [taskIdevice launch];
        });
    }
    
    NSData *data = [file readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    [file closeFile];
    
    taskIdevice.terminationHandler = ^(NSTask *task){
        taskIdevice = nil;
    };
    
    // Terminate 후 정리되는걸 기다릴 필요가 없다.
    [taskIdevice terminate];
    
    return output;
}


+ (NSString *) launchTaskFromSh:(NSString *)commandString{
    NSTask *task = [NSTask new];

    task.launchPath = @"/bin/sh";
//    task.arguments = @[@"-c", @"ps -ax | grep /usr/bin/xcodebuild"];
    task.arguments = @[@"-c", commandString];

    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;

    NSFileHandle *file = [pipe fileHandleForReading];

    [task launch];

    NSData *data = [file readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    
    return output;
}


//+ (NSString *) launchTaskFromSh:(NSString *)commandString{
//    NSPipe* outPipe = [NSPipe pipe];
//    NSPipe* errPipe = [NSPipe pipe];
//
//    __block dispatch_semaphore_t resourceMornitorSem = dispatch_semaphore_create(0);
//    NSString* path = @"/bin/sh";
//
//    NSUserUnixTask* unixTask = [[NSUserUnixTask alloc] initWithURL:[NSURL fileURLWithPath:path] error:nil];
//    NSArray* argArray  = [NSArray arrayWithObjects:
//                           @"-l", @"-c",
//                           commandString,
//                           nil];
//
//
//    [unixTask setStandardOutput:[outPipe fileHandleForWriting]];
//    [unixTask setStandardError:[errPipe fileHandleForWriting]];
//    __block NSString * output = nil;
//    [unixTask executeWithArguments:argArray completionHandler:^(NSError *error) {
//        output = [[NSString alloc] initWithData: [[outPipe fileHandleForReading] readDataToEndOfFile] encoding: NSUTF8StringEncoding];
//        NSLog(@"stdout: %@", output);
//
//       NSString *error1 = [[NSString alloc] initWithData: [[errPipe fileHandleForReading] readDataToEndOfFile] encoding: NSUTF8StringEncoding];
//       NSLog(@"stderr: %@", error1);
//        dispatch_semaphore_signal(resourceMornitorSem);
//    }];
//    dispatch_semaphore_wait(resourceMornitorSem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0f *NSEC_PER_SEC)));
//    return output;
//}

/// @brief 타스크를 실행하여 Output 문자열리스트를 얻어서 리턴함.. 위의 방법보단 더 좋은 방식임..
+ (NSString *) launchTaskFromBash:(NSString *)commandString {
//    NSLog(@"command = %@",commandString);
//    @autoreleasepool {
//        NSTask * testTask = [[NSTask alloc] init];
//        testTask.launchPath = @"/bin/bash";
//
//        testTask.arguments  = [NSArray arrayWithObjects:
//                               @"-l", @"-c",
//                               commandString,
//                               nil];
//
//
//        NSPipe *pipe = [NSPipe pipe];
//        [testTask setStandardOutput: pipe];
//        NSFileHandle *file = [pipe fileHandleForReading];
//
//        __block BOOL bLaunch = YES;
//        __block NSError * error = nil;
//        if( [NSThread isMainThread] ) {
//
//            if (@available(macOS 10.13, *)) {
//                bLaunch = [testTask launchAndReturnError:&error];
//            } else {
//                [testTask launch];
//            }
//
//        } else {
//            dispatch_sync(dispatch_get_main_queue(), ^(void){
//                if (@available(macOS 10.13, *)) {
//                    bLaunch = [testTask launchAndReturnError:&error];
//                } else {
//                    [testTask launch];
//                }
//            });
//        }
//        if(error == nil){
//            if(bLaunch){
//                NSData *data = [file readDataToEndOfFile];
//                NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
//                [file closeFile];
//
//                return output;
//            }else{
//                [file closeFile];
//                return nil;
//            }
//        }else{
//            NSLog(@"%s error = %@",__FUNCTION__,error.description);
//
//            [file closeFile];
//            [Utility restartCheck];
//            return nil;
//        }
//    }
    
    NSPipe* outPipe = [NSPipe pipe];
    NSPipe* errPipe = [NSPipe pipe];

//    NSTask * testTask = [[NSTask alloc] init];
//    testTask.launchPath = @"/bin/bash";
    __block dispatch_semaphore_t resourceMornitorSem = dispatch_semaphore_create(0);
    NSString* path = @"/bin/bash";
    
    NSUserUnixTask* unixTask = [[NSUserUnixTask alloc] initWithURL:[NSURL fileURLWithPath:path] error:nil];
    NSArray* argArray  = [NSArray arrayWithObjects:
                           @"-l", @"-c",
                           commandString,
                           nil];
    
    
    [unixTask setStandardOutput:[outPipe fileHandleForWriting]];
    [unixTask setStandardError:[errPipe fileHandleForWriting]];
    __block NSString * output = nil;
    [unixTask executeWithArguments:argArray completionHandler:^(NSError *error) {
        output = [[NSString alloc] initWithData: [[outPipe fileHandleForReading] readDataToEndOfFile] encoding: NSUTF8StringEncoding];
        NSLog(@"stdout: %@", output);

       NSString *error1 = [[NSString alloc] initWithData: [[errPipe fileHandleForReading] readDataToEndOfFile] encoding: NSUTF8StringEncoding];
       NSLog(@"stderr: %@", error1);
        dispatch_semaphore_signal(resourceMornitorSem);
    }];
    dispatch_semaphore_wait(resourceMornitorSem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0f *NSEC_PER_SEC)));
    return output;
}

// YES : 특수문자를 포함하고있음
// NO  : 특수문자를 포함하고 있지 않음
+ (BOOL)checkValidateString:(NSString *)string{
    
    if(!string){
        return YES;
    }
    NSLog(@"######## %@ ########",string);
    
    NSString *ptn = @"^[\\sㄱ-ㅎㅏ-ㅣa-zA-Z0-9가-힣.,<>?/'\"~*&(){}|_`:;!@#$%^*+=\\-\\[\\]\\\\ㆍ]*$";
    NSRange checkRange = [string rangeOfString:ptn options:NSRegularExpressionSearch];

    if(checkRange.length == 0){ //특수문자
        NSLog(@"특수문자1");
        return NO;
        
    }else{
        NSLog(@"특수문자2");
        return YES;
        
    }
}


//+ (void) restartManager {
//    DDLogError(@"1%s", __FUNCTION__);
//    
//    NSString* mgr = nil;
//    
//    NSArray* array = [[[NSBundle mainBundle] bundlePath] componentsSeparatedByString:@"/"];
//    int nTotalCount = (int)[array count];
//    NSString* appName = [array objectAtIndex:nTotalCount-1];
//    DDLogInfo(@"AppName = %@",appName);
//    if([appName isEqualToString:@"Manager.app"]){
//        mgr = [NSString stringWithFormat:@"%@Manager2.app", [Utility managerDirectory]];
//    }else{
//        mgr = [NSString stringWithFormat:@"%@Manager.app", [Utility managerDirectory]];
//    }
//    
//    [[NSWorkspace sharedWorkspace] launchApplication:mgr];
////    exit(0);
//    DDLogError(@"%s", __FUNCTION__);
//}

//+ (void)restartManager:(int)nIndex{
+ (void)restartManager{
    NSString* path = [[NSBundle mainBundle] executablePath];
    NSTask* restartTask = [[NSTask alloc] init];
    restartTask.launchPath = path;
    [restartTask launch];
    
    [[NSApplication sharedApplication] terminate:nil];
    
}

+(void)restartCheck{
    BOOL bRestart = [[NSUserDefaults standardUserDefaults] boolForKey:MANAGERRESTART];
    if(bRestart){
        [self restartManager];
        [self performSelectorInBackground:@selector(exitManager) withObject:nil];
        exit(0);
    }
}

-(void)exitManager{
    exit(0);
}

+ (NSString *) cpuHardwareName{
    struct utsname sysinfo;
    int retVal = uname(&sysinfo);
    if(EXIT_SUCCESS != retVal) return nil;
    
    return [NSString stringWithUTF8String:sysinfo.machine];
}

@end
