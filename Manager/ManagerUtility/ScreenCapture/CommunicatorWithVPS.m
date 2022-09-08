//
//  CommunicatorWithVPS.m
//  Manager
//
//  Created by SR_LHH_MAC on 2017. 8. 23..
//  Copyright © 2017년 tomm. All rights reserved.
//

#import "CommunicatorWithVPS.h"
#import "GCDAsyncSocket.h"
#import "WTFPacket.h"
#import "ScreenCapture.h"

#import "ControlAgent.h"
#import "DeviceInfo.h"


#define WELCOME_MSG             0
#define ECHO_MSG                1
#define WARNING_MSG             2
#define READ_TAG_MIRROR         3
#define READ_TAG_CONTROL        4

#define READ_TIMEOUT            15.0
#define READ_TIMEOUT_EXTENSION  15.0
#define WRITE_TIMEOUT           15.0
#define WRITE_TIMEOUT_EXTENSION 15.0


@interface CommunicatorWithVPS () <GCDAsyncSocketDelegate, ScreenCaptureDelegate>
@property (nonatomic, strong) GCDAsyncSocket    * mirrorListenSocket;
@property (nonatomic, strong) GCDAsyncSocket    * controlListenSocket;
@property (nonatomic, strong) GCDAsyncSocket    * mirrorSocket;
@property (nonatomic, strong) GCDAsyncSocket    * controlSocket;

@property (nonatomic, strong) ScreenCapture     * myScreenCapture;
@end


@implementation CommunicatorWithVPS

- (id) init {
    self = [super init];
    if( self ) {
        
    }
    
    return self;
}

- (id) initWithCaptureMode:(NSString *)captureMode withDeviceInfos:(DeviceInfos *)deviceInfo withControlAgent:(ControlAgent *)controlAgent {
    self = [super init];
    if( self ) {
        if( [captureMode isEqualToString:SCAPTURE_MODE_POLLING] ) {
            _myScreenCapture = [ScreenCapture createPollingScreenCapture:controlAgent];
        } else {
            _myScreenCapture = [QuickTimeScreenCapture createQuickTimeScreenCapture];
        }
        
        _myScreenCapture.customDelegate = self;
        _myDeviceInfos = deviceInfo;
        _myScreenCapture.devUdid = _myDeviceInfos.udid;
    }
    
    return self;
}

- (void) dealloc {
    _myScreenCapture = nil;
}

#pragma mark - <ScreenCapture Delegate>
- (void) processCapturedImage:(NSData *)data rect:(CGRect)rect bRotate:(BOOL)bNeedRotate isKeyFrame:(BOOL)isKeyFrame {
    if( data == nil || [data length] < 1)
        return ;
    
    int nLength = 17 + data.length + 1;
    unsigned char *bytes = malloc(nLength);  // modify by leehh  +1  추가함..
    memset(bytes, 0, nLength);              // add by leehh
    
    int cursor = 0;
    
    short sCommand = IMAGE_PORTRAIT;
    
    if( bNeedRotate )
    {
        sCommand = IMAGE_LANDSCAPE;
    }
    
    // timestamp
    struct timeval time;
//    gettimeofday(&time, NULL);
    long millis = (time.tv_sec * 1000) + (time.tv_usec / 1000);
    
    *(long*)(bytes+cursor) = CFSwapInt64HostToBig(millis);
    cursor += 8;
    
    // Left
    *(short*)(bytes+cursor) = CFSwapInt16HostToBig((short)rect.origin.x);
    cursor += 2;
    
    // Top
    *(short*)(bytes+cursor) = CFSwapInt16HostToBig((short)rect.origin.y);
    cursor += 2;
    
    // Right
    *(short*)(bytes+cursor) = CFSwapInt16HostToBig( (short)( rect.origin.x + rect.size.width));
    cursor += 2;
    
    // Bottom
    *(short*)(bytes+cursor) = CFSwapInt16HostToBig((short)( rect.origin.y + rect.size.height));
    cursor += 2;
    
    // IsKeyFrame
    bytes[cursor] = isKeyFrame;
    cursor++;
    
    NSData *wdata = [NSData dataWithBytes:bytes length:cursor];
    WTFPacket *wtfP = [[WTFPacket alloc] init];
    wtfP.devNo = _myDeviceInfos.deviceNo;
    
//    if( isKeyFrame ) {
//        DDLogInfo(@"mirror image:(%d, %d, %d, %d):Key(%d), size(%lu)",
//              (short)rect.origin.x,
//              (short)rect.origin.y,
//              (short)rect.size.width,
//              (short)rect.size.height,
//              isKeyFrame,
//              (unsigned long)[data length]);
//    }
    BOOL result = [wtfP resCommandWithData:sCommand data:wdata jpegData:data socket:_mirrorSocket];
    free(bytes);
}

