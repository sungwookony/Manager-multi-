//
//  URLConnectDelegate.h
//  Manager
//
//  Created by onycom on 2018. 6. 20..
//  Copyright © 2018년 tomm. All rights reserved.
//

#import <Foundation/Foundation.h>

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;

@protocol URLConnectDelegate <NSObject>


@end
