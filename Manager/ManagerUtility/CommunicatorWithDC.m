//
//  CommProcessorWDC.m
//  Manager
//
//  Created by User on 6/29/15.
//  Copyright (c) 2015 tomm. All rights reserved.
//

#import "CommunicatorWithDC.h"
#import "GCDAsyncSocket.h"
//#import "DefineKeycode.h"
#import "MainViewController.h"
#import "ConnectionItemInfo.h"
#import "DeviceLog.h"

#import "ComunicatorWithRM.h"                           // add by leehh
#import "TaskHandler.h"

#import "DeviceInfo.h"
#import "Utility.h"


#define TAG_READ_MANUAL         0
#define TAG_READ_AUTO           1


@interface CommunicatorWithDC () <ResourceMornitorDelegate> {
    /// @brief 리슽소켓
    GCDAsyncSocket          * listenSocket;
    /// @brief DC 와 연결된 소켓
    GCDAsyncSocket          * connectedSocket;
    
    // 소스 통합까지 임시적으로 사용
#ifdef USE_AUTO_MNG
    /// @brief 자동화 기능을 위해 만들어둔 소켓.... 굳이 소켓을 2개 가져갈 필요는 없는데 DC 에서도 소켓을 하나로 줄여야 하는 관계로 메니져에서 소켓을 하나더 추가함.
    GCDAsyncSocket          * autoListenSocket;
    GCDAsyncSocket          * autoConnectedSocket;
#endif
    // ~
    /// @brief GCD Queue (멀티쓰레드)
    dispatch_queue_t        infoQueue;//mg//멀티 단말기 다음에//[20];
    
    /// @brief GCD Semaphore (동시 접근/사용 제어)
    dispatch_semaphore_t    infoSem;//mg//멀티 단말기 보류//[20];                 // add by leehh
}

/// @brief Manual Socket 포트번호
@property (nonatomic, assign) NSInteger nPort;

/// @brief 자동화 소켓 포트 번호
@property (nonatomic, assign) int       nAutoPort;

@property (nonatomic, assign) BOOL  bStopTask;//mg//작업 중지

@end

/// @brief  DC 와 통신을 함.
@implementation CommunicatorWithDC {
    dispatch_queue_t    rxQueue;//mg//serial queue
}

/// @brief 싱글턴 객체
static CommunicatorWithDC *mySharedDCInterface = nil;


/// @brief 초기화 GCD 큐와 세마포어를 20개 생성해둔다.
- (id)init {
    
    if (self = [super init]) {
        _nPort = SOCKET_PORT;
        _nAutoPort = AUTO_SOCKET_PORT;
        
        listenSocket = nil;
        connectedSocket = nil;
#ifdef USE_AUTO_MNG        
        autoListenSocket = nil;
        autoConnectedSocket = nil;
#endif
        
        //mg//멀티 단말기 보류
        /*for(int i = 0; i <20 ; i++){
            NSString* queueName = [NSString stringWithFormat:@"CINFO_QUEUE_%d", i];
            infoQueue[i] = dispatch_queue_create([queueName UTF8String], NULL);//serial queue
            infoSem[i] = dispatch_semaphore_create(1);                  // add by leehh
        }*/
        
        infoQueue = dispatch_queue_create("REQUEST_QUEUE", NULL);//mg//serial queue
        infoSem = dispatch_semaphore_create(1);                  //mg//
        rxQueue = dispatch_queue_create("RX_SERIAL_QUEUE", NULL);//mg//
    }
    return self;
}

/// @brief 싱글턴 객체 생성
+ (CommunicatorWithDC *)sharedDCInterface {
    
    static dispatch_once_t onceToken ;
    dispatch_once(&onceToken, ^{
        if (!mySharedDCInterface || mySharedDCInterface == nil) {
            mySharedDCInterface = [[CommunicatorWithDC alloc] init] ;
        }
    });
    
    return mySharedDCInterface ;
}

/// @brief 자동화 소켓과 메뉴얼 소켓을 생성하여 DC 와 연결을 기다린다.
- (void)startInterfaceWithDC {
    
    DDLogInfo(@"%s, port : %d", __FUNCTION__, (int)self.nPort);
    
    dispatch_queue_t socketQueue = dispatch_queue_create("socketQueue", NULL);
//    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:socketQueue];
    
    NSError *error = nil;
    if(![listenSocket acceptOnPort:self.nPort error:&error]) {
        DDLogWarn(@"Error starting server: %@", error);
        return;
    }
    
#ifdef USE_AUTO_MNG
    dispatch_queue_t autoSocketQueue = dispatch_queue_create("autoSocketqueue", NULL);
    autoListenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:autoSocketQueue];
    
    if( ![autoListenSocket acceptOnPort:self.nAutoPort error:&error] ) {
        DDLogWarn(@"Error Start Auto Server : %@", error.description);
        return ;
    }
    DDLogWarn(@"Server started on port %hu, port %d", [listenSocket localPort], (int)autoListenSocket.localPort);
#else
    DDLogWarn(@"Server started on port %hu", [listenSocket localPort]);
#endif
    
}

/// @brief 디바이스 번호로 udid 획득
- (NSString *)udidByDeviceNo:(int)argDeviceNo {
    
    NSString *theUdid = [self.mainController udidByDeviceNo:argDeviceNo];
    return theUdid;
}


/// @brief 디바이스 번호에 맞는 GCD queue 획득
- (dispatch_queue_t)getDispatchQueue:(int)deviceNo {
    //mg//멀티 단말기 보류
    /*if (deviceNo > 0 && deviceNo < 21) {
        return infoQueue[deviceNo-1];
        
    }else {
        return nil;
    }*/
    return infoQueue;//mg//
}

// add by leehh
- (dispatch_semaphore_t)getSemaphore:(int)deviceNo {
    //mg//멀티 단말기 보류
    /*if (deviceNo > 0 && deviceNo < 21) {
        return infoSem[deviceNo-1];
    }else {
        return nil;
    }*/
    return infoSem;//mg//
}
// ~


#pragma mark -
#pragma mark GCDAsyncSocket Delegate
/// @brief DC 와 연결되어 호출 되는 Delebgate 메소드

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    DDLogWarn(@"%s", __FUNCTION__);
    // This method is executed on the socketQueue (not the main thread)
    
    ConnectionItemInfo * itemInfo = [self.mainController firstConnectionItemInfo];
    NSLog(@"%d",itemInfo.deviceInfos.deviceNo);
    [self commonResponse:YES reqCmd:0 msg:@"접속성공" deviceNo:itemInfo.deviceInfos.deviceNo];
    
    if( (int)newSocket.localPort == (int)_nPort ) {
        connectedSocket = newSocket;
//        [connectedSocket readDataWithTimeout:-1 tag:0];
        [connectedSocket readDataWithTimeout:-1 tag:TAG_READ_MANUAL];
    } else if ( (int)newSocket.localPort == (int)_nAutoPort ) {
#ifdef USE_AUTO_MNG
        autoConnectedSocket = newSocket;
        [autoConnectedSocket readDataWithTimeout:-1 tag:TAG_READ_AUTO];
#endif
    }
    
#ifdef VER_STANDALONE
    ConnectionItemInfo * itemInfo = [self.mainController firstConnectionItemInfo];
    if( nil == itemInfo )
        return ;
    
    [self sendDeviceChange:1 withInfo:itemInfo.deviceInfos andDeviceNo:itemInfo.deviceInfos.deviceNo];
#endif
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

/// @brief 소켓이 끊어졌을때 인데.. 별로 하는게 없음..
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    DDLogWarn(@"%s", __FUNCTION__);
    
    if (sock == listenSocket) {
//    if (sock == connectedSocket) {
        DDLogError(@"Disconnected............");
        listenSocket = nil;
        connectedSocket = nil;
        [self __disconnectPostProcessByDeviceNo:0];
    }
    
//    if( sock == autoListenSocket ) {
//        DDLogError(@"Disconnected............");
//        listenSocket = nil;
//        connectedSocket = nil;
//        [self __disconnectPostProcessByDeviceNo:0];
//    }
}

- (void)__disconnectPostProcessByDeviceNo:(int)argDeviceNo {
    // 1. stop log
    // 2. ??? stop appium ???
    
    [self __processEndConnectionByPacket:nil deviceNo:argDeviceNo];
}

