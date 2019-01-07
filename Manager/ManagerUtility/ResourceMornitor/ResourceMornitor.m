//
//  ResourceMornitor.m
//  Manager
//
//  Created by SR_LHH_MAC on 2017. 8. 1..
//  Copyright © 2017년 tomm. All rights reserved.
//

#import "ResourceMornitor.h"
#import "9LowVerResourceMornitor.h"
#import "10HighVerResourceMornitor.h"

@implementation ResourceMornitor
@synthesize deviceInfos;

+ (id) lowVersionResourceMornitor {
    return [[LowVersionRM alloc] init];
}

+ (id) highVersionResourceMornitor {
    return [[HighVersionRM alloc] init];
}

- (void) launchResourceMornitor {
    
}

- (void) finishResourceMornitor {
    
}

@end
