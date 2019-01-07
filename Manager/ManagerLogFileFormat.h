//
//  ManagerLogFileFormat.h
//  Manager
//
//  Created by onycom on 2018. 5. 17..
//  Copyright © 2018년 tomm. All rights reserved.
//

#ifndef ManagerLogFileFormat_h
#define ManagerLogFileFormat_h

#import <Foundation/Foundation.h>
#import "DDLog.h"

@interface ManagerLogFileFormat : NSObject <DDLogFormatter> {
    int atomicLoggerCount;
    NSDateFormatter *threadUnsafeDateFormatter;
}

@end
#endif /* ManagerLogFileFormat_h */