#pragma mark -
#pragma mark 수신된 패킷으로 기능 실행.
/// @brief 소켓에서 데이터를 받으면 호출되는 Delegate 메소드
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    DDLogDebug(@"%s data size = %d", __FUNCTION__, (int)data.length);
    
    __weak typeof(self) w_self = self ;
    
    //mg//dispatch_async(dispatch_get_main_queue(), ^{
    dispatch_async(rxQueue, ^{//mg//
        @autoreleasepool {
//            DDLogInfo(@"received delegate data %@" , data);
            [w_self __processReceivedData:data];
        }
    });
    
    if( sock == connectedSocket ) {
        [connectedSocket readDataWithTimeout:-1 tag:TAG_READ_MANUAL];
    }
#ifdef USE_AUTO_MNG
    else if ( sock == autoConnectedSocket ) {
        [autoConnectedSocket readDataWithTimeout:-1 tag:TAG_READ_AUTO];
    }
#endif
    
}

/// @brief 데이터 패킷 파싱.
- (void)__processReceivedData:(NSData *)data {
    
    int packetPos = 0;
    int prevPacket = 0;
    
//    NSLog(@"Recv Data : %@", data.description);
    
    while (data!=nil && data.length > 0) {
        const uint8_t * first = (uint8_t *)[data subdataWithRange:NSMakeRange(packetPos, 1)].bytes;
        packetPos += 1;
        //        NSInteger nFirst  = first[0];
        if(first[0] == 0x7f)
        {
            NSData* size = [data subdataWithRange:NSMakeRange(packetPos, 4)];
            NSInteger nSize  = CFSwapInt32BigToHost(*(int*)([size bytes]));
            
            int packetSize = 1+4+2+1+(int)nSize+2+1;
            
            if((packetSize + prevPacket) > [data length]) //data not enough
                break;
            
            packetPos += 4;
            
            NSData* cmd = [data subdataWithRange:NSMakeRange(packetPos, 2)];
            NSInteger nCmd  = CFSwapInt16HostToBig(*(int*)([cmd bytes]));
            
            packetPos += 2;
            
            const uint8_t * deviceNo = (uint8_t *)[data subdataWithRange:NSMakeRange(packetPos, 1)].bytes;
            int the_device_no = (int)(*deviceNo);
            packetPos += 1;
            
            NSData* packData = [data subdataWithRange:NSMakeRange(packetPos, nSize)];
            
            packetPos += nSize;
            
            //            NSData* checksum = [data subdataWithRange:NSMakeRange(packetPos, 2)];
            //            NSInteger nChecksum  = CFSwapInt16HostToBig(*(int*)([checksum bytes]));
            //            printf("++++ %s %d+++++", deviceNo, (int) nChecksum);
            packetPos += 2;
            
            const uint8_t * end = (uint8_t *)[data subdataWithRange:NSMakeRange(packetPos, 1)].bytes;
            if(end[0] != 0xEf) //end flag is not matched
                break;
            
            //            [self parsedPacket:nCmd packet:packData size:packetSize];
            [self doActionByPacketCommand:nCmd deviceNo:the_device_no packetData:packData size:packetSize];
            
            if([data length] == (packetSize + prevPacket)) {
                break;
            }
            else if ([data length]  > (packetSize + prevPacket)){
                prevPacket += packetSize;
                packetPos = prevPacket;
            }
        }
        else
        {
            //start flag is not matched
            break;
        }
    }
}

//mg//
/// @brief Start Command 를 수신하여 호출됨. 자동화/메뉴얼 동작을 실행시키고 UI 에 로그를 출력함.
- (void)__processStartConnectionByPacket:(NSData *)packet isManual:(BOOL)manual deviceNo:(int)argDeviceNo {
    DDLogDebug(@"%s", __FUNCTION__);
    
    // 1. 관련 초기화한다.
    // 2. CMD_RESPONSE를 보낸다.
    
    _bStopTask = true;
    
    ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];      //
    if (itemInfo == nil) {
        [self commonResponse:NO deviceNo:argDeviceNo];
    } else {
        dispatch_async(infoQueue, ^(void){
            [itemInfo launchResource];
            [itemInfo startAgentManual:manual];
            
            //onycap
            /*NSTask *task = [[NSTask alloc] init];
            task.launchPath = @"/bin/bash";
            task.arguments = @[@"-l", @"-c", @"open -a Onycap"];
            
            @try {
                [task launch];
                DDLogInfo(@"launch onycap");
            } @catch (NSException *e) {
                DDLogError(@"onycap launch error = %@", e.reason);
                
                //[self commonResponse:NO deviceNo:argDeviceNo];
                //[itemInfo stopAgent];
                //return;
            }*/
            
            _bStopTask = false;
        });
    }
}//__processStartConnectionByPacket

//mg//
/*- (void)__processStartConnectionByPacket:(NSData *)packet isManual:(BOOL)manual deviceNo:(int)argDeviceNo {
    DDLogDebug(@"%s", __FUNCTION__);
    
    // 1. 관련 초기화한다.
    // 2. CMD_RESPONSE를 보낸다.
    
    ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];      //
    if (itemInfo == nil) {
        [self commonResponse:NO deviceNo:argDeviceNo];
    } else {
        //        [self commonResponse:YES deviceNo:argDeviceNo];
        //        //리소스모니터 최초실행 swccc
        [itemInfo launchResource];
        
        dispatch_async(infoQueue, ^(void){
            [itemInfo startAgentManual:manual];
            
            //(Log를 시작할 때마다 로그를 출력하면 로그가 중복되어, 디바이스 연결시에 로그 출력을 시작하고 로그 출력 커맨드가 왔을 때 로그를 D.C로 전송)
            [itemInfo initDeviceLog];           // App 이 실행된 정보(BundleID)를 획득해야 하기 때문에 자동화/메뉴얼 구분없이 실행되어야 함.
             [itemInfo getMyAppListForStart];
             
             NSString* ratio = [NSString stringWithFormat:@"%.1f",itemInfo.deviceInfos.ratio];
             NSDictionary* dict = [[NSDictionary alloc] initWithObjectsAndKeys:itemInfo.deviceInfos.udid,@"UDID"
             ,itemInfo.deviceInfos.deviceName, @"NAME"
             ,itemInfo.deviceInfos.productVersion,@"VERSION"
             ,ratio, @"RATIO"
             , nil];
             
             //deviceLog정보를 UI로 보여줌
             dispatch_async(dispatch_get_main_queue(), ^{
             // code here
             [[NSNotificationCenter defaultCenter] postNotificationName:DEVICE_CONNECT object:self userInfo:dict];
             });
        });
    }
}//__processStartConnectionByPacket
 */

/// @brief STOP Command 가 수신되어 호출됨.
/// @param packet 관리자 페이지에서 초기화 관련 옵션에 따라 초기화를 결정할 값이 담겨있음. 1 또는 값이 없으면 설치한 앱 삭제 / 0 이면 삭제하지 않음.
/// @param argDeviceNo 디바이스 번호
- (void)__processEndConnectionByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
    DDLogDebug(@"%s", __FUNCTION__);
    
    _bStopTask = true;//mg//stop task

    ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
    if(itemInfo != nil){
        dispatch_async(infoQueue, ^(void){
            //mg//onycap
            /*NSTask *task = [[NSTask alloc] init];
            task.launchPath = @"/bin/bash";
            task.arguments = @[@"-l", @"-c", @"killall Onycap"];
            
            @try {
                [task launch];
                DDLogInfo(@"terminate onycap");
            } @catch (NSException *e) {
                DDLogError(@"onycap terminate error = %@", e.reason);
            }*/
            
            [itemInfo hardKeyEvent:3 longpress:0];//mg//앱 실행 화면에서 삭제하면 검정 화면이 표시되는 사례가 있으므로, 홈화면으로 바꾸고 삭제
            [itemInfo hardKeyEvent:3 longpress:0];//mg//앱 실행 화면에서 삭제하면 검정 화면이 표시되는 사례가 있으므로, 홈화면으로 바꾸고 삭제
            
            [itemInfo stopAgent];

            if( [[itemInfo getLaunchBundleId] length] ) {
                const uint8_t * clear = (packet ? (uint8_t *)packet.bytes : NULL);
                if( clear ) {
                    if ((int)clear[0] == 0)// packet 이 존재하며, clear == 0 인 상태 앱을 삭제 하지 않는다.
                        return;
                }
                
                 // !packet 기존 아무것도 없을때, clear == 1 clear 명령을 받을 때
                [itemInfo removeInstalledApp:NO];          // Clear 명령을 받으면 resetAppium 의 결과과 도달할 때 까지 기대렸다가 호출되는것으로 변경됨.
            }//if : 시작할 때 앱 설치
        });//info queue
    }
}//processEndConnectionByPacket

