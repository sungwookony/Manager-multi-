//
//  WTFPacket.h
//  onycap
//
//  Created by camel on 2015. 11. 17..
//  Copyright © 2015년 CoSTEP Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

#define START_FLAG_BYTE 0x7f
#define END_FLAG_BYTE   0xef

#define REQ_MIRROR_ONOFF    21002
/*
 1 ON/OFF       Byte:1     ON:1 OFF:0
 */
#define AUDIO_DATA          20003
/*
 1  Time Stamp      Long:8
 2  AAC Audio Data  Variable
 */
#define IMAGE_PORTRAIT      20004
#define IMAGE_LANDSCAPE     20005
/*
 1 Time Stamp   Long:8
 2 Left         Short:2
 3 Top          Short:2
 4 Right        Short:2
 5 Bottom       Short:2
 6 IsKeyFrame   Byte:1     1: 키프레임, 0: 키프레임 아님
 7 JPG Data     Variable
 
 3.2.3 KeyFrame 전송 조건
 아래의 각 항목에 해당할 시에 KeyFrame을 전송한다.
 A. 최초 VPS와 접속하여 영상을 전송할 때
 B. 폰의 회전으로 방향이 변경되었을 때
 C. 영상 미러링 해상도가 변경되었을 때 (3.5절, 3.6절)
 D. KeyFrame 전송 후 매 5초의 시간이 경과되었 때
 E. KeyFrame 전송요청이 있을 때 (3.4절)
 */
#define REQ_CHANGE_RESOLUTION   21001
/*
 1 Direction        Byte:1      Horizontal (Landscape): 0, Vertical (Portrait): 1
 2 Longer           Short:2     Width 와 Height 중 긴 쪽의 길이
 3 Shorter          Short:2     Width 와 Height 중 짧은 쪽의 길이
 */
#define REQ_KEY_FRAME       21003       // no data field
#define REQ_CHANGE_SCALE    21004
/*
 1 Ratio    Short:2     원래 해상도에서 축소 비율 (10~100)
 */
#define REQ_MAX_RESOLUTION  21005   // no data field (response RES_MAX_RESOLUTION)
#define RES_MAX_RESOLUTION  21006
/*
 1 Width    Short:2 세로 모드에서의 가로 길이 : at normal direction ( HOME at down )
 2 Height   Short:2 세로 모드에서의 세로 길이 : at normal direction ( HOME at down )
 */
#define REQ_CHANGE_QUALITY  30001

#define REQ_RESTART         31000
/*
 1 Quality      Short:2             1~100 (default:70)
 2 Client ID    String(Variable)    n/c
 */

#define ERR_SCREEN_CAPTURE_NOT_AVAILABLE    32401
/*
 1 에러 코드    Short 2
 
 --에러 코드
 101 영상 캡쳐 불가   Mirroring App에서의 오류메세지 ‘errcheck : -1’
 */

typedef struct _WTFData {
    unsigned char   StartFlag;
    int             DataSize;
    short           CommandCode;
    unsigned char   DeviceNo;
    void*           Data;
    unsigned short  Checksum;
    unsigned char   EndFlag;
} WTFData;

@interface WTFPacket : NSObject
{
    WTFData wtf;
    int devNo;
}

@property (readonly) WTFData  wtf;
@property (nonatomic, assign) int devNo;

- (BOOL) getWTFData:(NSData*)data;
- (BOOL)resCommandWithData:(short)command data:(NSData*)data socket:(GCDAsyncSocket*)socket;
- (BOOL)resCommandWithData:(short)command data:(NSData*)data jpegData:(NSData*)jdata socket:(GCDAsyncSocket*)socket;

@end
