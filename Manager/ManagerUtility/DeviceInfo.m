//
//  DeviceInfo.m
//  Manager
//
//  Created by SR_LHH_MAC on 2016. 9. 9..
//  Copyright © 2016년 tomm. All rights reserved.
//

#import "DeviceInfo.h"
#import "Utility.h"

@interface DeviceInfos ()
@property (nonatomic, strong) NSDictionary  * dicResolutions;
@property (nonatomic, strong) NSDictionary  * dicRatio;
@property (nonatomic, assign) CGSize        resolution;
@property (nonatomic, strong) dispatch_queue_t      deviceInfoQueue;
@property (nonatomic, strong) dispatch_semaphore_t  deviceInfoSem;
@end


/// @brief  AppiumDeviceMapping.txt 파일에서 정보를읽어들여 구성함.
/// @brief  Standalone 버전일 경우 자체적으로 ideviceinfo 명령을 수행하여 정보를 구성함.
@implementation DeviceInfos
@synthesize customDelegate;


static DeviceInfos *myShareDeviceInfo = nil;

/// @brief 싱글턴 객체 생성
+ (DeviceInfos *)shareDeviceInfos {
    
    static dispatch_once_t onceToken ;
    dispatch_once(&onceToken, ^{
        if (!myShareDeviceInfo || myShareDeviceInfo == nil) {
            myShareDeviceInfo = [[DeviceInfos alloc] init] ;
            myShareDeviceInfo.arrayDeivce = [[NSMutableArray alloc] init];
        }
    });
    
    return myShareDeviceInfo ;
}


- (id) init {
    self = [super init];
    if( self ) {
        
        // iOS 9.x 버전일경우 Safari 의 하단 툴바부분에 공유하기 버튼을 누르면 동작하지 않는 문제가 있어 해당 부분의 터치를 걸러내기 위해 아래의 코드를 넣었다.
        _deviceInfoQueue = dispatch_queue_create("DeviceInfoQueue", NULL);
        _deviceInfoSem = dispatch_semaphore_create(1);
        
        NSValue * inch_4_size = [NSValue valueWithSize:CGSizeMake(320.0f, 568.0f)];
        NSValue * inch_4_7_size = [NSValue valueWithSize:CGSizeMake(375.0f, 667.0f)];
        NSValue * inch_5_5_size = [NSValue valueWithSize:CGSizeMake(414.0f, 736.0f)];
        
        NSNumber * ratio_1x = [NSNumber numberWithFloat:1.0f];
        NSNumber * ratio_2x = [NSNumber numberWithFloat:2.0f];
        NSNumber * ratio_3x = [NSNumber numberWithFloat:3.0f];
        
        _dicResolutions = [NSDictionary dictionaryWithObjectsAndKeys:inch_4_size, @"iPhone5,1", inch_4_size, @"iPhone5,2", inch_4_size, @"iPhone5,3", inch_4_size, @"iPhone5,4", inch_4_size, @"iPhone6,1", inch_4_size, @"iPhone6,2", inch_5_5_size, @"iPhone7,1", inch_4_7_size, @"iPhone7,2", inch_4_7_size, @"iPhone8,1", inch_5_5_size, @"iPhone8,2", inch_4_7_size, @"iPhone8,4", nil];
        
        _dicRatio = [NSDictionary dictionaryWithObjectsAndKeys:ratio_1x, @"iPhone5,1", ratio_1x, @"iPhone5,2", ratio_1x, @"iPhone5,3", inch_4_size, @"iPhone5,4", ratio_1x, @"iPhone6,1", ratio_1x, @"iPhone6,2", ratio_3x, @"iPhone7,1", ratio_2x, @"iPhone7,2", ratio_2x, @"iPhone8,1", ratio_3x, @"iPhone8,2", ratio_2x, @"iPhone8,4", nil];
        // ~
        
        _usbNumber = nil;
    }
    
    return self;
}

- (void) dealloc {
    _udid = nil;
    
    _usbNumber = nil;
    _deviceClass = nil;
    _productName = nil;
    _productType = nil;
    _productVersion = nil;
    
    _dicResolutions = nil;
    _dicRatio = nil;
    
    _deviceInfoSem = nil;
    _deviceInfoQueue = nil;
}

