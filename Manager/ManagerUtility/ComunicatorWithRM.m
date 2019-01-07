//
//  ComunicatorWithRM.m
//  ResourceMornitor
//
//  Created by SR_LHH_MAC on 2016. 5. 3..
//  Copyright © 2016년 onycom1. All rights reserved.
//

#import "ComunicatorWithRM.h"
#import "GCDAsyncSocket.h"
#import "NSArray+Safe.h"

#import "LogWriteToFile.h"

#import <netinet/in.h>
#import <netinet/tcp.h>


/**
 *  @file   CommunicatorWithRM.h
 *  @brief  리소스모니터 앱과 통신을 하기 위해 만들어 사용했으나 지금은 사용하지 않음.
 *  @brief  해당 기능은 USB 터널링을 pearTalk 에서 iproxy 로 변경 되면서 CommunicatorWithIProxy.m 으로 대체됨. 자세한 설명은 해당 파일에서..
 */

#define TAG_WHO_ARE_YOU         10000


@interface CommunicatorWithRM ()

@property (nonatomic, strong) GCDAsyncSocket    * serverSocket;
@property (nonatomic, strong) NSMutableDictionary <NSNumber *, GCDAsyncSocket *> * clientSocket;
@property (nonatomic, strong) NSMutableArray <GCDAsyncSocket *> * tempClientSocket;
#ifdef USE_LOG_RESOURCE
@property (nonatomic, strong) LogWriteToFile    * logWriteFile;
#endif

@end

/// @brief  리소스모니터 앱과 통신을 하기 위해 만들어 사용했으나 지금은 사용하지 않음.
/// @brief  해당 기능은 USB 터널링을 pearTalk 에서 iproxy 로 변경 되면서 CommunicatorWithIProxy.m 으로 대체됨. 자세한 설명은 해당 파일에서..
@implementation CommunicatorWithRM {
    dispatch_queue_t    rxQueue;//mg//serial queue
}

@synthesize mainViewCtrl;
@synthesize customDelegate;

static CommunicatorWithRM *mySharedRMInterface = nil;

+ (CommunicatorWithRM *)sharedRMInterface {
    static dispatch_once_t onceToken ;
    dispatch_once(&onceToken, ^{
        if (!mySharedRMInterface || mySharedRMInterface == nil) {
            mySharedRMInterface = [[CommunicatorWithRM alloc] init] ;
        }
    });
    
    return mySharedRMInterface ;
}

- (id) init {
    self = [super init];
    if( self ) {
        _serverSocket = nil;
        _clientSocket = [NSMutableDictionary dictionaryWithCapacity:10];
        _tempClientSocket = [[NSMutableArray alloc] initWithCapacity:10];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:ApplicationWillTerminateNotification object:nil];
        
        rxQueue = dispatch_queue_create("RX_SERIAL_QUEUE", NULL);//mg//
        
#ifdef USE_LOG_RESOURCE
        _logWriteFile = [[LogWriteToFile alloc] init];
#endif
    }
    
    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_clientSocket removeAllObjects];
    _clientSocket = nil;
    
    [_tempClientSocket removeAllObjects];
    _tempClientSocket = nil;
    
#ifdef USE_LOG_RESOURCE
    _logWriteFile = nil;
#endif
}


- (void)startInterfaceWithRM {
    
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    _serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:mainQueue];
    
    NSError *error = nil;
    if(![_serverSocket acceptOnPort:RM_SOCKET_PORT error:&error]) {
        DDLogWarn(@"Error starting server: %@", error);
        return;
    }
    
    DDLogWarn(@"Server started on port %hu", [_serverSocket localPort]);
}

- (BOOL)sendCommand:(NSString *)cmd withDeviceID:(int)deviceID {
//    DDLogInfo(@"SendCommand -- cmd : %@, device id : %d", cmd, deviceID);
    NSData *dataCmd = [cmd dataUsingEncoding:NSUTF8StringEncoding];
//    GCDAsyncSocket *clntSocket = [_clientSocket safeObjectAtIndex:deviceID];
    GCDAsyncSocket *clntSocket = [_clientSocket objectForKey:[NSNumber numberWithInt:deviceID]];
    if( !clntSocket ) {
        DDLogError(@"Client is not connected!! - %s",__FUNCTION__);
        return NO;
    }
    
    [clntSocket writeData:dataCmd withTimeout:-1 tag:deviceID];
    
    return YES;
}

