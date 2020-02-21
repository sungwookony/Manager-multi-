//
//  HHURLConnection.m
//  Manager
//
//  Created by SR_LHH_MAC on 2016. 6. 9..
//  Copyright © 2016년 tomm. All rights reserved.
//

#import "HHURLConnection.h"

/// @brief NSURLConnection을 사용하여 비동기로 통신하는 클래스와 클래스 메소드 코드블록을 통해 결과를 비동기적으로 리턴한다.
/// @brief DC 로부터 Install 명령과 함께 들어온 URL 의 ipa 파일을 다운로드 하는데 사용함...
@implementation ASyncURLConnection
+ (void) asyncSendHttpURLConnection:(NSURLRequest *)httpRequest completion:(void (^)(NSURLResponse *response, NSData * data, NSError *error))block {
    
    //    dispatch_queue_t asyncURLConnectionQueue = dispatch_queue_create("asyncURLConnection", NULL);                 // HTTP Module 을 호출한 객체에 종속됨...
    dispatch_queue_t asyncURLConnectionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);     // Global 이기 때문에 Http Module 을 호출한 객체와 분리됨..
    dispatch_async(asyncURLConnectionQueue, ^(void) {                                                               // 따라서 Http Module 을 호출한 객체가 소멸되어도 별도로 동작을 하기 때문에 안전함..
        @autoreleasepool {
            
            if(floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_11){
                NSLog(@"########1 %f",floor(NSAppKitVersionNumber));
                NSError *error = nil;
                NSURLResponse *response = nil;
                NSData *rawData = [NSURLConnection sendSynchronousRequest:httpRequest returningResponse:&response error:&error];
                block(response, rawData, error);
            }else{
                NSLog(@"########2 %f",floor(NSAppKitVersionNumber));
                NSURLSessionDataTask *dataTask =
                [[NSURLSession sharedSession] dataTaskWithRequest:httpRequest
                completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // handle
                        block(response, data, error);
                    });
                }];
                [dataTask resume];
            }
        }
    });
}
@end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// @brief NSURLConnection 을 사용하여 동기로 통신하는 클래스와 클래스 메소드
@implementation SyncURLConnection
+ (void) syncSendHttpURLConnection:(NSURLRequest *)httpRequest completion:(void (^)(NSURLResponse *response, NSData * data, NSError *error))block {
    @autoreleasepool {
        NSError *error = nil;
        NSURLResponse *response = nil;
        NSData *rawData = [NSURLConnection sendSynchronousRequest:httpRequest returningResponse:&response error:&error];
        
        block(response, rawData, error);
    }
}
@end
