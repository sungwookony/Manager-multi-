//
//  AppInstaller.m
//  Manager
//
//  Created by SR_LHH_MAC on 2017. 8. 11..
//  Copyright © 2017년 tomm. All rights reserved.
//

#import "AppInstaller.h"


/**
 *  @file       AppInstaller.m
 *  @brief      idevice 에 ipa 파일을 설치한다.  삭제하는 기능을 넣어두는게 맞지만.. 안했음..
 *  @details    DC 로 전달받은 URL 로 ipa 파일을 다운로드, idevice 에 install 기능이 있음.
 * author       이훈희 (SR_LHH_MAC)
 */




#pragma makr - <AppInstaller>
@implementation AppInstaller

/// @brief ideviceinstaller 는 XCode9.x 에서 AdHoc 으로 앱을 만들었을때, Complete 가 떨어지지 않는 경우가 있음. (ideviceinstaller 을 업데이트 해야 할지도..)
/// @brief 해당 문제를 펄어비스에 방문하여 테스트 하다 발견해서... 급하게 처리하느라 Complete 가 떨어지지 않아도 성공이 되도록 예외 처리를 함.
+ (void) asyncIDeviceInstaller:(NSString *)appPath withUDID:(NSString *)udid completion:(void (^)(BOOL successed, NSString * description))block {
    
//    dispatch_queue_t asyncURLConnectionQueue = dispatch_queue_create("asyncURLConnection", NULL);                 // AppInstaller 을 호출한 객체에 종속됨...
    dispatch_queue_t asyncURLConnectionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);     // Global 이기 때문에 Http Module 을 호출한 객체와 분리됨..
    dispatch_async(asyncURLConnectionQueue, ^(void) {                                                               // 따라서 Http Module 을 호출한 객체가 소멸되어도 별도로 동작을 하기 때문에 안전함..
        @autoreleasepool {
            DDLogWarn(@"install path %@", appPath);
            __block NSTask * installTaks = [[NSTask alloc] init];
            installTaks.environment = [NSDictionary dictionaryWithObjectsAndKeys:@"/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin", @"PATH", nil];
            [installTaks setLaunchPath: @"/usr/local/bin/ideviceinstaller"];
            [installTaks setArguments: @[@"-i", appPath, @"-u", udid]];
            
            
            NSPipe *pipe= [NSPipe pipe];
            [installTaks setStandardOutput: pipe];
            NSFileHandle *file = [pipe fileHandleForReading];
            
            NSPipe * errorPipe = [NSPipe pipe];
            [installTaks setStandardError:errorPipe];
            NSFileHandle * errorFile = [errorPipe fileHandleForReading];
            
            //mg//[installTaks launch];
            //mg//s
            if( [NSThread isMainThread] ) {
                [installTaks launch];
            } else {
                dispatch_sync(dispatch_get_main_queue(), ^(void){
                    [installTaks launch];
                });
            }
            //mg//e
            
            NSData * errorData = [errorFile readDataToEndOfFile];
            NSString * errorOutput = [[NSString alloc] initWithData:errorData encoding: NSUTF8StringEncoding];
            [errorFile closeFile];
            
            installTaks.terminationHandler = ^(NSTask *task){
                // do things after completion
                DDLogWarn(@"%s : terminate myInstallTaks", __FUNCTION__);
                installTaks = nil;
            };
            
            DDLogWarn(@"Error Output : %@", errorOutput);
            errorOutput = [errorOutput stringByReplacingOccurrencesOfString:@"\r" withString:@""];
            NSArray* arrErrorOut = [errorOutput componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            
            if( arrErrorOut.count != 0 ) {
                for(NSString* tmp in arrErrorOut) {
                    if( 0 == tmp.length )
                        continue;
                    
                    if( [[tmp lowercaseString] hasPrefix:@"error:"] ) {
                        // 어플 설치 오류 발생.
                        DDLogError(@"out error %@", tmp);
                        NSString* result = [[tmp componentsSeparatedByString:@"- Error occurred:"] lastObject];
                        DDLogError(@"-----error result %@", result);
                        
                        result = [NSString stringWithFormat:@"앱 설치오류 = %@",result];
                        block(NO, result);
                        
//                        [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:NO appId:result deviceNo:_deviceInfos.deviceNo];
                        return ;
                    }
                }
            }
            
            NSData *data = [file readDataToEndOfFile];
            NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
            [file closeFile];
            
            DDLogWarn(@"output %@", output);
            
            output = [output stringByReplacingOccurrencesOfString:@"\r" withString:@""];
            NSArray* arrOut = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            NSString* installAppId = nil;
            
            
            NSLog(@"result output : \n\n%@\n\n", arrOut);
            
            [installTaks terminate];
            
            if (output == nil || [output isEqualToString:@""] || [output isEqual:[NSNull null]]) {
                DDLogError(@"install fail");
//                self.installPath = nil;
//                [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:NO appId:@"설치 실패" deviceNo:_deviceInfos.deviceNo];
                block(NO, @"설치 실패");
            } else {
                for(NSString* tmp0 in arrOut)
                {
                    if( 0 == tmp0.length )
                        continue;
                    
                    NSString * tmp = [tmp0 lowercaseString];
                    
                    if( [tmp hasPrefix:@"installing"] ) {
                        
                        NSArray * tmpArray = [tmp componentsSeparatedByString:@" "];
                        NSString * tmpbundleID = [tmpArray objectAtIndex:1];
                        NSString * bundleID = [tmpbundleID substringWithRange:NSMakeRange(1, tmpbundleID.length -2)];
                        
                        DDLogWarn(@"\n\n\n\n[#### Info ####] install bundleid : %@ \n\n\n\n", bundleID);
                        
                        continue;
                    }
                    
                    
                    if( [tmp containsString:@" error occurred:"]){
                        
                        // 어플 설치 오류 발생.
                        DDLogError(@"out error %@", tmp0);
                        NSString* result = [[tmp componentsSeparatedByString:@"- error occurred:"] lastObject];
                        DDLogError(@"-----error result %@", result);
                        result = [NSString stringWithFormat:@"앱 설치오류 = %@",result];
                        
//                        [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:NO appId:result deviceNo:_deviceInfos.deviceNo];
                        block(NO, result);
                        
                        return ;
                    }
                    else if ([tmp hasSuffix:@" complete"]) {
                        // 어플 설치 성공.
                        DDLogWarn(@"install success");
                        block(YES, nil);
                        return ;
                    }
                }
                
                // ideviceinstaller 로 인스톨을 했을때, Complete 가 안되는 경우가 있음.. (90% 이상에서 "segmentation fault: 11" 이 발생함.. 하지만 앱은 설치가 되었으며, 실행도 가능함.  "brew install -g ideviceinstaller" 또는 "brew install -g ideviceinstaller --HEAD" 로 설치를 해도 마찬가지임.. ideviceinstaller 가 외부요인에 의해 불안정적으로 동작을 하기 때문에 좀더 안정적인 ios-deploy 로 동작시키는것이 좋을거 같음..)
                // 뭐 어쨌든 여기 까지 들어온건.. 성공한 거라 볼수 있어서.. 성공을 리턴함..
                DDLogWarn(@"install success -- Segmentation fault: 11");
                block(YES, nil);
                return ;
            }
        }
    });
}

