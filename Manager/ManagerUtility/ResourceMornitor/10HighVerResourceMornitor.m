//
//  10HighVerResourceMornitor.m
//  Manager
//
//  Created by SR_LHH_MAC on 2017. 8. 1..
//  Copyright © 2017년 tomm. All rights reserved.
//

#import "10HighVerResourceMornitor.h"
#import "TaskHandler.h"

@interface HighVersionRM () <PipeHandlerDelegate>
@property (nonatomic, strong) NSTask        * myResourceMornitorTask;
@property (nonatomic, strong) PipeHandler   * resourceMornitorHandler;
@property (nonatomic, strong) PipeHandler   * resourceMornitorErrorHandler;
@property (nonatomic, strong) dispatch_semaphore_t      resourceSem;
@end

@implementation HighVersionRM

- (id) init {
    self = [super init];
    if( self ) {
        _myResourceMornitorTask = nil;
        _resourceMornitorHandler = nil;
        _resourceMornitorErrorHandler = nil;
        _resourceSem = dispatch_semaphore_create(1);
    }
    
    return self;
}

- (void) dealloc {
    [self finishResourceMornitor];
}

#pragma mark - <Timer>
- (void) onAutoFinishResourceMornitorTimer:(NSTimer *)theTimer {
    [self performSelectorInBackground:@selector(finishResourceMornitor) withObject:nil];
}

#pragma mark - <PipeHandler Delegate>
- (void) readData:(NSData *)readData withHandler:(id)handler {
    // 출력되는 정보는 필요없어 무시함..
}

#pragma mark - <Functions>

/*
 *
 *  AppBuilder 가 존재하는 지 확인 한 후에 Appbuilder가 존재 유무를 확인하여
 *  존재하지 않으면 Appbuilder 가 아닌 경로를 활성화 해주어서 업로드 해야함
 *
 */
- (void) launchResourceMornitor {
    DDLogDebug(@"%s", __FUNCTION__);
//    [self finishResourceMornitor];
    
    dispatch_semaphore_wait(_resourceSem, DISPATCH_TIME_FOREVER);
    
    // iOS 10.x 버전은 Background 에 있는 ResourceMornitor App 을 Foreground 로 올려주는 역활만 있음. 만약 Background 에 없으면 실행됨.
    // ** 중요 ** : NSTask 로 실행한 Appbuilder 는 자동으로 Task 가 종료되지 않는다.
    __block __typeof__(self) blockSelf = self;
    dispatch_queue_t resourceQueue = dispatch_queue_create("ResourceQueue", NULL);
    dispatch_async(resourceQueue, ^{
        NSString * commandString = [NSString stringWithFormat:@"appbuilder device run com.onycom.ResourceMornitor2 --device %@", deviceInfos.udid];
        blockSelf.myResourceMornitorTask = [[NSTask alloc] init];
        blockSelf.myResourceMornitorTask.launchPath = @"/bin/bash";
        blockSelf.myResourceMornitorTask.arguments = @[@"-l", @"-c", commandString];
        
        blockSelf.resourceMornitorHandler = [[PipeHandler alloc] initWithDelegate:self];
        blockSelf.resourceMornitorErrorHandler = [[PipeHandler alloc] initWithDelegate:self];
        [blockSelf.resourceMornitorHandler setReadHandlerForTask:blockSelf.myResourceMornitorTask withKind:PIPE_OUTPUT];
        [blockSelf.resourceMornitorErrorHandler setReadHandlerForTask:blockSelf.myResourceMornitorTask withKind:PIPE_ERROR];
        
        // NSTask 파라미터 설정
        dispatch_async(dispatch_get_main_queue(), ^{
        
            [blockSelf.myResourceMornitorTask launch];
        
            // Appbuilder 로 ResoueceMornitor App 을 실행하든, Foreground 로 올리든.. 사용하고 나면.. 정리해줌. 계속 실행하고 있을 필요가 없음.
            [NSTimer scheduledTimerWithTimeInterval:5.0f target:self selector:@selector(onAutoFinishResourceMornitorTimer:) userInfo:nil repeats:NO];
            
            dispatch_semaphore_signal(_resourceSem);
        });
    });
}//launchResourceMornitor

- (void) finishResourceMornitor {
    DDLogWarn(@"%s, %d", __FUNCTION__, deviceInfos.deviceNo);
    
    dispatch_semaphore_wait(_resourceSem, DISPATCH_TIME_FOREVER);
    if( _myResourceMornitorTask ) {
        __block BOOL bFinished = NO;
        __block dispatch_semaphore_t resourceMornitorSem = dispatch_semaphore_create(0);
        
        _myResourceMornitorTask.terminationHandler = ^(NSTask * task) {
            if( resourceMornitorSem )
                dispatch_semaphore_signal(resourceMornitorSem);
        };
        [_myResourceMornitorTask terminate];        // // Not always possible. Sends SIGTERM.   항상 가능한게 아니라서.. 5초동안 기다린후 정리함.
        
        dispatch_semaphore_wait(resourceMornitorSem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0f *NSEC_PER_SEC)));
        
        _myResourceMornitorTask.terminationHandler = nil;
        
        if( _resourceMornitorHandler ) {
            [_resourceMornitorHandler closeHandler];
            _resourceMornitorHandler = nil;
        }
        
        if( _resourceMornitorErrorHandler ) {
            [_resourceMornitorErrorHandler closeHandler];
            _resourceMornitorErrorHandler = nil;
        }
        
        bFinished = YES;
        
        resourceMornitorSem = nil;
        _myResourceMornitorTask = nil;
    }
    
    dispatch_semaphore_signal(_resourceSem);
}

@end