/// @brief wakeup command 수신되어 호출되는데 iPhne 은 해당 기능이 없어 테스트 하는 용도로 사용함. 배포시 아래 함수 내용을 주석처리 해야함.
- (void)__processWakeupByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif
    
    __block __typeof__(self) blockSelf = self;
    dispatch_async(infoQueue, ^(void){
        NSString *path = [[NSString alloc] initWithData:packet encoding: NSUTF8StringEncoding];
        
        path = @"Safari";
        DDLogWarn(@"===== CMD_INSTALL %@  ============ %d", path, argDeviceNo);
        
        if ((path == nil) || ([path length] <= 0)) {
            return;
        }
        
        ConnectionItemInfo* itemInfo = [blockSelf.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) {
            [blockSelf commonResponse:NO deviceNo:argDeviceNo];
        } else {
            DDLogWarn(@"path = %@",path);
            [itemInfo installApplication:path];
        }
    });
}

/// @brief FIXME: Tap. 탭실행.
- (void)__processTapByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif

    __block __typeof__(self) blockSelf = self;
    dispatch_async(infoQueue, ^(void){
        NSData *x = [packet subdataWithRange:NSMakeRange(0, 2)];
        short nX  = CFSwapInt16HostToBig(*(short *)([x bytes]));
        NSData *y = [packet subdataWithRange:NSMakeRange(2, 2)];
        short nY  = CFSwapInt16HostToBig(*(short *)([y bytes]));
        
        DDLogWarn(@"=====CMD_TAP====== tap %d, %d =============", (short)nX, (short)nY);
        
        //mg//
        if (_bStopTask)
            return;
        
        ConnectionItemInfo* itemInfo = [blockSelf.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo != nil)
            [itemInfo doTapAtX:nX andY:nY];
    });
}

/// @brief FIXME:  터치 이벤트 제어.  Drag & Drop
- (void)__processDownMoveUpByPacket:(NSData *)packet command:(NSInteger)cmd deviceNo:(int)argDeviceNo {
    
#ifdef DEBUG
    DDLogInfo(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif
    __block __typeof__(self) blockSelf = self;
    dispatch_async(infoQueue, ^(void){
        NSData *x = [packet subdataWithRange:NSMakeRange(0, 2)];
        short nX  = CFSwapInt16HostToBig(*(short *)([x bytes]));
        NSData *y = [packet subdataWithRange:NSMakeRange(2, 2)];
        short nY  = CFSwapInt16HostToBig(*(short *)([y bytes]));
        
        ConnectionItemInfo* itemInfo = [blockSelf.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) return;
        
        //mg//
        if (_bStopTask)
            return;
        
        if (cmd == CMD_TOUCH_DOWN) {
            DDLogInfo(@"===== DOWN ====== tap %d, %d =============", (short)nX, (short)nY);
            [itemInfo doTouchStartAtX:nX andY:nY];
        } else if (cmd == CMD_TOUCH_MOVE) {
//            DDLogInfo(@"===== MOVE ====== tap %d, %d =============", (short)nX, (short)nY);
            [itemInfo doTouchMoveAtX:nX andY:nY];
        } else if (cmd == CMD_TOUCH_UP) {
            DDLogInfo(@"===== UP ====== tap %d, %d =============", (short)nX, (short)nY);
            [itemInfo doTouchEndAtX:nX andY:nY];
            [blockSelf commonResponse:YES deviceNo:argDeviceNo];//mg//
        }
    });
}

/// @brief Web Client 에서 사용자가 키보드의 Ctrl 키를 누르게 되면 마우스로 좌표를 2개 입력할 수 있음. 이 상태에서 Drag & Drop 으로 줌 인/아웃 기능을 동작 시킬 수 있음.
- (void)__processMultiTouchDownMoveUpByPacket:(NSData *)packet command:(NSInteger)cmd deviceNo:(int)argDeviceNo {
    
#ifdef DEBUG
    DDLogInfo(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif
    
    __block __typeof__(self) blockSelf = self;
    dispatch_async(infoQueue, ^(void){
        NSData *x1 = [packet subdataWithRange:NSMakeRange(0, 2)];
        short nX1  = CFSwapInt16HostToBig(*(short *)([x1 bytes]));
        NSData *y1 = [packet subdataWithRange:NSMakeRange(2, 2)];
        short nY1  = CFSwapInt16HostToBig(*(short *)([y1 bytes]));
        
        NSData *x2 = [packet subdataWithRange:NSMakeRange(4, 2)];
        short nX2 = CFSwapInt16HostToBig(*(short *)([x2 bytes]));
        NSData *y2 = [packet subdataWithRange:NSMakeRange(6, 2)];
        short nY2 = CFSwapInt16HostToBig(*(short *)([y2 bytes]));
        
//        DDLogInfo(@"Cmd : %d, x1 : %d, y1 : %d, x2 : %d, y2: %d",cmd, nX1, nY1, nX2, nY2);
        
        ConnectionItemInfo* itemInfo = [blockSelf.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) return;
        
        //mg//
        if (_bStopTask)
            return;
        
        NSPoint point1 = NSMakePoint((CGFloat)nX1, (CGFloat)nY1);
        NSPoint point2 = NSMakePoint((CGFloat)nX2, (CGFloat)nY2);
        
        if (cmd == CMD_MULTI_TOUCH_DOWN) {
//            DDLogInfo(@"===== DOWN ====== tap %d, %d =============", (short)nX, (short)nY);
            [itemInfo doMultiTouchStartAtPoint1:point1 andPoint2:point2];
        } else if (cmd == CMD_MULTI_TOUCH_MOVE) {
//            DDLogInfo(@"===== MOVE ====== tap %d, %d =============", (short)nX, (short)nY);
//            [itemInfo doTouchMoveAtX:nX andY:nY];
            [itemInfo doMultiTouchMoveAtPoint1:point1 andPoint2:point2];
        } else if (cmd == CMD_MULTI_TOUCH_UP) {
//            DDLogInfo(@"===== UP ====== tap %d, %d =============", (short)nX, (short)nY);
            [itemInfo doMultiTouchEndAtPoint1:point1 andPoint2:point2];
        }
    });
}

/// @brief  터치 이벤트 제어. Swipe.
- (void)__processSwipeByPacket:(NSData *)packet command:(NSInteger)cmd deviceNo:(int)argDeviceNo {
    
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif

    __block __typeof__(self) blockSelf = self;
    dispatch_async(infoQueue, ^(void){
        NSData *x1 = [packet subdataWithRange:NSMakeRange(0, 2)];
        short nX1  = CFSwapInt16HostToBig(*(short *)([x1 bytes]));
        NSData *y1 = [packet subdataWithRange:NSMakeRange(2, 2)];
        short nY1  = CFSwapInt16HostToBig(*(short *)([y1 bytes]));
        NSData *x2 = [packet subdataWithRange:NSMakeRange(4, 2)];
        short nX2  = CFSwapInt16HostToBig(*(short *)([x2 bytes]));
        NSData *y2 = [packet subdataWithRange:NSMakeRange(6, 2)];
        short nY2  = CFSwapInt16HostToBig(*(short *)([y2 bytes]));
        
        DDLogWarn(@"===== CMD_SWIPE ====== 1 : %d , %d --  2 : %d , %d  =============", (short)nX1, (short)nY1, (short)nX2, (short)nY2);
        
        ConnectionItemInfo* itemInfo = [blockSelf.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) return;
        
        //mg//
        if (_bStopTask)
            return;

        [itemInfo  doSwipeAtX1:nX1 andY1:nY1 andX2:nX2 andY2:nY2];
    });
}

/// @brief 하드키(Lock, Home, Volume) 동작. (Lock, Home 미구현)
- (void)__processHardKeyByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif
    
    // type 0 : press, 1 : longpress
    const uint8_t * type = (uint8_t *)[packet subdataWithRange:NSMakeRange(0, 1)].bytes;
    NSInteger nType  = type[0];
    NSData* key = [packet subdataWithRange:NSMakeRange(1, 2)];
    short nKey  = CFSwapInt16HostToBig(*(short*)([key bytes]));
    
    DDLogWarn(@"======CMD_HARDKEY===== %d, %d =============", (int)nType, (int)nKey);
    
    dispatch_async(infoQueue, ^(void){
        ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) return;
        
        //mg//
        if (_bStopTask)
            return;

        [itemInfo hardKeyEvent:nKey longpress:(int)nType];
        [self commonResponse:YES deviceNo:argDeviceNo];//mg//
    });
}

