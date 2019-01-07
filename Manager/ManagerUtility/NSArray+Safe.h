//
//  NSArray+Safe.h
//  ResourceMornitor
//
//  Created by SR_LHH_MAC on 2016. 5. 9..
//  Copyright © 2016년 onycom1. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (Safe)
- (id) safeObjectAtIndex:(NSInteger)index;
@end