//mg//return : result message, nil in case success
/*+ (NSString *) ideviceInstaller:(NSString *)appPath withUDID:(NSString *)udid {
    DDLogDebug(@"%s %@", __FUNCTION__, appPath);
    
        @autoreleasepool {
            __block NSTask * installTaks = [[NSTask alloc] init];
            installTaks.environment = [NSDictionary dictionaryWithObjectsAndKeys:@"/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin", @"PATH", nil];
            [installTaks setLaunchPath: @"/usr/local/bin/ideviceinstaller"];
            [installTaks setArguments: @[@"-i", appPath, @"-u", udid]];
            
            NSPipe *pipe= [NSPipe pipe];
            [installTaks setStandardOutput: pipe];
            NSFileHandle *file = [pipe fileHandleForReading];
            
            NSPipe * errorPipe = [NSPipe pipe];
            [installTaks setStandardError:errorPipe];
            NSFileHandle * errorFile = [errorPipe fileHandleForReading];
            
            @try {
                [installTaks launch];
            } @catch (NSException *e){
                return e.reason;
            }
            
            NSData * errorData = [errorFile readDataToEndOfFile];
            NSString * errorOutput = [[NSString alloc] initWithData:errorData encoding: NSUTF8StringEncoding];
            [errorFile closeFile];
            
            installTaks.terminationHandler = ^(NSTask *task){
                // do things after completion
                DDLogVerbos(@"ideviceinstaller terminated");
                installTaks = nil;
            };
            
            errorOutput = [errorOutput stringByReplacingOccurrencesOfString:@"\r" withString:@""];
            NSArray* arrErrorOut = [errorOutput componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            
            if( arrErrorOut.count != 0 ) {
                for(NSString* tmp in arrErrorOut) {
                    if( 0 == tmp.length )
                        continue;
                    
                    if( [[tmp lowercaseString] hasPrefix:@"error:"] ) {
                        // 어플 설치 오류 발생.
                        DDLogError(@"install error : %@", tmp);
                        NSString* result = [[tmp componentsSeparatedByString:@"- Error occurred:"] lastObject];
                        return result;
                    }
                }
            }
            
            NSData *data = [file readDataToEndOfFile];
            NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
            [file closeFile];
            
            DDLogDebug(@"output : %@", output);
            
            output = [output stringByReplacingOccurrencesOfString:@"\r" withString:@""];
            NSArray* arrOut = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            
            [installTaks terminate];
            
            if (output == nil || [output isEqualToString:@""] || [output isEqual:[NSNull null]]) {
                DDLogError(@"install error : no result");
                return @"no result";
            } else {
                for(NSString* tmp0 in arrOut) {
                    if( 0 == tmp0.length )
                        continue;
                    
                    NSString * tmp = [tmp0 lowercaseString];
                    
                    if( [tmp hasPrefix:@"installing"] ) {
                        NSArray * tmpArray = [tmp componentsSeparatedByString:@" "];
                        NSString * tmpbundleID = [tmpArray objectAtIndex:1];
                        NSString * bundleID = [tmpbundleID substringWithRange:NSMakeRange(1, tmpbundleID.length -2)];
                        
                        DDLogInfo(@"bundle id : %@", bundleID);
                        continue;
                    }
                    
                    if( [tmp containsString:@" error occurred:"]){
                        // 어플 설치 오류 발생.
                        DDLogError(@"install error : %@", tmp0);
                        NSString* result = [[tmp componentsSeparatedByString:@"- error occurred:"] lastObject];
                        
                        return result;
                    } else if ([tmp hasSuffix:@" complete"]) {
                        // 어플 설치 성공.
                        DDLogInfo(@"install success");
                        
                        return nil;
                    }
                }//for : output
                
                // ideviceinstaller 로 인스톨을 했을때, Complete 가 안되는 경우가 있음.. (90% 이상에서 "segmentation fault: 11" 이 발생함.. 하지만 앱은 설치가 되었으며, 실행도 가능함.  "brew install -g ideviceinstaller" 또는 "brew install -g ideviceinstaller --HEAD" 로 설치를 해도 마찬가지임.. ideviceinstaller 가 외부요인에 의해 불안정적으로 동작을 하기 때문에 좀더 안정적인 ios-deploy 로 동작시키는것이 좋을거 같음..)
                // 뭐 어쨌든 여기 까지 들어온건.. 성공한 거라 볼수 있어서.. 성공을 리턴함..
                DDLogInfo(@"install success : check");
                return nil;
            }//if - else : output
        }//autoreleasepool
}//ideviceInstaller
 */