/// @brief 앱설치. ideviceinstaller 이용.
/// @brief 자동화 기능은 앱 설치후 앱을 바로 실행함.
/// @brief 메뉴얼 기능은 Web Client 에서 "자동으로 앱 실행" 체크 여부에 따라, DC 로 부터 RunApp command 가 Install 후 들어오거나 안들어 오게 됨.
- (void)__processInstallCommandByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
    DDLogDebug(@"%s", __FUNCTION__);
    
    __block __typeof__(self) blockSelf = self;
    dispatch_async(infoQueue, ^(void){
        NSString *path = [[NSString alloc] initWithData:packet encoding: NSUTF8StringEncoding];
        //DDLogVerbose(@"===== CMD_INSTALL %@  ============ %d", path, argDeviceNo);
        DDLogInfo(@"install : %@", path);

        if ((path == nil) || ([path length] <= 0)) {
            //mg//[self commonResponseForInstall:NO appId:@"빈칸" deviceNo:argDeviceNo];
            [self commonResponseForInstall:NO appId:@"File Path Error" deviceNo:argDeviceNo];//mg//
            return;
        }
        
        //mg//
        if (_bStopTask)
            return;

        ConnectionItemInfo* itemInfo = [blockSelf.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        //mg//if(itemInfo == nil) {
            //mg//[blockSelf commonResponse:NO deviceNo:argDeviceNo];
        if(itemInfo != nil) {
            //DDLogWarn(@"path = %@",path);
            
            itemInfo.bInstalling = YES;
            [itemInfo installApplication:path];
        }
    });//infoQueue
}//__processInstallCommandByPacket

/// @brief  OpenUrl. 웹페이지 열기. (swccc)
/// @brief ResourceMornitor App 을 WebDriverAgent 를 실행한뒤 BundleID 로 실행한뒤 OpenURL 기능을 사용하는게 좋을거 같음.
/// @param packet url 정보
- (void)__processOpenURLByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif
    
    __block __typeof__(self) blockSelf = self;
    dispatch_async(infoQueue, ^(void) {

        ConnectionItemInfo* itemInfo = [blockSelf.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) return;
        
        NSString *url = [[NSString alloc] initWithData:packet encoding: NSUTF8StringEncoding];
        DDLogWarn(@"===== URL : %@  ============ %d", url, argDeviceNo);
        
        if ((url == nil) || ([url length] <= 0)) {
            return;
        }
        
        //mg//
        if (_bStopTask)
            return;

        NSString* safari = [NSString stringWithFormat:@"%@|%@",CMD_SAFARI,url];
        
        [itemInfo sendOpenURL:url];
    });
    
//    [self commonResponse:NO deviceNo:argDeviceNo];
}

/// @brief Start Monitoring. 리소스 모니터링 시작.
/// @bug 일부 단말에서 Network 정보를 전송하지 않는 버그가 있어 디버깅 해야 함.
- (void)__processStartResourceMonitoringByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif
    
    __block __typeof__(self) blockSelf = self;
    dispatch_async(infoQueue, ^(void) {
        // modify by leehh
        //--------- 제외.
        // argDeviceNo 는 1 부터 시작함..
        const uint8_t *resType = (uint8_t *)[packet subdataWithRange:NSMakeRange(0, 1)].bytes;
        NSInteger nResType  = resType[0];
        const uint8_t *reqType = (uint8_t *)[packet subdataWithRange:NSMakeRange(1, 1)].bytes;
        NSInteger nReqType  = reqType[0];
        
        DDLogWarn(@"===========CMD_RES_START %d, %d=============", (int)nReqType, (int)nResType);
        
        ConnectionItemInfo* itemInfo = [blockSelf.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) return;
        
        //mg//
        if (_bStopTask)
            return;

        switch (nResType) {
            case TYPE_CPU: {
                [itemInfo sendResourceMornitorCommand:CMD_CPU_ON autoConnect:YES];
            }   break;
            case TYPE_MEMORY: {
                [itemInfo sendResourceMornitorCommand:CMD_MEMORY_ON autoConnect:YES];
            }   break;
            case TYPE_NETWORK: {
                [itemInfo sendResourceMornitorCommand:CMD_NETWORK_ON autoConnect:YES];
            }   break;
        }
    }) ;
    // ~
}

/// @brief: Stop Monitoring. 리소스 모니터링 종료.
- (void)__processStopResourceMonitoringByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif

    __block __typeof__(self) blockSelf = self;
    dispatch_async(infoQueue, ^(void) {
        const uint8_t *resType = (uint8_t *)[packet subdataWithRange:NSMakeRange(0, 1)].bytes;
        NSInteger nResType  = resType[0];
        
        DDLogWarn(@"===========CMD_RES_STOP -- type : %d=============", (int)nResType);
        
        ConnectionItemInfo* itemInfo = [blockSelf.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) return;
        
        //mg//
        if (_bStopTask)
            return;
        
        switch (nResType) {
            case TYPE_CPU: {
                [itemInfo sendResourceMornitorCommand:CMD_CPU_OFF autoConnect:NO];
            }   break;
            case TYPE_MEMORY: {
                [itemInfo sendResourceMornitorCommand:CMD_MEMORY_OFF autoConnect:NO];
            }   break;
            case TYPE_NETWORK: {
                [itemInfo sendResourceMornitorCommand:CMD_NETWORK_OFF autoConnect:NO];
            }   break;
        }
    });
}

/// @brief Setting. 환경설정 진입. (미구현)
- (void)__processSettingsCommandByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif
    
    [self commonResponse:NO deviceNo:argDeviceNo];
}

/// @brief 키보드 이벤트 처리. 문제의 Remote Keyboard 기능임.
/// @brief 이 기능에 문제가 상당히 많은데... Web Client 에서 이벤트가 지속적으로 발생됨.. 근데 정상이라 함!! 불필요한 동작을 막기 위해 문자 범위를 지정해서 걸러줌... 그래서 문자이외엔 처리가 안됨.
/// @param packet 아스키 코드값
- (void)__processKeyboardEventByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif
    
    dispatch_async(infoQueue, ^(void){
        ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) {
            [self commonResponse:NO deviceNo:argDeviceNo];
        } else {
            NSData * data = [packet subdataWithRange:NSMakeRange(0, 4)];
            NSInteger tempData = CFSwapInt32BigToHost(*(int*)([data bytes]));
            if( tempData < 64) {
                DDLogError(@"%s, %d -- 잘못된 데이터 : %d", __FUNCTION__, argDeviceNo, (int)tempData);
                return ;
            }
            
            //mg//
            if (_bStopTask)
                return;

            NSData * resultData = [self reverseMutableData:data];
            [itemInfo inputRemoteKeyboardByKey:resultData];
        }
    });
}

/// @brief  로그 전송 시작.
/// @brief 로그 레벨이 안드로이드 기준이라 로그기준을 새로 정해서 작업해줘야 함...
/// @brief 때에 따라 deviceconsole 에 App 에서 NSLog 로 출력한 로그가 안나오는 경우가 있는거 같음.
/// @param packet 로그레벨, 로그 검색 키워드 (Install 에 대한 Response 를 보낼때 App 이름을 넣어주는데 그 값이 검색키워드로 넘어옴.)
- (void)__processStartLogByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif
    dispatch_async(infoQueue, ^(void){
        NSString *search = [[NSString alloc] initWithData:packet encoding: NSUTF8StringEncoding];
        DDLogWarn(@"====== START_LOG %@======", search);
        NSArray *infos = [search componentsSeparatedByString:@":"];
        
        char theLogLevel ='V';
        NSString *theLogSearch = nil;
        NSString *theLogIdentifier = nil;
//
//        if ([infos count] == 2) {
//            theLogSearch = [infos objectAtIndex:0];
//            NSString *strtmp = [infos objectAtIndex:1];
//            NSArray *infos2 = [strtmp componentsSeparatedByString:@"\n"];
//            if ([infos2 count] < 2) {
//                theLogLevel = [[infos2 objectAtIndex:0] characterAtIndex:0];
//                theLogIdentifier = @"*";
//            } else {
//                theLogLevel = [[infos2 objectAtIndex:0] characterAtIndex:0];
//                theLogIdentifier = [infos2 objectAtIndex:1];
//            }
//        }
        if([infos count] == 2){
            theLogSearch = [infos objectAtIndex:0];
            theLogLevel = [[infos objectAtIndex:1] characterAtIndex:0];
            theLogIdentifier = @"*";
            
        }else{
            return ;
        }
        
        
//        DDLogInfo(@"===== log : %@, %c", logSearch, gLoglvl);
        ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) return;
        
        //mg//
        if (_bStopTask)
            return;

        [itemInfo startLogSearch:theLogSearch identifier:theLogIdentifier level:theLogLevel];
    });
}

/// @brief 로그 전송 종료.
- (void)__processEndLogByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif
    ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
    if(itemInfo == nil) return;
    [itemInfo stopLog];
}