#pragma mark - <GCDAsyncSocket Delegate>
- (void) socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    DDLogInfo(@"%s, %d", __FUNCTION__, _myDeviceInfos.deviceNo);
    
    int mirrorPort = _myDeviceInfos.mirrorPort;
    uint16 inport = newSocket.localPort;
    if( inport ==  mirrorPort ) {
        _mirrorSocket = newSocket;
        DDLogInfo(@"%s, %d -- MirrorSocket", __FUNCTION__, _myDeviceInfos.deviceNo);
        
        [newSocket readDataWithTimeout:READ_TIMEOUT tag:READ_TAG_MIRROR];
    } else {
        DDLogInfo(@"%s, %d -- ControlSocket", __FUNCTION__, _myDeviceInfos.deviceNo);
        _controlSocket = newSocket;
        
        [newSocket readDataWithTimeout:READ_TIMEOUT tag:READ_TAG_CONTROL];
    }
    
    NSString *host = [newSocket connectedHost];
    
    if( inport == mirrorPort )
    {
        DDLogInfo(@"Accepted Client mirror connection %@", host);
        
#ifdef DEBUG
        //[ioc startStream];
#endif
        
    }
}

- (void) socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    DDLogInfo(@"%s, %d", __FUNCTION__, _myDeviceInfos.deviceNo);
    
}

- (void) socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    DDLogInfo(@"%s, %d", __FUNCTION__, _myDeviceInfos.deviceNo);
    
    if (sock != _mirrorListenSocket && sock != _controlListenSocket /*&& sock != controlSocket*/)
    {
        if( sock == _mirrorSocket )
        {
            DDLogInfo(@"Mirror Socket is Disconnected !!");     // add by leehh
            
            if( _controlSocket.isConnected ) {
                [_controlSocket disconnectAfterReading];
            }
        }
        
        // add by leehh
        if( sock == _controlSocket ) {
            DDLogInfo(@"Control Socket is Disconnected !!");
            
            if( _mirrorSocket.isConnected ) {
                [_mirrorSocket disconnectAfterReading];
            }
        }
    }
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length
{
    DDLogInfo(@"%s, %d", __FUNCTION__, _myDeviceInfos.deviceNo);
    if (elapsed <= WRITE_TIMEOUT)
    {
        DDLogInfo(@"Network packet send delayed %.0f sec. wait more %.0f sec", WRITE_TIMEOUT, WRITE_TIMEOUT_EXTENSION);
        return WRITE_TIMEOUT_EXTENSION;
    }
    
    DDLogError(@"Network packet send delay over limit. Stop connection");
    [self sendCaptureErrorStatus:102];
    return 0.0;
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    //    DDLogInfo(@"%s", __FUNCTION__);
}

- (void) socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag  {
    DDLogInfo(@"%s, %d", __FUNCTION__, _myDeviceInfos.deviceNo);
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            
            WTFPacket *wtf = [WTFPacket alloc];
            if( [wtf getWTFData:data] == true)
            {
                [self processPacket:wtf];
            }
            [_controlSocket readDataWithTimeout:-1 tag:tag];
        }
    });
}



#pragma mark - <User Functions>


- (BOOL) startVPSSocketServer {
    _mirrorListenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    _controlListenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    NSError * error = nil;
    if( ![_mirrorListenSocket acceptOnPort:_myDeviceInfos.mirrorPort error:&error] ) {
        DDLogError(@"Error starting listen mirror port: %@", error);
        return NO;
    }
    
    if( ![_controlListenSocket acceptOnPort:_myDeviceInfos.controlPort error:&error] ) {
        DDLogError(@"Error starting listen control port: %@", error);
        return NO;
    }
    
    return YES;
}

