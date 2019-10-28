//
//  HHURLConnection.h
//  Manager
//
//  Created by SR_LHH_MAC on 2016. 6. 9..
//  Copyright © 2016년 tomm. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ASyncURLConnection : NSObject {
    
}

+ (void) asyncSendHttpURLConnection:(NSURLRequest *)httpRequest completion:(void (^)(NSURLResponse *response, NSData * data, NSError *error))block;

@end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface SyncURLConnection : NSObject {
    
}

+ (void) syncSendHttpURLConnection:(NSURLRequest *)httpRequest completion:(void (^)(NSURLResponse *response, NSData * data, NSError *error))block;

@end
