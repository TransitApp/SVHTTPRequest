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
- (void)setSendParametersAsJSON:(BOOL)encode;
- (void)setCachePolicy:(NSURLRequestCachePolicy)cachePolicy;

- (void)GET:(NSString*)path parameters:(NSDictionary*)parameters completion:(void (^)(id response, NSError *error))completionBlock;
- (void)GET:(NSString*)path parameters:(NSDictionary*)parameters saveToPath:(NSString*)savePath progress:(void (^)(float progress))progressBlock completion:(void (^)(id response, NSError *error))completionBlock;

- (void)POST:(NSString*)path parameters:(NSDictionary*)parameters completion:(void (^)(id response, NSError *error))completionBlock;
- (void)PUT:(NSString*)path parameters:(NSDictionary*)parameters completion:(void (^)(id response, NSError *error))completionBlock;
- (void)DELETE:(NSString*)path parameters:(NSDictionary*)parameters completion:(void (^)(id response, NSError *error))completionBlock;

- (void)cancelRequestsWithPath:(NSString*)path;
- (void)cancelAllRequests;

@end
