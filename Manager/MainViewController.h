//
//  MainViewController.h
//  Manager
//
//  Created by mac_onycom on 2015. 6. 22..
//  Copyright (c) 2015년 tomm. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class ConnectionItemInfo;
@interface MainViewController : NSViewController
{
    NSDateFormatter *dateToday;

    NSDateFormatter *dateNow;
    
    NSString* appName;
    NSString* appName2;
    
    
    
}

- (ConnectionItemInfo *)firstConnectionItemInfo;
- (ConnectionItemInfo* )connectionItemInfoByDeviceNo:(int)argDeviceNo;
- (NSString *)udidByDeviceNo:(int)argDeviceNo;
- (void)killProcess;


-(void)logStart:(NSString *)udid logSearch:(NSString *)search identifier:(NSString* )identifier level: (char)level;
-(void)logStop;

@property (nonatomic, strong) NSTask *logTask;

@property (nonatomic, strong) id    pipe;
@property (nonatomic, strong) id    pipeNotiObserver;
@property (weak) IBOutlet NSView *dcView;

@end
