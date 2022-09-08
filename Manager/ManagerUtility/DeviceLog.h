//
//  DeviceLog.h
//  Manager
//
//  Created by Mac0516 on 2015. 7. 23..
//  Copyright (c) 2015년 tomm. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MainViewController.h"

@class DeviceInfos;
@protocol DeviceLogDelegate;


@interface DeviceLog : NSObject {
    __weak  id<DeviceLogDelegate> customDelegate;
}


@property (nonatomic, weak)     MainViewController *mainController;
@property (nonatomic, weak)     id<DeviceLogDelegate>   customDelegate;

@property (nonatomic, strong) DeviceInfos       * myDeviceInfos;


@property (nonatomic, strong) NSTask *logTask;
@property (nonatomic, strong) id    pipe;
@property (nonatomic, strong) id    pipeNotiObserver;

@property (nonatomic, strong) NSString *logSearch;
@property (nonatomic, strong) NSString *logIdentifier;
@property (nonatomic, strong) NSString *udid;
@property (nonatomic, strong) NSString *bundleId;

//swccc 설치된 app name 추가
@property (nonatomic, strong) NSString *appName;

@property (nonatomic, assign) int osVersion;

@property (nonatomic, assign) int logLevel;
@property (nonatomic, assign) int deviceNo;

@property (nonatomic, assign) BOOL bLogStarted;

- (id)initWithDeviceNo:(int)argDeviceNo UDID: (NSString* ) argUDID withDelegate:(id<DeviceLogDelegate>)delegate;
- (id)initWithDeviceNo:(int)argDeviceNo UDID: (NSString* ) argUDID deviceVersion:(NSString *)deviceVersion withDelegate:(id<DeviceLogDelegate>)delegate;
- (void)startLogAtFirst;
//- (void)startLog:(NSString *)search identifier:(NSString* )identifier level: (char)level;
- (void)startLog:(NSString *)search identifier:(NSString* )identifier level: (char)level bundleID:(NSString *)bundleID appName:(NSString *)appName;
- (void)setLogFilterSearch:(NSString *)search identifier:(NSString* )identifier level: (char)level;
- (void)stopLog;
- (void)killLogProcess;
@end


@protocol DeviceLogDelegate <NSObject>
@required
- (void) launchedAppInfos:(NSArray *)arrInfos;
@end
