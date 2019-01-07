//
//  AppInstaller.h
//  Manager
//
//  Created by SR_LHH_MAC on 2017. 8. 11..
//  Copyright © 2017년 tomm. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma makr - <AppInstaller>
@interface AppInstaller : NSObject
+ (void) asyncIDeviceInstaller:(NSString *)appPath withUDID:(NSString *)udid completion:(void (^)(BOOL successed, NSString *description))block;
+ (void) asyncIOS_Deploy:(NSString *)appPath withUDID:(NSString *)udid completion:(void (^)(BOOL successed, NSString *description))block;

+ (void) asyncDownloadIpaFile:(NSString *)strUrl saveFilePath:(NSString *)managerDirectory completion:(void (^)(BOOL successed, NSString *description))block;

@end