/// @brief ios-deploy 로 인스톨 함.
/// @brief ios-deploy 는 ideviceinstaller 가 문제를 발생시키는 상황에서도 안정적으로 동작함. 하지만, appName 을 얻을 수 있는 방법이 없으므로 ideviceinstaller 도 사용해야 함.
+ (void) asyncIOS_Deploy:(NSString *)appPath withUDID:(NSString *)udid completion:(void (^)(BOOL successed, NSString *description))block {
    dispatch_queue_t asyncURLConnectionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);     // Global 이기 때문에 Http Module 을 호출한 객체와 분리됨..
    dispatch_async(asyncURLConnectionQueue, ^(void) {                                                               // 따라서 Http Module 을 호출한 객체가 소멸되어도 별도로 동작을 하기 때문에 안전함..
        @autoreleasepool {
            DDLogWarn(@"install path %@", appPath);
            NSString * commandString = [NSString stringWithFormat:@"ios-deploy -b %@ -i %@", appPath, udid];
            
            __block NSTask * installTaks = [[NSTask alloc] init];
            installTaks.launchPath = @"/bin/bash";
            installTaks.arguments = @[@"-l", @"-c", commandString];
            
            NSPipe *pipe= [NSPipe pipe];
            [installTaks setStandardOutput: pipe];
            NSFileHandle *file = [pipe fileHandleForReading];
            
            NSPipe * errorPipe = [NSPipe pipe];
            [installTaks setStandardError:errorPipe];
            NSFileHandle * errorFile = [errorPipe fileHandleForReading];
            
            installTaks.terminationHandler = ^(NSTask *task){
                // do things after completion
                DDLogWarn(@"%s : terminate myInstallTaks", __FUNCTION__);
                installTaks = nil;
            };
            
            @try {
                [installTaks launch];
            } @catch (NSException *e) {
                DDLogError(@"task error : %@", e.reason);
                
                [file closeFile];//mg//
                [errorFile closeFile];//mg//
                block(NO, @"ios-deploy error");//mg//
                return;
            }
            
            
            NSData * errorData = [errorFile readDataToEndOfFile];
            NSString * errorOutput = [[NSString alloc] initWithData:errorData encoding: NSUTF8StringEncoding];
            [errorFile closeFile];
            
            
            
            errorOutput = [errorOutput stringByReplacingOccurrencesOfString:@"\r" withString:@""];
            NSArray* arrErrorOut = [errorOutput componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            
            if( arrErrorOut.count != 0 ) {
                for(NSString* tmp in arrErrorOut) {
                    if( 0 == tmp.length )
                        continue;
                    
                    if( [[tmp lowercaseString] containsString:@"error"] ) {
                        // 어플 설치 오류 발생.
                        DDLogError(@"out error %@", tmp);
                        NSString* result = [[tmp componentsSeparatedByString:@"- Error occurred:"] lastObject];
                        DDLogError(@"-----error result %@", result);
                        
                        result = [NSString stringWithFormat:@"앱 설치오류 = %@",result];
                        block(NO, result);
                        return ;
                    }
                }
            }
            
            NSData *data = [file readDataToEndOfFile];
            NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
            [file closeFile];
            
            output = [output stringByReplacingOccurrencesOfString:@"\r" withString:@""];
            NSArray* arrOut = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            NSString* installAppId = nil;
            
            [installTaks terminate];
            
            if (output == nil || [output isEqualToString:@""] || [output isEqual:[NSNull null]]) {
                DDLogError(@"install fail");
//                self.installPath = nil;
//                [[CommunicatorWithDC sharedDCInterface] commonResponseForInstall:NO appId:@"설치 실패" deviceNo:_deviceInfos.deviceNo];
                block(NO, @"설치 실패");
                return ;
            } else {
                for(NSString* tmp0 in arrOut)
                {
                    if( 0 == tmp0.length )
                        continue;
                    
                    NSString * tmp = [tmp0 lowercaseString];
                    
                    if( [tmp containsString:@" error "]) {
                        
                        // 어플 설치 오류 발생.
                        DDLogError(@"out error %@", tmp0);
                        NSString* result = [[tmp componentsSeparatedByString:@"- error occurred:"] lastObject];
                        DDLogError(@"-----error result %@", result);
                        result = [NSString stringWithFormat:@"앱 설치오류 = %@",result];
                        
                        block(NO, result);
                        return ;
                    }
                    else if ([tmp containsString:@"installed package"]) {
                        // 앱 설치 성공.
                        DDLogWarn(@"install success");
                        block(YES, nil);
                        return ;
                    }
                }
            }
        }
    });
}

