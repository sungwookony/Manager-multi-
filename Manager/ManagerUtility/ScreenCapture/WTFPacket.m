//
//  WTFPacket.m
//  onycap
//
//  Created by camel on 2015. 11. 17..
//  Copyright © 2015년 CoSTEP Inc. All rights reserved.
//

#import "WTFPacket.h"


@implementation WTFPacket
@synthesize wtf;
@synthesize devNo;

- (id)init
{
        if((self = [super init]))
        {
            wtf.Data = nil;
            wtf.DataSize = 0;
            wtf.DeviceNo = -1;
        }
        return self;
}

- (void)dealloc
{
    if( wtf.Data != nil && wtf.DataSize > 0)
    {
        free(wtf.Data);
    }
#if ! __has_feature(objc_arc)
    [super dealloc];
#endif
}

- (unsigned short) in_cksum:(unsigned short *)ptr nbytes:(int)nbytes
{
    
    long sum;
    
    u_short answer;  // return value
    sum = 0; // initialize sum
    
    while(nbytes > 1) { // 읽어올 값이 남아있으면
        sum +=  (*ptr++);
        nbytes -= 2;
    }
    
    if(nbytes == 1) { // 남은 읽어 올 값이 홀수이면
        sum += *(u_char *)ptr; // 그것도 더해줌
    }
    
    // 상위 16바이트와 하위 16바이트의 합
    sum = (sum >> 16) + (sum & 0xffff);
    
    //올라 온 값이 있으면 그것도 더해줌
    
    sum += (sum >> 16);
    
    answer = ~sum; // 전체 비트 반전
    
    return (answer); // 만들어진 값을 리턴
}

- (BOOL) getWTFData:(NSData*)data
{
    DDLogInfo(@"%s", __FUNCTION__);
    const uint8_t *     bufferBytes;
    int          bufferLength;
    int          cursor;
    
    assert(data != nil);
    
    bufferBytes = [data bytes];
    bufferLength= (int)[data length];
    
    cursor = 0;
    
    if( bufferLength < 11)
    {
        DDLogInfo(@"packet length is too short");
        return false;
    }
    
    // check start flag
    if( bufferBytes[cursor] != START_FLAG_BYTE)
    {
        DDLogInfo(@"packet start flag not found");
        return false;
    }
    cursor++;
    
    // check data size 
    wtf.DataSize = CFSwapInt32BigToHost(*(int*)(bufferBytes + cursor));
    cursor += 4;
    
    // check command code
    wtf.CommandCode = CFSwapInt16BigToHost(*(short*)(bufferBytes + cursor));
    cursor += 2;
    
    // check DeviceNo
    wtf.DeviceNo = bufferBytes[cursor];
    self.devNo = (int)wtf.DeviceNo;
    cursor ++;
    
    if( wtf.DataSize > 0 /*&& wtf.CommandCode != REQ_KEY_FRAME*/) {
        wtf.Data = (void*)malloc(wtf.DataSize);
        memcpy(wtf.Data, bufferBytes+cursor, wtf.DataSize);
        cursor += wtf.DataSize;
    } else {
        wtf.Data = nil;
    }
    
    // check checksum
//    wtf.Checksum = CFSwapInt16BigToHost(*(short*)(bufferBytes + cursor));
//    unsigned short csum = [self in_cksum:(unsigned short*)(bufferBytes+1) nbytes:cursor-1];
//    if( csum != wtf.Checksum)
//    {
//        DDLogInfo(@"Checksum is not valid");
//        free(wtf.Data);
//        wtf.Data = nil;
//        return false;
//    }
    cursor += 2;
    
    if( bufferBytes[cursor] != END_FLAG_BYTE)
    {
        DDLogInfo(@"Packet end flag not found");
        free(wtf.Data);
        wtf.Data = nil;
        return false;
    }

    return true;
}

- (BOOL)resCommandWithData:(short)command data:(NSData*)data socket:(GCDAsyncSocket*)socket{
    {
        int datalen = 0;
        if( data != nil)
            datalen = (int)[data length];
        
//        DDLogInfo(@"resCommand:%c with data %dbytes", command, datalen);
        unsigned char *bytes = malloc(sizeof(WTFData) + datalen);
        int cursor = 0;
        
        // start flag
        bytes[cursor] = START_FLAG_BYTE;
        cursor++;
        
        // data size
        *(int*)(bytes+cursor) = CFSwapInt32HostToBig(datalen);
        cursor += 4;
        
        // command code
        *(short*)(bytes+cursor) = CFSwapInt16HostToBig(command);
        cursor += 2;
        
        // Device No
        bytes[cursor] = self.devNo;
        cursor ++;
        
        memcpy((bytes+cursor), [data bytes], datalen);
        cursor += datalen;
        
        // check sum
        unsigned short csum = [self in_cksum:(unsigned short*)bytes+1 nbytes:cursor-1];
        *(short*)(bytes+cursor) = CFSwapInt16HostToBig(csum);
        cursor += 2;
        
        // end flag
        bytes[cursor] = END_FLAG_BYTE;
        cursor ++;
        
        NSData *wdata = [NSData dataWithBytes:bytes length:cursor];
        
        [socket writeData:wdata withTimeout:-1 tag:command];
        
        free(bytes);
        return true;
    }
    
}

- (BOOL)resCommandWithData:(short)command data:(NSData*)data jpegData:(NSData*)jdata socket:(GCDAsyncSocket*)socket
{
    {
        if( data == nil || jdata == nil)
            return FALSE;

        int datalen =  (int)[data length];
        int jdatalen = (int)[jdata length];
        
        if( datalen == 0 || jdatalen == 0 )
            return FALSE;
        
//        DDLogInfo(@"resCommand:%d with data %dbytes", command, datalen + jdatalen);
        unsigned char *bytes = malloc(sizeof(WTFData) + datalen + jdatalen);
        int cursor = 0;
        
        // start flag
        bytes[cursor] = START_FLAG_BYTE;
        cursor++;
        
        // data size
        *(int*)(bytes+cursor) = CFSwapInt32HostToBig(datalen + jdatalen);
        cursor += 4;
        
        // command code
        *(short*)(bytes+cursor) = CFSwapInt16HostToBig(command);
        cursor += 2;
        
        // Device No
        bytes[cursor] = self.devNo;
        cursor ++;
        
//        DDLogInfo(@"[#### Info ####] %s, deviceNo : %d, portNo : %d", __FUNCTION__, (int)self.devNo, (int)socket.localPort);
        
        if( datalen > 0)
            memcpy((bytes+cursor), [data bytes], datalen);
        cursor += datalen;
        
        if( jdatalen > 0)
            memcpy((bytes+cursor), [jdata bytes], jdatalen);
        cursor += jdatalen;
        
        // check sum
        unsigned short csum = [self in_cksum:(unsigned short*)bytes+1 nbytes:cursor-1];
        *(short*)(bytes+cursor) = CFSwapInt16HostToBig(csum);
        cursor += 2;
        
        // end flag
        bytes[cursor] = END_FLAG_BYTE;
        cursor ++;
        
        NSData *wdata = [NSData dataWithBytes:bytes length:cursor];
//        NSLog(@"%@", wdata.description);
        
        [socket writeData:wdata withTimeout:-1 tag:command];
        
        free(bytes);
        return true;
    }
    
}


@end
