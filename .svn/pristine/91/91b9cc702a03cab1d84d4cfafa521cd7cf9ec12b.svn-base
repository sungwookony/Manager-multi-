//
//  LogWriteToFile.m
//  ResourceMornitor
//
//  Created by SR_LHH_MAC on 2016. 5. 16..
//  Copyright © 2016년 onycom1. All rights reserved.
//


#import "LogWriteToFile.h"


#define LOG_RESOURCE            @"ResourceLog.txt"



@interface LogWriteToFile ()
@property (nonatomic, strong) NSFileHandle      * fileHandle;
@property (nonatomic, strong) NSDateFormatter   * dateFormatter;
@property (atomic, strong)    dispatch_queue_t  fileQueue;
@end

/// @brief 리소스 모니터에서 보내주는 리소스 정보를 파일로 남겨서 디버깅을 하기 위해 사용함..
@implementation LogWriteToFile
- (id) init {
    self = [super init];
    if( self ) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        
        _fileQueue = dispatch_queue_create("FileQueue", NULL);
    }
    
    return self;
}

- (void) dealloc {
    _fileHandle = nil;
    _dateFormatter = nil;
}

- (void) writeString:(NSString *)string withTag:(int)tag {
    dispatch_async(_fileQueue, ^{
        // 수신된 리소스 정보를 파일에 기록한다.        // 디버깅용..
        if( _fileHandle ) {
            NSLocale * currnetLocale = [NSLocale currentLocale];
            NSString * currentDate = [[NSDate date] descriptionWithLocale:currnetLocale];
            NSString * strOutput = [NSString stringWithFormat:@"==== %@ === device : %d ====\n%@\n\n\n\n", [currentDate description], tag, string];
            NSData * dtOutput = [strOutput dataUsingEncoding:NSUTF8StringEncoding];
            
            [_fileHandle truncateFileAtOffset:[_fileHandle seekToEndOfFile]];
            [_fileHandle writeData:dtOutput];
        }
    });
}

- (void) createLogFileByDeviceID:(int)deviceId {
    
    NSString * fileName = [NSString stringWithFormat:@"ResourceLog_%02d.txt", deviceId];
    NSString * resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString * thePath = [resourcePath stringByAppendingPathComponent:fileName];
    
    DDLogWarn(@"name Path : %@", thePath);
    NSFileManager * fileManager = [NSFileManager defaultManager] ;
    NSError *error = nil;
    
    if (![fileManager fileExistsAtPath:thePath]) {
        if( ![fileManager createFileAtPath:thePath contents:nil attributes:nil] ) {
            DDLogError(@"로그 파일 생성 실패 !!");
        }
    } else {
        if( ![@"" writeToFile:thePath atomically:YES encoding:NSUTF8StringEncoding error:&error] ) {
            DDLogError(@"로그 파일 초기화 실패 !!");
        }
    }
    
    _fileHandle = [NSFileHandle fileHandleForWritingAtPath:thePath];
}

- (void) closeFile {
    dispatch_async(_fileQueue, ^{
        [_fileHandle synchronizeFile];
        [_fileHandle closeFile];
        _fileHandle = nil;
    });
}

@end