//mg//
/// @brief 설치된 앱 리스트 요청.
- (void)__processAppListByPacket:(NSData *)packet deviceNo:(int)argDeviceNo launch:(bool)bLaunch{
    DDLogDebug(@"%s", __FUNCTION__);
    
    dispatch_async(infoQueue, ^(void){
        ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) return;
        
        if (_bStopTask)
            return;
        
        NSString * strAppList = @"";
//        NSArray *appList = [((NSArray *)[itemInfo getAppListForDevice:NO]) copy];
        NSMutableArray* appList = (NSMutableArray *)[itemInfo getAppListForDevice:NO];
        
        if (appList != nil)
            strAppList = [appList componentsJoinedByString:@"\n"];
        
        NSData* resData = [strAppList dataUsingEncoding:NSUTF8StringEncoding];
        NSData* packetData = [self makePacket:CMD_SEND_APPLIST data:resData deviceNo:argDeviceNo];
        
        GCDAsyncSocket * targetSocket = [self getSendTargetSocket:argDeviceNo];
        //send
        if(targetSocket.isConnected )
            [targetSocket writeData:packetData withTimeout:-1 tag:0];
    });
}


//mg//
/*- (void)__processAppListByPacket:(NSData *)packet deviceNo:(int)argDeviceNo launch:(bool)bLaunch{
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif
    
    dispatch_async(infoQueue, ^(void){
        ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) return;
        
        GCDAsyncSocket * targetSocket = [self getSendTargetSocket:argDeviceNo];
        
        NSString * strAppList = [itemInfo getMyAppListForStart];
        
        //DDLogWarn(@"==================== AppList START ========================");
        //DDLogWarn(@"%@", strAppList);
        //DDLogWarn(@"==================== AppList END ========================");
        
        NSData* resData = [strAppList dataUsingEncoding:NSUTF8StringEncoding];
        NSData* packetData = [self makePacket:CMD_SEND_APPLIST data:resData deviceNo:argDeviceNo];
        
        dispatch_async(dispatch_get_main_queue(), ^{
        if( !targetSocket.isConnected ) {
            //DDLogError(@"socket 이 연결이 되어 있지 않음 ");
            return ;
        }
        [targetSocket writeData:packetData withTimeout:-1 tag:0];
        });
    });
}*/

/// @brief 설치된 앱 삭제
/// @brief 이 명령엔 문제점이 있는데 Web Client 에서 앱만 삭제하는 기능이 있어서 이 명령이 호출되었을 때 앱을 삭제만 하면 STOP 명령과 겹치는 부분이 있음.
/// @brief WebClient 에서 종료를 하게 되면.. Clear 가 먼저 발생하고 STOP 이 발생하게 됨. 실행중인 앱을 삭제하게 되면 앱이 종료되어 사용자는 앱이 종료된걸 보다가 Device 제어창이 닫아지는 상황을 보게됨.
/// @brief 전혀 상관이 없다면.. 그냥 Clear 수신시 앱 삭제하는 기능을 넣으면 됨.
/// @bug 앲 삭제 기능이 없음.
- (void)__processClearCommandByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
    DDLogDebug(@"%s", __FUNCTION__);
    
    dispatch_async(infoQueue, ^(void){
        //mg//
        if (_bStopTask)
            return;
        
        ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo != nil) {
//            [itemInfo resetDevice];
//            [itemInfo waitForServerStop];
            
            [itemInfo removeInstalledApp:YES];
            
            [self commonResponseClear:YES msg:@"" deviceNo:argDeviceNo];
        }
    });
}

/// @brief Input Text. 아이폰에 키보드가 있어야 입력됨.
- (void)__processInputTextByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif
    dispatch_async(infoQueue, ^(void){
        //mg//
        if (_bStopTask)
            return;

        ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        
        //mg//
        /*if(itemInfo == nil) {
            [self commonResponse:NO deviceNo:argDeviceNo];
        } else {*/
        
        if(itemInfo != nil) {//mg//
            if( 4 <= packet.length ) {
                NSData * subData = [packet subdataWithRange:NSMakeRange(0, 4)];
                NSInteger data = CFSwapInt32BigToHost(*(int*)([subData bytes]));
                if( data < 64 ) {
                    DDLogError(@"%s 잘못된 데이터 = %d", __FUNCTION__, (int)data);
                    
                    [self commonResponse:NO reqCmd:CMD_INPUT_TEXT msg:@"Data Error" deviceNo:argDeviceNo];//mg//
                    return ;
                }
            }
            
            NSString * msg = [[NSString alloc] initWithData:packet encoding:NSUTF8StringEncoding];
            [itemInfo inputTextByString:msg];

            //swccc수정
//            [self commonResponse:YES deviceNo:argDeviceNo];
        }//if - else : 단말기 확인
    });//dispatch_async
}//__processInputTextByPacket

/// @brief 덤프파일 요청. 객체분석 요청임. 아이폰 현재 화면의 객체를 붐석하여 XML 로 만들어 DC 로 전달함.
- (void)__processRequstDumpFileByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif
    
    dispatch_async(infoQueue, ^(void){
        //mg//
        if (_bStopTask)
            return;

        ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) {
            [self commonResponse:NO reqCmd:CMD_REQ_DUMP msg:@"" deviceNo:argDeviceNo];
        } else {
            NSString *url = [[NSString alloc] initWithData:packet encoding: NSUTF8StringEncoding];
            [itemInfo uploadDumpFile:url];
        }
    });
}

/// @brief 자동화 엘레먼트 선택.
- (void)__processAutoSelectByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif

    dispatch_async(infoQueue, ^(void){
        //mg//
        if (_bStopTask)
            return;

        ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) {
            [self commonResponse:NO deviceNo:argDeviceNo];
        } else {
            //        [itemInfo autoSelect:packet];
            [itemInfo automationSearch:packet andSelect:YES];
        }
    });
}

/// @brief 자동화 엘레먼트 검색.
- (void)__processAutoSearchByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif
    
    dispatch_async(infoQueue, ^(void){
        //mg//
        if (_bStopTask)
            return;

        ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) {
            [self commonResponse:NO deviceNo:argDeviceNo];
        } else {
            //        [itemInfo autoSearch:packet];
            [itemInfo automationSearch:packet andSelect:NO];
        }
    });
}

/// @brief 자동화 엘레먼트를 찾아서 텍스트입력.
- (void)__processAutoInputTextByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif

    dispatch_async(infoQueue, ^(void){
        //mg//
        if (_bStopTask)
            return;

        ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) {
            [self commonResponse:NO deviceNo:argDeviceNo];
        } else {
            [itemInfo autoInputText:packet];
        }
    });
}

/// @brief 자동화 리소스 요청. 자동화는 리소스 기능이 없음. 추후 추가될 수 있는데 메뉴얼의 리소스 기능을 사용하면 됨.
/// @brief 단, 리소스 앱을 실행하는 방식을 교체한뒤 사용하는게 좋을것임.
- (void)__processAutoResourceByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif

    dispatch_async(infoQueue, ^(void){
        ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) {
            [self commonResponse:NO deviceNo:argDeviceNo];
        } else {

        }
    });
}

/// @brief 자동화 Orientation 변경
- (void)__processAutoOrientationByPacket:(NSData *)packet state:(BOOL)bLand deviceNo:(int)argDeviceNo {
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif
    
    if( bLand) {
        DDLogInfo(@"CMD_LANDSCAPE(%d)", argDeviceNo);
    } else {
        DDLogInfo(@"CMD_PORTRAIT(%d)", argDeviceNo);
    }

    dispatch_async(infoQueue, ^(void) {
        //mg//
        if (_bStopTask)
            return;

        ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) {
            [self commonResponse:NO deviceNo:argDeviceNo];
        } else {
            [itemInfo autoOrientation:bLand];
            [self commonResponse:YES deviceNo:argDeviceNo];//mg//
        }
    });
}

/// @brief 자동화 어플 재시작.
- (void)__processAutoRunAppByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
#ifdef DEBUG
    DDLogWarn(@"%s, %d", __FUNCTION__, argDeviceNo);
#endif
    
    DDLogInfo(@"CMD_AUTO_RUNAPP(%d)", argDeviceNo);
    //    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
    dispatch_async(infoQueue, ^(void){
        //mg//
        if (_bStopTask)
            return;

        ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) {
            [[CommunicatorWithDC sharedDCInterface] commonResponse:NO reqCmd:CMD_RESPONSE msg:@"연결 정보 없음." deviceNo:argDeviceNo];
        } else {
//            [[CommunicatorWithDC sharedDCInterface] commonResponse:YES reqCmd:CMD_RESPONSE msg:@"" deviceNo:argDeviceNo];
            // 흠... 이상함.. 예전엔 설치후 바로 실행했었고, 잘 동작 했었는데.. 지금은 ... 설치후 응답하고, Runapp 이 도착했을때 바로 실행하면... 앱이 실행되다 멈춰버림...
            // 일단.. 이렇게 해두고.. 나중에... 시간 되면.. 그때 알아봄.. 그때가 올런지...
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSString * bundleId = [[NSString alloc] initWithData:packet encoding:NSUTF8StringEncoding];
                [itemInfo autoRunApp:bundleId];
            });
        }
    });
}