- (void) removeSocket:(NSNumber *)keyNumber {
    [_clientSocket removeObjectForKey:keyNumber];
}

#pragma mark - <Notification>
- (void) applicationWillTerminate:(NSNotification *)notification {
    [_serverSocket setDelegate:nil];
    [_serverSocket disconnect];
    
#ifdef USE_LOG_RESOURCE
    [_logWriteFile closeFile];
#endif
}

#pragma mark - <Timer>
- (void) onCheckSocketOptions:(NSTimer *)theTimer {
    DDLogInfo(@"%s", __FUNCTION__);
    GCDAsyncSocket * socket = (GCDAsyncSocket *)[theTimer userInfo];
    
    [socket performBlock:^{
        int fd = [socket socketFD];
        
        int nLen = sizeof(int);
        int sendBufSize = 24;
        if( -1 == getsockopt(fd, SOL_SOCKET, SO_SNDBUF, (char *)&sendBufSize, &nLen) ) {
            DDLogError(@"SetSockOpt Failed!! -- (SO_SNDBUF)");
        } else {
            DDLogWarn(@"Socket Send Buffer Size : %d", sendBufSize);
        }
        
        int recvBufSize = 16;
        if( -1 == getsockopt(fd, SOL_SOCKET, SO_RCVBUF, (char *)&recvBufSize, &nLen) ) {
            DDLogError(@"SetSockOpt Failed!! -- (SO_RCVBUF)");
        } else {
            DDLogWarn(@"Seocket Read Buffer Size : %d", recvBufSize);
        }
    
//        int on = 1;
//        if( -1 == getsockopt(fd, IPPROTO_TCP, TCP_NODELAY, (char* )&on, &nLen) ) {
//            /* handle error */
//            DDLogInfo(@"SetSockOpt Failed!! -- (TCP_NODELAY)");
//        } else {
//            if( on )
//                DDLogInfo(@"SetSockOpt Successed!! -- (TCP_NODELAY)");
//        }
    }];
    
    [theTimer invalidate];
}

#pragma mark - <GCDAsyncSocket Delegate>
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    DDLogWarn(@"%s", __FUNCTION__);
    // This method is executed on the socketQueue (not the main thread)
    
    [_tempClientSocket addObject:newSocket];
    int nTag = (int)[_tempClientSocket indexOfObject:newSocket] + TAG_WHO_ARE_YOU;
    
    [newSocket writeData:[CMD_WHO_ARE_YOU dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:nTag];
    [newSocket readDataWithTimeout:-1 tag:nTag];
    
    [newSocket performBlock:^{
        int fd = [newSocket socketFD];
        
        int nLen = sizeof(int), nStatus = -1;
        int nSendBufSize = 16, nRecvBufSize = 24;
        
        nStatus = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &nSendBufSize, (socklen_t)nLen);
        if( -1 == nStatus ) {
            DDLogWarn(@"setsockopt Failed!! -- SO_SNDBUF");
        }
        
        nStatus = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &nRecvBufSize, (socklen_t)nLen);
        if( -1 == nStatus ) {
            DDLogWarn(@"setsockopt Failed!! -- SO_RCVBUF");
        }
        
//        int on = 1;
//        if( -1 == setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, (char*)&on, &nLen) ) {
//            /* handle error */
//            DDLogInfo(@"SetSockOpt Failed!! -- (TCP_NODELAY)");
//        }
    }];
    
    [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(onCheckSocketOptions:) userInfo:newSocket repeats:NO];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
//    DDLogInfo(@"%s", __FUNCTION__);
    
    // This method is executed on the socketQueue (not the main thread)
    
    //[sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:60.0 tag:0];
}