- (void) sendCaptureErrorStatus:(short)subCode {
    unsigned char *bytes = malloc(2);
    
    // Data
    //#define ERR_SCREEN_CAPTURE_NOT_AVAILABLE    32401
    /*
     1 에러 코드    Short 2
     
     --에러 코드
     101 영상 캡쳐 불가   Mirroring App에서의 오류메세지 ‘errcheck : -1’
     
     */
    
    *(short*)(bytes+0) = CFSwapInt16HostToBig(subCode);
    
    NSData *wdata = [NSData dataWithBytes:bytes length:2];
    
    //DDLogInfo(@"ERR Screen capture not available(%d)", 101);
    DDLogError(@"ERR Screen capture not available(%d)", subCode);
    
    WTFPacket *wtfP = [[WTFPacket alloc] init];
    [wtfP resCommandWithData:ERR_SCREEN_CAPTURE_NOT_AVAILABLE data:wdata socket:_mirrorSocket];
    
    free(bytes);
}

- (BOOL) processPacket:(WTFPacket*)wtfP
{
    DDLogInfo(@"#######################");
    DDLogInfo(@"Command Code : %d, deviceNo : %d\n\n\n\n", wtfP.wtf.CommandCode, wtfP.wtf.DeviceNo);
    
    if( wtfP.wtf.DeviceNo != _myDeviceInfos.deviceNo ) {
        DDLogInfo(@"다른 Device 에 대한 명령이라 스킵함. -- WTFPacket DevNo : %d, DeviceNo : %d", (int)wtfP.wtf.DeviceNo, _myDeviceInfos.deviceNo);
        return false;
    }
    
    BOOL result = true;
    switch( wtfP.wtf.CommandCode)
    {
        case REQ_MIRROR_ONOFF:
            DDLogInfo(@"REQ_MIRROR_ONOFF");
            result = [self resMirrorOnOff:wtfP];
            break;
            
        case REQ_CHANGE_RESOLUTION:
            DDLogInfo(@"REQ_CHANGE_RESOLUTION");
            result = [self resChangeResolution:wtfP];
            break;
            
        case REQ_KEY_FRAME:
            DDLogInfo(@"REQ_KEY_FRAME");
            result = [self resKeyFrame:wtfP];
            break;
            
        case REQ_CHANGE_SCALE:
            DDLogInfo(@"REQ_CHANGE_SCALE");
            result = [self resChangeScale:wtfP];
            break;
            
        case REQ_MAX_RESOLUTION:
            DDLogInfo(@"REQ_MAX_RESOLUTION");
            result = [ self resMaxResolution:wtfP];
            break;
            
        case REQ_CHANGE_QUALITY:
            DDLogInfo(@"REQ_CHANGE_QUALITY -- Skip");
//            result = [self resChangeQuality:wtfP];
            break;
        case REQ_RESTART:
            DDLogInfo(@"REQ_RESTART");
//            dispatch_semaphore_wait(self.restartSem, DISPATCH_TIME_FOREVER);
//            [self processRestart];
//            dispatch_semaphore_signal(self.restartSem);
            break;
        default:
            DDLogInfo(@"Unknown Command : %d", wtfP.wtf.CommandCode);
//            [self logError:FORMAT(@"Unknown command received:%d", wtfP.wtf.CommandCode)];
//            assert(1);
            break;
    }
    
    return result;
}

- (BOOL) resMirrorOnOff:(WTFPacket*)wtfP
{
    DDLogInfo(@"%s deviceNo : %d", __FUNCTION__, wtfP.wtf.DeviceNo);
    
    //#define REQ_MIRROR_ONOFF    21002
    /*
     1 ON/OFF       Byte:1     ON:1 OFF:0
     */
    if( wtfP.wtf.DataSize < 1 )
        return false;
    char* bytes = (char*)wtfP.wtf.Data;
    char bStart = bytes[0];
    
    DDLogInfo(@"Mirror On/Off : (%d)", bStart);
    if( bStart )
    {
        [_myScreenCapture startScreenCapture];
    } else {
        [_myScreenCapture stopScreenCapture];
    }
    
    return true;
}

