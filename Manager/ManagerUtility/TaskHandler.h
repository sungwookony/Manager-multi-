//
//  TaskHandler.h
//  Manager
//
//  Created by SR_LHH_MAC on 2016. 6. 24..
//  Copyright © 2016년 tomm. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PipeHandlerDelegate;

/// @struct KindOfPipe
typedef NS_ENUM(NSUInteger, KindOfPipe) {
    /// 아무것도 아님.
    PIPE_NONE,
    
    /// Input Pipe
    PIPE_INPUT,
    
    /// Output 출력 Pipe
    PIPE_OUTPUT,
    
    /// Error 출력 Pipe
    PIPE_ERROR,
};

@interface PipeHandler :NSObject {
    /// 읽어들인 데이터를 전달하기 위한 Delegate
    __weak id<PipeHandlerDelegate> customDelegate;
    
    /// Pipe 객체
    id      pipe;
    
    /// Pipe Observer 한줄 한줄 Output 이 발생하는걸 비동기적으로 감지한다.
    id      pipeNotiObserver;
    
    /// Pipe 에서 출력되는 로그를 읽어들이기 위한 핸들러
    id      readFileHandler;
}

@property (nonatomic, weak) id<PipeHandlerDelegate> customDelegate;
@property (nonatomic, strong) id    pipe;
@property (nonatomic, strong) id    pipeNotiObserver;
@property (nonatomic, strong) id    readFileHandler;

- (id) initWithDelegate:(id)delegate;
- (void) setReadHandlerForTask:(NSTask *)task withKind:(int)kind;
- (void) closeHandler;

@end

@protocol PipeHandlerDelegate <NSObject>
@required
/// 읽어들인 데이터를 전달하기 위한 Delegate 메소드
- (void) readData:(NSData *)readData withHandler:(id)handler;
@end
