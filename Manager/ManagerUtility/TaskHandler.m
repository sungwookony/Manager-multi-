//
//  TaskHandler.m
//  Manager
//
//  Created by SR_LHH_MAC on 2016. 6. 24..
//  Copyright © 2016년 tomm. All rights reserved.
//

#import "TaskHandler.h"

/// @brief  타스크 이벤트 핸들러 등록 및 관리
@implementation PipeHandler
@synthesize customDelegate, pipe, pipeNotiObserver, readFileHandler;

/// 초기화
- (id) initWithDelegate:(id)delegate {
    self = [super init];
    if( self ) {
        pipe = [[NSPipe alloc] init];
        customDelegate = delegate;
    }
    return self;
}

/// 예전의 습관때문에 정리해주는데 굳이 할 필요 없음.
- (void) dealloc {
    customDelegate = nil;
    pipe = nil;
    pipeNotiObserver = nil;
    readFileHandler = nil;
}

/// @brief 입력 받은 task 에 Pipe 와 Observer 를 등록함.
/// @brief task 에서 문자열을 출력 되면 출력되는 경로(output. error) 에 따라 Pipe 를 통해 Notification 이 발생되어 문자열을 읽어들인다.
/// @brief 읽은 문자열을 Delegate 를 통해 비동기적으로 전달하게 된다.
/// @param task 실행될 task
/// @param kink Pipe  종류
- (void) setReadHandlerForTask:(NSTask *)task withKind:(int)kind {
    
    switch (kind) {
        case PIPE_INPUT: {
            [task setStandardInput:pipe];
        }   break;
        case PIPE_OUTPUT: {
            [task setStandardOutput:pipe];
        }   break;
        case PIPE_ERROR: {
            [task setStandardError:pipe];
        }   break;
        default: {
            
        }   break;
    }
    
    // BlockSelf 를 사용하면 setReadabilityHandler 안으로 들어가지 못함.. 왜 그런지는 확인해봐야 함..
    [[self.pipe fileHandleForReading] waitForDataInBackgroundAndNotify];
    self.pipeNotiObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleDataAvailableNotification object:[self.pipe fileHandleForReading] queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        
        DDLogVerbose(@"addObserverForName");
        
        [[self.pipe fileHandleForReading] setReadabilityHandler:^(NSFileHandle *file) {
            self.readFileHandler = file;
            
            NSData * output = [file availableData];
            if( [self.customDelegate respondsToSelector:@selector(readData:withHandler:)] ) {
                [self.customDelegate readData:output withHandler:self];
            }
            [[self.pipe fileHandleForReading] waitForDataInBackgroundAndNotify];
        }];
    }];
}

/// @brief pip, observer, file handler 등을 정리 한다.
- (void) closeHandler {
    if( readFileHandler )
        [readFileHandler closeFile];
    
    
    if( pipeNotiObserver ) {
        [[NSNotificationCenter defaultCenter] removeObserver:pipeNotiObserver];
        pipeNotiObserver = nil;
    }
    
    pipe = nil;
}

@end