- (BOOL) resChangeResolution:(WTFPacket*)wtfP
{
    DDLogInfo(@"%@, %d", __FUNCTION__, wtfP.wtf.DeviceNo);
    /*
     1 Direction        Byte:1      Horizontal (Landscape): 0, Vertical (Portrait): 1
     2 Longer           Short:2     Width 와 Height 중 긴 쪽의 길이
     3 Shorter          Short:2     Width 와 Height 중 짧은 쪽의 길이
     */
    if( wtfP.wtf.DataSize < 5 )
        return false;
    
    unsigned char *bytes = wtfP.wtf.Data;
    int cursor = 0;
    _myScreenCapture.jpegFixedOrientation = *(char *)(bytes + cursor);
    cursor ++;

    _myScreenCapture.jpegFixedLonger = CFSwapInt16BigToHost(*(short *)(bytes + cursor));
    cursor += 2;
    _myScreenCapture.jpegFixedShorter = CFSwapInt16BigToHost(*(short *)(bytes + cursor));
    //cursor += 2;

    _myScreenCapture.jpegbFixed = 1;
    DDLogInfo(@"ChangeResolution:orient(%d) longer(%d), shorter(%d)", _myScreenCapture.jpegFixedOrientation, _myScreenCapture.jpegFixedLonger, _myScreenCapture.jpegFixedShorter);

    return true;
}

- (BOOL) resKeyFrame:(WTFPacket*)wtfP
{
    DDLogInfo(@"resKeyFrame");
    
    //[self logMessage:@"KeyFrame Requested"];
    
    return true;
}


- (BOOL) resChangeScale:(WTFPacket*)wtfP
{
    DDLogInfo(@"%s, %d", __FUNCTION__, wtfP.wtf.DeviceNo);
    // Data
    /*
     1 Ratio    Short:2     원래 해상도에서 축소 비율 (10~100)
     */
    unsigned char *bytes = wtfP.wtf.Data;
    ushort scale = CFSwapInt16BigToHost(*(short *)(bytes));
    
    if( scale < 10)
        scale = 10;
    if( scale > 100)
        scale = 100;
    
    _myScreenCapture.jpegScale = scale;
    DDLogInfo(@"Change Scale:%d", scale)
    return true;
}


- (BOOL) resChangeQuality:(WTFPacket*)wtfP
{
    DDLogInfo(@"%s, %d", __FUNCTION__, wtfP.wtf.DeviceNo);
    // Data
    /*
     1 Quality      Short:2             1~100 (default:70)
     2 Client ID    String(Variable)    n/c
     */
    unsigned char *bytes = wtfP.wtf.Data;
    ushort quality = CFSwapInt16BigToHost(*(short *)(bytes));
    
    if( quality < 1)
        quality = 1;
    if( quality > 100)
        quality = 100;
    
    [_myScreenCapture setQuality:quality];
    DDLogInfo(@"Change JPEG Qulity:%d", quality);
    
    return true;
}


- (BOOL) resMaxResolution:(WTFPacket*)wtfP
{
    DDLogInfo(@"%s, %d", __FUNCTION__, wtfP.wtf.DeviceNo);
    unsigned char *bytes = malloc(4);
    
    // Data
    //#define RES_MAX_RESOLUTION  21006
    /*
     1 Width    Short:2 세로 모드에서의 가로 길이 : at normal direction ( HOME at down )
     2 Height   Short:2 세로 모드에서의 세로 길이 : at normal direction ( HOME at down )
     */
    CGSize devSize = _myScreenCapture.deviceMaxSize;

    ushort width = (ushort)devSize.width;
    ushort height = (ushort)devSize.height;
    if( _myScreenCapture.devOrientation != 1 ) // portrait
    {
        height = (ushort)devSize.width;
        width = (ushort)devSize.height;
    }
    *(short*)(bytes+0) = CFSwapInt16HostToBig(width);
    *(short*)(bytes+2) = CFSwapInt16HostToBig(height);

    NSData *wdata = [NSData dataWithBytes:bytes length:4];

    DDLogInfo(@"MaxResolution(%d x %d)", width, height);
    BOOL result =  [wtfP resCommandWithData:RES_MAX_RESOLUTION data:wdata socket:_controlSocket];
    
    free(bytes);
    return result;

    return NO;
}



@end