///**
// * This method is called if a read has timed out.
// * It allows us to optionally extend the timeout.
// * We use this method to issue a warning to the user prior to disconnecting them.
// **/
//- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length {
//
//	if (elapsed <= READ_TIMEOUT) {
//		NSString *warningMsg = @"Are you still there?\r\n";
//		NSData *warningData = [warningMsg dataUsingEncoding:NSUTF8StringEncoding];
//
//		[sock writeData:warningData withTimeout:-1 tag:WARNING_MSG];
//
//		return READ_TIMEOUT_EXTENSION;
//	}
//
//	return 0.0;
//}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    DDLogWarn(@"%s, error : %@", __FUNCTION__, err);
    // Client Socket 정보가 넘어옴..
    if( NSNotFound != [_tempClientSocket indexOfObject:sock] ) {
        [_tempClientSocket removeObject:sock];
    }
    
    [_clientSocket enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, GCDAsyncSocket * _Nonnull obj, BOOL * _Nonnull stop) {
        if( obj == sock ) {
            [self performSelectorOnMainThread:@selector(removeSocket:) withObject:key waitUntilDone:NO];        // 혹시 몰라서 분기 처리 했음..
            *stop = YES;
        }
    }];
}

- (void)__disconnectPostProcessByDeviceNo:(int)argDeviceNo {
    // 1. stop log
    // 2. ??? stop appium ???
    
}

#pragma mark -
#pragma mark 수신된 패킷으로 기능 실행.

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    
    __weak typeof(self) w_self = self ;
    
    //mg//dispatch_async(dispatch_get_main_queue(), ^{
    dispatch_async(rxQueue, ^{//mg//
        @autoreleasepool {
            [w_self __processReceivedData:data withTag:tag];
        }
    });
}

- (void)__processReceivedData:(NSData *)data withTag:(long)tag {
    if( TAG_WHO_ARE_YOU == tag ) {
        NSString * uploadedPacket = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//    DDLogInfo(@"[#### Info ####] Device : %d,  Uploaded Packet : %@", tag, uploadedPacket ? uploadedPacket : @"데이터 없음.");
        NSArray * content = [uploadedPacket componentsSeparatedByString:@":"];
        
        if( content.count < 2 ) {
            DDLogError(@"데이터에 문제 발생함..");
            return ;
        }
        
#ifdef USE_LOG_RESOURCE
        [_logWriteFile writeString:uploadedPacket withTag:tag];
#endif
        if( [@"device" isEqualToString:[content objectAtIndex:0]] ) {
            int nDeviceNo = [[content objectAtIndex:1] intValue];
            tag -= TAG_WHO_ARE_YOU;
            GCDAsyncSocket * clntSocket = [_tempClientSocket objectAtIndex:tag];
            [_tempClientSocket removeObjectAtIndex:tag];
            
            [_clientSocket setObject:clntSocket forKey:[NSNumber numberWithInt:nDeviceNo]];
            [clntSocket readDataWithTimeout:-1 tag:nDeviceNo];
        }
        /*      // 데이터 확인용
        else if ( [@"packet" isEqualToString:[content objectAtIndex:0]] ) {
            if( self.customDelegate && [self.customDelegate respondsToSelector:@selector(recvdResourcePacket:)] ) {
                [self.customDelegate recvdResourcePacket:[content objectAtIndex:1]];
            }
            
            NSString * recvPacket = [content safeObjectAtIndex:1];
            if( recvPacket ) {
                //            DDLogInfo(@"Recv Packet: %@\n\n\n", [content objectAtIndex:1]);
            } else {
                DDLogInfo(@"받은 데이터가 없음..");
            }
            
            GCDAsyncSocket * clntSocket = [_clientSocket objectForKey:[NSNumber numberWithInt:tag]];
            [clntSocket readDataWithTimeout:-1 tag:tag];
        }
        */
        else {
            DDLogError(@"잘못된 데이터.....");
        }
    } else {        // 수신된 리소스 정보들..  리소스 정보들은 해당 디바이스의 아이디를 테그로 사용한다.
        if( self.customDelegate && [self.customDelegate respondsToSelector:@selector(recvdResourcePacket:andDeviceNo:)] ) {
            [self.customDelegate recvdResourcePacket:data andDeviceNo:(int)tag];
//            DDLogInfo(@"RecvData : %@", data.description);
        }
        
#ifdef USE_LOG_RESOURCE
        [_logWriteFile writeString:data.description withTag:tag];
#endif
        
        GCDAsyncSocket * clntSocket = [_clientSocket objectForKey:[NSNumber numberWithInt:(int)tag]];
        [clntSocket readDataWithTimeout:-1 tag:tag];
    }
}

@end