/// @brief  Standalone 버전일 경우 ideviceinfo 를 통해 정보를 획득하여 구성함.
- (void) getDeviceInfo {
    
    //    dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    
    __block __typeof__(self) blockSelf = self;
    
    dispatch_sync(blockSelf.deviceInfoQueue, ^{
    
        NSString * result = [Utility launchTask:@"/usr/local/bin/ideviceinfo" arguments:@[@"-u", _udid, @"-s"]];
        if( 0 == result.length )
            return ;
        
        NSArray * datas = [result componentsSeparatedByString:@"\n"];
        
        for( NSString * keyValue in datas ) {
            if( 0 == keyValue.length )
                continue;
            
            NSArray * keyAndValue = [keyValue componentsSeparatedByString:@": "];
            if( 2 == keyAndValue.count ) {
                const NSString * key = [keyAndValue objectAtIndex:0];
                NSString * value = [keyAndValue objectAtIndex:1];
                
//                DDLogInfo(@"Key : %@, value : %@", key, value);
                
                /*
                 DeviceClass: iPhone
                 DeviceName: HoonHee's iPhone 5s
                 ProductName: iPhone OS
                 ProductType: iPhone7,1
                 ProductVersion: 9.3.4
                 */
                
                if( [key isEqualToString:@"DeviceClass"] ) {
                    if( !blockSelf.deviceClass )
                        blockSelf.deviceClass = value;
                } else if( [key isEqualToString:@"DeviceName"] ) {
                    if( !blockSelf.deviceName )
                        blockSelf.deviceName = value;
                } else if( [key isEqualToString:@"ProductName"] ) {
                    if( !blockSelf.productName )
                        blockSelf.productName = value;
                } else if( [key isEqualToString:@"ProductType"] ) {
                    if( !blockSelf.productType )
                        blockSelf.productType = value;
                } else if( [key isEqualToString:@"ProductVersion"] ) {
                    if( !blockSelf.productVersion )
                        blockSelf.productVersion = value;
                }
            }
        }
        
//        dispatch_semaphore_signal(blockSelf.deviceInfoSem);
        dispatch_async(dispatch_get_main_queue(), ^{
            if( self.customDelegate && [self.customDelegate respondsToSelector:@selector(didCompletedGetDeviceInfos)] ) {
                [self.customDelegate didCompletedGetDeviceInfos];
            }
        });
    });
}

/// @brief 해상도 정보를 돌려준다.
- (CGSize) resolution {
    if( CGSizeEqualToSize(_resolution, CGSizeZero) ) {
        NSValue * resolution = [_dicResolutions objectForKey:_productType];
        if( !resolution )
            return CGSizeZero;
        
        _resolution = [resolution sizeValue];
    }
    
    return _resolution;
}

/// @brief  비율값을 돌려준다.
- (CGFloat) ratio {
    
    if( 0.0f == _ratio ) {
        NSNumber * ratio = [_dicRatio objectForKey:_productType];
        if( !ratio )
            return 0.0f;
        
        _ratio = [ratio floatValue];
    }
    
    return _ratio;
}

/// @brief  비율값을 설정한다.
- (void) ratio:(CGFloat)fRatio {
    _ratio = fRatio;
}

/// @brief  메모리 정리.
- (void) clearDeviceInfos {
    _deviceClass = nil;
    _productName = nil;
    _productType = nil;
    _productVersion = nil;
    
//    _usbNumber = nil;       // Detach 되었다가 Attach 되었을 때만 정보가 변경된다..
}


-(NSString *) buildWDAResult:(NSString* )udid
{
    @try
    {
        // Set up the process
        NSTask *t = [[NSTask alloc] init];
        [t setLaunchPath:@"/bin/ls"];
        
        NSString* udidPath = [udidPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString* path = [NSString stringWithFormat:@"%@PreBuild4WDA/%@/Build/Products/",[Utility managerDirectory],udid];
        [t setCurrentDirectoryPath:path];
        [t setArguments:[NSArray arrayWithObjects:@"-1", path, nil]];
        
        // Set the pipe to the standard output and error to get the results of the command
        NSPipe *p = [[NSPipe alloc] init];
        [t setStandardOutput:p];
        [t setStandardError:p];
        
        // Launch (forks) the process
        [t launch]; // raises an exception if something went wrong
        
        // Prepare to read
        NSFileHandle *readHandle = [p fileHandleForReading];
        NSData *inData = nil;
        NSMutableData *totalData = [[NSMutableData alloc] init];
        
        while ((inData = [readHandle availableData]) &&
               [inData length]) {
            [totalData appendData:inData];
        }
        
        // Polls the runloop until its finished
        [t waitUntilExit];
        
        NSString * output = [[NSString alloc] initWithData:totalData encoding: NSUTF8StringEncoding];
        
        NSArray* temp = [output componentsSeparatedByString:@"\n"];
        NSString* buildWDA = [NSString stringWithFormat:@"%@",[temp objectAtIndex:1]];
        return buildWDA;
    }
    @catch (NSException *e)
    {
        NSLog(@"Expection occurred %@", [e reason]);
        return @"0";
        
    }
}

@end
