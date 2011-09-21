//
//  SVHTTPRequest.h
//
//  Created by Sam Vermette on 20.09.11.
//  Copyright 2011 samvermette.com. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kSVHTTPRequestTimeoutInterval 20

@interface SVHTTPRequest : NSObject

+ (SVHTTPRequest*)GET:(NSString*)address parameters:(NSDictionary*)parameters completion:(void (^)(NSObject *response))block;
+ (SVHTTPRequest*)POST:(NSString*)address parameters:(NSDictionary*)parameters completion:(void (^)(NSObject *response))block;

// Sign requests for basic authentication (http://en.wikipedia.org/wiki/Basic_access_authentication)
+ (SVHTTPRequest*)GET:(NSString*)address parameters:(NSDictionary*)parameters username:(NSString*)username password:(NSString*)password completion:(void (^)(NSObject *response))block;
+ (SVHTTPRequest*)POST:(NSString*)address parameters:(NSDictionary*)parameters username:(NSString*)username password:(NSString*)password completion:(void (^)(NSObject *response))block;

- (void)cancel;

@end