/// @brief 설정 앱 실행 여부를 결정함. 관리자 페이지에 해당 정보를 설정할 수 있음.
- (void) __processLockAndUnlockByPacket:(NSData *)packet deviceNo:(int)argDeviceNo {
    DDLogDebug(@"%s", __FUNCTION__);
    
    dispatch_async(infoQueue, ^(void){
        //mg//
        if (_bStopTask)
            return;

        ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo != nil) {
//            [itemInfo autoRunApp];
            [itemInfo lockSetting:packet];
        }
    });
}

//mg//20180509//uninstall
- (void) __processUninstallByPacket:(NSData *)packetData deviceNo:(int)argDeviceNo {
    dispatch_async(infoQueue, ^(void){
        if (_bStopTask)
            return;

        ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
        if(itemInfo == nil) {
            [self commonResponse:NO reqCmd:CMD_UNINSTALL msg:@"Device Error" deviceNo:argDeviceNo];
        } else {
            //앱 실행 화면에서 삭제하면 검정 화면이 표시되는 사례가 있으므로, 홈화면으로 바꾸고 삭제
            [itemInfo hardKeyEvent:3 longpress:0];

            NSString *bundleId = [[NSString alloc] initWithData:packetData encoding:NSUTF8StringEncoding];
            [itemInfo removeApp:bundleId];
            
            //response
            [self commonResponse:YES reqCmd:CMD_UNINSTALL msg:@"" deviceNo:argDeviceNo];
        }
    });
}

/*
 CMD_CLEAR --> commonResponseClear call 하면 된다.
 
 CMD_INSTALL
 CMD_OPENURL
 CMD_SETTING
 CMD_INPUT_TEXT
 
 --> CommonResponse를 Yes, No로 보낸다.
 */

/// @brief 파싱된 데이터로 동작 결정.
//packetData : 패킷의 데이터 부분
- (void)doActionByPacketCommand:(NSInteger)cmd deviceNo:(int)argDeviceNo packetData:(NSData *)data size:(int)dataSize {
    DDLogDebug(@"%s", __FUNCTION__);
    DDLogInfo(@"packet from DC = %d", (int)cmd);
    //DC창에 명령어 로그 추가
//    DCLog(@"%d",(int)cmd);
    
    NSString* message = [NSString stringWithFormat:@"%d",(int)cmd];
    [[NSNotificationCenter defaultCenter] postNotificationName:DEVICE_LOG object:message userInfo:nil];
    
    if (argDeviceNo < 1 || argDeviceNo > 20) {
        return;
    }
    
    switch (cmd) {
        case CMD_START_MAN:{
            [self __processStartConnectionByPacket:data isManual:YES deviceNo:argDeviceNo];
        }
            break;
        case CMD_START_AUTO:{
            [self __processStartConnectionByPacket:data isManual:NO deviceNo:argDeviceNo];
        }
            break;
        case CMD_STOP:{
            [self __processEndConnectionByPacket:data deviceNo:argDeviceNo];
        }
            break;
        case CMD_WAKEUP:{
            [self __processWakeupByPacket:data deviceNo:argDeviceNo];
        }
            break;
        case CMD_TAP:{
            [self __processTapByPacket:data deviceNo:argDeviceNo];
        }
            break;
        case CMD_TOUCH_DOWN:
        case CMD_TOUCH_UP:
        case CMD_TOUCH_MOVE:
        {
            [self __processDownMoveUpByPacket:data command:cmd deviceNo:argDeviceNo];
        }
            break;
        case CMD_SWIPE:{
            [self __processSwipeByPacket:data command:cmd deviceNo:argDeviceNo];
        }   break;
            
        case CMD_MULTI_TOUCH_DOWN:
        case CMD_MULTI_TOUCH_UP:
        case CMD_MULTI_TOUCH_MOVE: {
            [self __processMultiTouchDownMoveUpByPacket:data command:cmd deviceNo:argDeviceNo];
        }   break;
            
        case CMD_HARDKEY:{
            [self __processHardKeyByPacket:data deviceNo:argDeviceNo];
        }
            break;
        case CMD_INSTALL:{
            [self __processInstallCommandByPacket:data deviceNo:argDeviceNo];             // test leehh
        }
            break;
        case CMD_OPENURL:{
            [self __processOpenURLByPacket:data deviceNo:argDeviceNo];
        }
            break;
        case CMD_RES_START:{
            [self __processStartResourceMonitoringByPacket:data deviceNo:argDeviceNo];    // modify by leehh
        }
            break;
        case CMD_RES_STOP:{
            [self __processStopResourceMonitoringByPacket:data deviceNo:argDeviceNo];     // modify by leehh
        }
            break;
        case CMD_SETTING:{
            [self __processSettingsCommandByPacket:data deviceNo:argDeviceNo];
        }
            break;
        case CMD_KEYBOARD:{
            [self __processKeyboardEventByPacket:data deviceNo:argDeviceNo];
        }
            break;
        case CMD_LOG_START:{
            [self __processStartLogByPacket:data deviceNo:argDeviceNo];
        }
            break;
        case CMD_LOG_STOP:{
            [self __processEndLogByPacket:data deviceNo:argDeviceNo];
        }
            break;
        case CMD_REQ_APPLIST:{
            [self __processAppListByPacket:data deviceNo:argDeviceNo launch:NO];
        }
            break;
        case CMD_CLEAR:{
            [self __processClearCommandByPacket:data deviceNo:argDeviceNo];
        }
            break;
        case CMD_INPUT_TEXT:{
            [self __processInputTextByPacket:data deviceNo:argDeviceNo];
        }
            break;
        case CMD_REQ_DUMP:{
            [self __processRequstDumpFileByPacket:data deviceNo:argDeviceNo];
        }
            break;
        case CMD_AUTO_SELECT:{
            [self __processAutoSelectByPacket:data deviceNo:argDeviceNo];
        }
            break;
        case CMD_AUTO_SEARCH:{
            [self __processAutoSearchByPacket:data deviceNo:argDeviceNo];
        }
            break;
        case CMD_AUTO_INPUT:{
            [self __processAutoInputTextByPacket:data deviceNo:argDeviceNo];
        }
            break;
        case CMD_RES_ONCE:{
            [self __processAutoResourceByPacket:data deviceNo:argDeviceNo];
        }
            break;
        case CMD_PORTRAIT:{
            [self __processAutoOrientationByPacket:data state:NO deviceNo:argDeviceNo];
        }
            break;
        case CMD_LANDSCAPE:{
            [self __processAutoOrientationByPacket:data state:YES deviceNo:argDeviceNo];
        }
            break;
        case CMD_AUTO_RUNAPP:{
            [self __processAutoRunAppByPacket:data deviceNo:argDeviceNo];
        }
            break;
        case CMD_LOCK_UNLOCK: {
//            [self __processLockAndUnlockByPacket:packet deviceNo:argDeviceNo];
        }   break;
            //mg//20180509//uninstall 추가
        case CMD_UNINSTALL:{
            [self __processUninstallByPacket:data deviceNo:argDeviceNo];
        }
            break;
        default: {
            
        }   break;
    }
}

#pragma mark -
#pragma mark StartAndInstall Timer
/// @brief 예전에 Start 후 Install 명령이 순차적으로 들어왓었는데 가끔 예외적으로 Start 후 Install 이 안들어오고 무한 대기 하는 경우가 있었음..  이런 상태에 대한 예외 처리로 30초 타이머를 실행시킴.
/// @brief 현재는 사용하지 않지만, Appium 을 사용하는 버전, WebClient 에서 예전 버전을 사용한 다면 사용할 수 잇어 남겨둠...
- (void) onStartIntervalTimer:(NSTimer *)theTimer {
    NSNumber * deviceNo = [theTimer userInfo];
    
    [self commonResponseForInstall:NO appId:@"Start후 30초간 Install 이 안들어옴." deviceNo:deviceNo.intValue];
}

#pragma mark -
#pragma mark Transmission Data Managing

