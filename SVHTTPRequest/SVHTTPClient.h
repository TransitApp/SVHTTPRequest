//
//  SVHTTPClient.h
//
//  Created by Sam Vermette on 15.12.11.
//  Copyright 2011 samvermette.com. All rights reserved.
//
//  https://github.com/samvermette/SVHTTPRequest
//

#import <Foundation/Foundation.h>

@interface SVHTTPClient : NSObject

+ (SVHTTPClient*)sharedClient;

- (void)setBasePath:(NSString*)path;
- (void)setBasicAuthWithUsername:(NSString*)username password:(NSString*)password;

- (void)GET:(NSString*)path parameters:(NSDictionary*)parameters completion:(void (^)(id response, NSError *error))block;
- (void)GET:(NSString*)path parameters:(NSDictionary*)parameters saveToPath:(NSString*)savePath completion:(void (^)(id response, NSError *error))block;
- (void)POST:(NSString*)path parameters:(NSDictionary*)parameters completion:(void (^)(id response, NSError *error))block;
- (void)PUT:(NSString*)path parameters:(NSDictionary*)parameters completion:(void (^)(id response, NSError *error))block;
- (void)DELETE:(NSString*)path parameters:(NSDictionary*)parameters completion:(void (^)(id response, NSError *error))block;

- (void)cancelAllRequests;

@end
