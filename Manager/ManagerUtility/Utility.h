//
//  Utility.h
//  Appium
//
//  Created by Dan Cuellar on 3/3/13.
//  Copyright (c) 2013 Appium. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sys/utsname.h>

#define DEFAULTS [NSUserDefaults standardUserDefaults]

@interface Utility : NSObject
+(NSString*) pathToAndroidBinary:(NSString*)binaryName atSDKPath:(NSString*)sdkPath;
+(NSString*) runTaskWithBinary:(NSString*)binary arguments:(NSArray*)args path:(NSString*)path;
+(NSString*) runTaskWithBinaryEnv:(NSString*)binary arguments:(NSArray*)args path:(NSString*)path;
+(NSString*) runTaskWithBinary:(NSString*)binary arguments:(NSArray*)args;
+(NSNumber*) getPidListeningOnPort:(NSNumber*)port;
+(NSString*) pathToVBoxManageBinary;
+(NSString*) managerDirectory;
+(NSString *)ManualDirectory;
+(NSString*) pathToInstaller;
+(NSString *)pathToLogger;
+(NSString *)pathToWebDriverAgent;

+ (void) killListenPort:(int)port exceptPid:(int)exceptPid;
+ (void) killProcessByName:(NSString*)processName;
+ (NSString *)GetBuildString;
+ (NSDate *)GetBuildDate;
+ (NSString *)getSerialNumber;

+ (NSString *)getHangulDecomposition:(NSString *)hangul;

+ (NSString *)launchTask:(NSString *)launchPath arguments:(NSArray *)arguments;

+ (NSString *) launchTaskFromSh:(NSString *)commandString;
+ (NSString *) launchTaskFromBash:(NSString *)commandString;
//특수문자 포함여부 확인
+ (BOOL)checkValidateString:(NSString* )string;

+ (NSString *)deviceVersion;
+ (void) restartManager;
+ (void)restartCheck;

// CPU의 제품체크
+ (NSString *) cpuHardwareName;

//+ (void)restartManager:(int)nIndex;

#define LOG_APPIUM          0x01
#define LOG_APPIUM_ERR      0x02
#define LOG_APPIUM_VERBOSE  0x04
#define LOG_MANAGER         0x08
#define LOG_MANAGER_ERR     0x10
#define LOG_MANAGER_VERBOSE 0x20
#define LOG_IOS             0x40
#define LOG_SOCKET          0x80

+(void) MLog:(int)level formats:(NSString*)format, ...;
@end
