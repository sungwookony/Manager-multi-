//
//  ResourceMornitor.h
//  Manager
//
//  Created by SR_LHH_MAC on 2017. 8. 1..
//  Copyright © 2017년 tomm. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DeviceInfo.h"

@protocol ResourceMornitorDelegate;

@interface ResourceMornitor : NSObject {
    DeviceInfos *deviceInfos;
}

@property (nonatomic, strong) DeviceInfos   * deviceInfos;

+ (id) lowVersionResourceMornitor;
+ (id) highVersionResourceMornitor;

- (void) launchResourceMornitor;
- (void) finishResourceMornitor;

@end


@protocol ResourceMornitorDelegate <NSObject>
@required

@end