/// @brief  비동기로 NSURLSession 을 사용하여 ipa 파일을 다운로드 한다.
+ (void)asyncDownloadIpaFile:(NSString *)strUrl saveFilePath:(NSString *)managerDirectory completion:(void (^)(BOOL successed, NSString *description))block {
    
    dispatch_queue_t asyncURLConnectionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);     // Global 이기 때문에 Http Module 을 호출한 객체와 분리됨..
    dispatch_async(asyncURLConnectionQueue, ^(void) {                                                               // 따라서 Http Module 을 호출한 객체가 소멸되어도 별도로 동작을 하기 때문에 안전함..
        @autoreleasepool {
//            block(NO, @"설치 안됨");
            
            NSString *theFileName;
            NSArray* parse = [strUrl componentsSeparatedByString:@"/"];
            NSString* lastObj =[parse lastObject];
            
            //들어오기 전에 ipa 또는 zip 구분했었음.
            theFileName = lastObj;
            
            __block NSError * asyncError = nil;
            void (^completionHandler)(NSData * __nullable responseData, NSURLResponse * __nullable response, NSError * __nullable sessionError);
            completionHandler = ^(NSData * __nullable responseData, NSURLResponse * __nullable response, NSError * __nullable sessionError)
            {
                if( [sessionError code] ) {
                    asyncError = sessionError;
//                    DDLogError(@"다운로드 실패 (device no : %d) -- %@", _deviceInfos.deviceNo, asyncError);
                    block(NO, sessionError.description);
                    return ;
                }
                
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
                int nResponseCode =  (int)[httpResponse statusCode];
                if (nResponseCode != 200 && nResponseCode != 303)
                {
//                    DDLogError(@"다운로드 실패 (device no : %d) errorcode : %d", _deviceInfos.deviceNo, nResponseCode );
                    block(NO, [NSNumber numberWithInt:nResponseCode].description);
                    return ;
                }
                
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    NSString *theFinalPath = [NSString stringWithFormat:@"%@/%@", managerDirectory, theFileName];
                    DDLogWarn(@"Install File Path : %@", theFinalPath);
                    DDLogWarn(@"[theData length]=[%d]=---", (int)[responseData length]);
//                    [responseData writeToFile:theFinalPath atomically:NO] ;
                    
                    NSError* error;
                    //보내준 경로로 파일의 다운로드가 성공/실패 여부를 얻어옴.
                    BOOL bRes = [responseData writeToFile:theFinalPath options:NSDataWritingAtomic error:&error];
                    
                    if(bRes){
//                        DDLogWarn(@"파일 저장 성공 -- device no : %d", _deviceInfos.deviceNo);
                        block(YES, theFinalPath);
                    }
                    else {
//                        DDLogWarn(@"파일 저장 실패 이유(device : %d) : %@", _deviceInfos.deviceNo, error);
                        block(NO, theFinalPath);
                    }
                });
            };
            NSURL * url = [NSURL URLWithString:strUrl];
            NSURLRequest * request = [NSURLRequest requestWithURL:url];
            [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:completionHandler] resume];
        }
    });
}

@end