/// @brief 데이터 리버스.(MutableData)   BigEndian/LittleEndian 변환 정도로 이해함.
- (NSMutableData *)reverseMutableData:(NSMutableData *)data {
    
    const char *bytes = (char *)[data bytes];
    char *reverseBytes = (char *)(malloc(sizeof(char) * [data length]));
    int index = (int)([data length] - 1);
    for (int i = 0; i < [data length]; i++) {
        reverseBytes[index--] = bytes[i];
    }
    
    NSMutableData *reversedData = [NSMutableData dataWithBytes:reverseBytes length:[data length]];
    return reversedData;
}

/// @brief 데이터 리버스.(MutableData)   BigEndian/LittleEndian 변환 정도로 이해함..
- (NSData *)reverseData:(NSData *)data {
    
    const char *bytes = (char *)[data bytes];
    char *reverseBytes = (char *)(malloc(sizeof(char) * [data length]));
    int index = (int)([data length] - 1);
    for (int i = 0; i < [data length]; i++) {
        reverseBytes[index--] = bytes[i];
    }
    
    NSData *reversedData = [NSData dataWithBytes:reverseBytes length:[data length]];
    return reversedData;
}

/// @brief D.C에 전송할 데이터 패킷 생성
- (NSData *)makePacket:(int16_t)command data:(NSData *)data deviceNo:(int)number {
    
    int32_t dataSize = 0;
    if (data != nil) {
        dataSize = (int)[data length];
    }
    int totalSize = 1 + 4 + 2 + 1 + dataSize + 2 + 1;
    
    NSMutableData *sendPacket= [[NSMutableData alloc] init];
    int8_t start = 0x7f;
    int8_t deviceNo = number;
    int8_t end = 0xef;
    
    // make data for reverse
    [sendPacket appendBytes:&end length:1];         //endflag
    [sendPacket appendBytes:&command length:2];     //checksum
    //data//
    [sendPacket appendBytes:&deviceNo length:1];            //device number
    [sendPacket appendBytes:&command length:2];     //command
    [sendPacket appendBytes:&dataSize length:4];      //datasize
    [sendPacket appendBytes:&start length:1];         //startflag
    
    NSMutableData *reverse = [self reverseMutableData:sendPacket];
    if(dataSize > 0) {
        NSMutableData *newData = [[NSMutableData alloc] init];
        [newData appendBytes:[reverse subdataWithRange:NSMakeRange(0, 8)].bytes length:8];  //startflag, datasize, command, devicenumber
        [newData appendBytes:data.bytes length:dataSize];                                   //data
        [newData appendBytes:[reverse subdataWithRange:NSMakeRange(8, 3)].bytes length:3];  //checksum, endflag
        return [newData subdataWithRange:NSMakeRange(0, totalSize)];
    } else {
        return [reverse subdataWithRange:NSMakeRange(0, totalSize)];
    }
}

/// @brief 로그 데이터를 DC 로 전송
- (void)sendLogData:(NSData *)argLogPacket deviceNo:(int)argDeviceNo {
    NSData *logPacketData = [self makePacket:CMD_LOG data:argLogPacket deviceNo:argDeviceNo];
    dispatch_async(dispatch_get_main_queue(), ^{
        GCDAsyncSocket * targetSocket = [self getSendTargetSocket:argDeviceNo];
        [targetSocket writeData:logPacketData withTimeout:-1 tag:0];
    });
}

/// @brief 자동화/메뉴얼을 통합 하기 전까지 임시로 사용하는 코드임.
- (GCDAsyncSocket *) getSendTargetSocket:(int)deviceNo {
    ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:deviceNo];
    GCDAsyncSocket * target = nil;
    
    
    if( CNNT_TYPE_MAN == itemInfo.connectType ) {
        target = connectedSocket;
    }
#ifdef USE_AUTO_MNG
    else if( CNNT_TYPE_AUTO == itemInfo.connectType ) {
        target = autoConnectedSocket;
    }else{
        target = connectedSocket;
    }
#endif
    return target;
}
// ~

// add by leehh
#pragma mark - <ResourceMornitor Delegate>
/// @brief 리소스모니터 앱에서 올려준 데이터를 DC 로 전송함. (CPU, Memory, Network 리소스 정보)
- (void) recvdResourcePacket:(NSData *)packet andDeviceNo:(int)deviceNo {
    // Client 의 Resource Mornitor 에서 올려준 데이터를 그대로 DC 에 넘겨주면 된다.
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // 소스통합전 까지 임시로 사용할 코드
//        [connectedSocket writeData:packet withTimeout:-1 tag:0];
        [[self getSendTargetSocket:deviceNo] writeData:packet withTimeout:-1 tag:0];
    });
}
// ~


#pragma mark - <Send DC>
/// @brief StandAlone 기능임.. 현재는 사용하고 있지 않지만, 나중에 필요할 수 있음. Standalone 기능은 MainViewcontroller 에서 VER_STANDALONE 에의해 막아놨음.
/// @brief VER_STANDALONE 을 푼다고 해도.. 관리를 하지 않아서 버그가 많을 거임..
- (void) sendDeviceChange:(int)type withInfo:(DeviceInfos *)deviceInfo andDeviceNo:(int)argDeviceNo {
    
    GCDAsyncSocket * targetSocket = [self getSendTargetSocket:argDeviceNo];
    
//    if( !connectedSocket.isConnected ) {
    if( !targetSocket.isConnected ) {
        return ;
    }
    
    NSMutableData *sendPacket= [[NSMutableData alloc] init];
    uint8_t utype = (uint8_t)type;
    
    /*
     DeviceClass: iPhone
     DeviceName: HoonHee's iPhone 5s
     ProductName: iPhone OS
     ProductType: iPhone7,1
     ProductVersion: 9.3.4
     */
    
    NSData * dtPlatform = [deviceInfo.productName dataUsingEncoding:NSUTF8StringEncoding];
    NSData * dtProductType = [deviceInfo.productType dataUsingEncoding:NSUTF8StringEncoding];
    NSData * dtUDID = [deviceInfo.udid dataUsingEncoding:NSUTF8StringEncoding];
    NSData * dtProdductVersion = [deviceInfo.productVersion dataUsingEncoding:NSUTF8StringEncoding];
    
    char szPlatform[16] = {0};
    char szProductType[64] = {0};
    char szUDID[64] = {0};
    char szProductionVersion[32] = {0};
    
    memcpy((void *)szPlatform, dtPlatform.bytes, dtPlatform.length);
    memcpy((void *)szProductType, dtProductType.bytes, dtProductType.length);
    memcpy((void *)szUDID, dtUDID.bytes, dtUDID.length);
    memcpy((void *)szProductionVersion, dtProdductVersion.bytes, dtProdductVersion.length);
    
    CGSize resolution = deviceInfo.resolution;
    uint16_t width = CFSwapInt16HostToBig((uint16_t)resolution.width * (uint16_t)deviceInfo.ratio);
    uint16_t height = CFSwapInt16HostToBig((uint16_t)resolution.height * (uint16_t)deviceInfo.ratio);
    
    [sendPacket appendData:[NSData dataWithBytes:&utype length:1]];
    [sendPacket appendData:[NSData dataWithBytes:szPlatform length:16]];
    [sendPacket appendData:[NSData dataWithBytes:szProductType length:64]];
    [sendPacket appendData:[NSData dataWithBytes:szUDID length:64]];
    [sendPacket appendData:[NSData dataWithBytes:szProductionVersion length:32]];
    [sendPacket appendData:[NSData dataWithBytes:&width length:2]];
    [sendPacket appendData:[NSData dataWithBytes:&height length:2]];
    
    NSData *ecoPacket = [self makePacket:CMD_SND_DEVICE_CHANGE data:sendPacket deviceNo:argDeviceNo];
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // 소스통합까지 임시로 사용할 코드
//        [connectedSocket writeData:ecoPacket withTimeout:-1 tag:0];
        [targetSocket writeData:ecoPacket withTimeout:-1 tag:0];
    });
}

#pragma mark -
#pragma mark CommonResponse Func.


/// @brief CommonResponse로 결과를 D.C에 전송. (성공/실패)
- (void)commonResponse:(BOOL)bSueccss deviceNo:(int)argDeviceNo {
    //DDLogDebug(@"%s, suc %d, no %d", __FUNCTION__,   (int)bSueccss, argDeviceNo);
    DDLogWarn(@"%s result = %s", __FUNCTION__, bSueccss? "success":"fail");

    GCDAsyncSocket * targetSocket = [self getSendTargetSocket:argDeviceNo];
    NSData * resData = nil, * ecoPacket = nil;
    
    if (bSueccss) { //success
        char suc = '0';
        resData = [NSData dataWithBytes:&suc length:1];
    } else { //fail
        resData = [@"1\n" dataUsingEncoding:NSUTF8StringEncoding];
    }
    ecoPacket = [self makePacket:CMD_RESPONSE data:resData deviceNo:argDeviceNo];
    
    //mg//
    /*if( [NSThread isMainThread] ) {
        [targetSocket writeData:ecoPacket withTimeout:-1 tag:0];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            // 소스통합까지 임시로 사용할 코드
//            [connectedSocket writeData:ecoPacket withTimeout:-1 tag:0];
            [targetSocket writeData:ecoPacket withTimeout:-1 tag:0];
        });
    }*/
    [targetSocket writeData:ecoPacket withTimeout:-1 tag:0];//mg//
}

