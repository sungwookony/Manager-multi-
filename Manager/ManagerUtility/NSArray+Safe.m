//
//  NSArray+Safe.m
//  ResourceMornitor
//
//  Created by SR_LHH_MAC on 2016. 5. 9..
//  Copyright © 2016년 onycom1. All rights reserved.
//

#import "NSArray+Safe.h"

/// @brief objectAtIndex: 에 범위를 벗어난 인덱스가 들어가면 예외가 발생하기에 보통 이렇게 사용함...
@implementation NSArray (Safe)
- (id) safeObjectAtIndex:(NSInteger)index {
    
    int nCount = (int)self.count;
    
    if( nCount > index) {
        return [self objectAtIndex:index];
    }
    return nil;
}
@end
