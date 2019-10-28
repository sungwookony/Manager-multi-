//
//  InstrumentsControlAgent.m
//  Manager
//
//  Created by SR_LHH_MAC on 2017. 7. 31..
//  Copyright © 2017년 tomm. All rights reserved.
//

#import "InstrumentsControlAgent.h"

@interface InstrumentsControlAgent()
@property (nonatomic, strong) NSDictionary  * dicDontTouchRect;
@end



@implementation InstrumentsControlAgent

- (id) init {
    self = [super init];
    if( self ) {
        
        // 사파리의 하단 툴바의 공유버튼을 눌러 팝업이 발생하면 Instruments 의 동작이 이뤄지지 않는다. 그래서, 해당 버튼의 위치를 Tap 할때 막는 역활을 위해 아래의 코드가 들어감...
        NSValue * inch_4_rect = [NSValue valueWithRect:CGRectMake(138.0f, 524.0f, 44.0f, 44.0f)];
        NSValue * inch_4_7_rect = [NSValue valueWithRect:CGRectMake(165.0f, 623.0f, 44.0f, 44.0f)];
        NSValue * inch_5_5_rect = [NSValue valueWithRect:CGRectMake(185.0f, 692.0f, 44.0f, 44.0f)];
        
        _dicDontTouchRect = [NSDictionary dictionaryWithObjectsAndKeys:inch_4_rect, @"iPhone5,1", inch_4_rect, @"iPhone5,2", inch_4_rect, @"iPhone5,3", inch_4_rect, @"iPhone5,4", inch_4_rect, @"iPhone6,1", inch_4_rect, @"iPhone6,2", inch_5_5_rect, @"iPhone7,1", inch_4_7_rect, @"iPhone7,2", inch_4_7_rect, @"iPhone8,1", inch_5_5_rect, @"iPhone8,2", inch_4_7_rect, @"iPhone8,4", nil];
    }
    return self;
}

@end