//mg//
/*- (void)commonResponseClassIndex:(BOOL)bSueccss elemLabel:(NSString*)label deviceNo:(int)argDeviceNo{
    DDLogInfo(@">>> ResponseClassIndex:result(%d), Dev(%d)", (int)bSueccss, argDeviceNo);
    
    GCDAsyncSocket * targetSocket = [self getSendTargetSocket:argDeviceNo];
    
    NSData * resData = nil, * ecoPacket = nil;
    if (bSueccss) { //success
        NSString* str = [NSString stringWithFormat:@"0\n%@",label];
        resData = [str dataUsingEncoding:NSUTF8StringEncoding];
    } else { //fail
        resData = [@"1\n" dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    ecoPacket = [self makePacket:CMD_RESPONSE data:resData deviceNo:argDeviceNo];
    DDLogWarn(@"%s , size = %d",__FUNCTION__,(int)ecoPacket.length);
    DDLogWarn(@"success = %d, label = %@ (%d)",bSueccss,label,argDeviceNo);
    if( [NSThread isMainThread] ) {
        [targetSocket writeData:ecoPacket withTimeout:-1 tag:0];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [targetSocket writeData:ecoPacket withTimeout:-1 tag:0];
        });
    }
}*/

/// @brief CommonResponse로 Install 에 대한 결과를 DC 에 전달함.
- (void)commonResponseForInstall:(BOOL)bSueccss appId:(NSString*)bundleId deviceNo:(int)argDeviceNo{
    DDLogDebug(@"%s, suc %d, %@, no %d", __FUNCTION__,   (int)bSueccss, bundleId, argDeviceNo);

    NSData * ecoPacket = nil;
    
    if (bSueccss) { //success
        if([bundleId isEqualToString:@"com.onycom.ResourceMonitor2"]){
            bundleId = @"com.apple.MobileSafari";
        }
        
        NSString* str = [NSString stringWithFormat:@"\n%@", bundleId];
        char suc = '0';
        
        NSMutableData *sendPacket= [[NSMutableData alloc] init];
        [sendPacket appendData:[NSData dataWithBytes:&suc length:1]];
        [sendPacket appendData:[str dataUsingEncoding:NSUTF8StringEncoding]];
        
        ecoPacket = [self makePacket:CMD_RESPONSE data:sendPacket deviceNo:argDeviceNo];
    } else { //fail
//        NSData *resData = [@"1\n" dataUsingEncoding:NSUTF8StringEncoding];
        
        NSString* str = [NSString stringWithFormat:@"1\n %@",bundleId];
        NSData* resData = [str dataUsingEncoding:NSUTF8StringEncoding];
        
        ecoPacket = [self makePacket:CMD_RESPONSE data:resData deviceNo:argDeviceNo];
    }
    
    GCDAsyncSocket * targetSocket = [self getSendTargetSocket:argDeviceNo];
    //mg//
    /*if( [NSThread isMainThread] ) {
        [targetSocket writeData:ecoPacket withTimeout:-1 tag:0];
    } else {    
        dispatch_async(dispatch_get_main_queue(), ^{
     */
            [targetSocket writeData:ecoPacket withTimeout:-1 tag:0];
        //});
    //}
    
    ConnectionItemInfo* itemInfo = [self.mainController connectionItemInfoByDeviceNo:argDeviceNo];
    itemInfo.bInstalling = NO;
}//commonResponseForInstall

//mg//
- (void)sendResponse:(BOOL)bSueccss message:(NSString*)msg deviceNo:(int)no {
    DDLogDebug(@"%s result = %@, message = %@", __FUNCTION__,
               bSueccss? @"success":@"fail", msg);
    
    NSData* resData = nil;
    
    if (msg == nil || [msg isEqual:[NSNull null]] || [msg length] ==0) {
        char res = bSueccss? '0':'1';
        resData = [NSData dataWithBytes:&res length:1];
    } else {
        NSString *s = [NSString stringWithFormat:@"%d\n%@", bSueccss? 0:1, msg];
        resData = [s dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    NSData *ecoPacket = [self makePacket:CMD_RESPONSE data:resData deviceNo:no];

    GCDAsyncSocket * targetSocket = [self getSendTargetSocket:no];
    [targetSocket writeData:ecoPacket withTimeout:-1 tag:0];
}

/// @brief CommonResponse로 결과를 D.C에 전송. (성공/실패, cmd, Message)
- (void)commonResponse:(BOOL)bSueccss reqCmd:(int)cmd msg:(NSString *)msg deviceNo:(int)argDeviceNo{
    DDLogWarn(@"%s, suc %d, cmd %d, msg %@,  no %d", __FUNCTION__, bSueccss, cmd, msg, argDeviceNo);
    
    GCDAsyncSocket * targetSocket = [self getSendTargetSocket:argDeviceNo];
    
    NSMutableData *sendPacket= [[NSMutableData alloc] init];
    
    Byte success = (bSueccss)? 0 : 1;
    [sendPacket appendBytes:&success length:1];
    [sendPacket appendBytes:&cmd length:2];
    
    sendPacket = [self reverseMutableData:sendPacket];
    if(msg != nil) {
        if(![msg isEqualToString:@""]){
            [sendPacket appendData:[msg dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    
    NSData *ecoPacket = [self makePacket:CMD_RESPONSE data:sendPacket deviceNo:argDeviceNo];
    // 소스통합까지 임시로 사용할 코드
    //    [connectedSocket writeData:ecoPacket withTimeout:-1 tag:0];
    [targetSocket writeData:ecoPacket withTimeout:-1 tag:0];
}

/// @brief Clear 요청에 대한 Response로 결과를 D.C에 전송.(성공/실패, Message)
- (void)commonResponseClear:(BOOL)bSuccss msg:(NSString *)argMsg deviceNo:(int)argDeviceNo {
    
    DDLogWarn(@"%s, suc %d, msg %@, no %d", __FUNCTION__, bSuccss, argMsg, argDeviceNo);
    
    GCDAsyncSocket * targetSocket = [self getSendTargetSocket:argDeviceNo];
    
    int8_t nSuccess = (bSuccss)? 1:0;
    int16_t nCmd = CMD_CLEAR;
    
    NSMutableData *sendPacket= [[NSMutableData alloc] init];
    [sendPacket appendBytes:&nCmd length:2];
    [sendPacket appendBytes:&nSuccess length:1];
    [sendPacket appendData:[argMsg dataUsingEncoding:NSUTF8StringEncoding]];
    NSData *resData = [NSData dataWithData:sendPacket];
    NSData *ecoPacket = [self makePacket:CMD_RESPONSE data:resData deviceNo:argDeviceNo];
    
//    [connectedSocket writeData:ecoPacket withTimeout:-1 tag:0];
    if( [NSThread isMainThread] ) {
        [targetSocket writeData:ecoPacket withTimeout:-1 tag:0];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [targetSocket writeData:ecoPacket withTimeout:-1 tag:0];
        });
    }
}

/// @brief idevice 에 작업을 요청했는데 응답이 없어 타임아웃으로 끝나면 그 다음부턴 모든 요청은 실패를 하게되어 DC 로 DeviceDisconnect 를 보내주면 Stop 을 DC 로 부터 전달받게 되어 정리를 할 수 있게 된다.
/// @brief WebClient 에도 알림 창이 나타나게 되어 사용자에게 문제가 발생했음을 알려주게 된다.
- (void)responseDeviceDisconnected:(int)argDeviceNo {
    DDLogWarn(@"%s", __FUNCTION__);
    
    GCDAsyncSocket * targetSocket = [self getSendTargetSocket:argDeviceNo];
    
    NSData *ecoPacket = [self makePacket:CMD_DEVICE_DISCONNECTED data:nil deviceNo:argDeviceNo];
//    [connectedSocket writeData:ecoPacket withTimeout:-1 tag:0];
    
    //mg//
    /*if( [NSThread isMainThread] ) {
        [targetSocket writeData:ecoPacket withTimeout:-1 tag:0];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [targetSocket writeData:ecoPacket withTimeout:-1 tag:0];
        });
    }*/

    [targetSocket writeData:ecoPacket withTimeout:-1 tag:0];//mg//
}

@end
