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

@property (weak) IBOutlet NSView *dcView;

@end
