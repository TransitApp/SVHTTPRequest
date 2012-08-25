//
//  SVHTTPClient.h
//
//  Created by Sam Vermette on 15.12.11.
//  Copyright 2011 samvermette.com. All rights reserved.
//
//  https://github.com/samvermette/SVHTTPRequest
//

#import <Foundation/Foundation.h>

typedef void (^SVHTTPRequestCompletionHandler)(id response, NSHTTPURLResponse *urlResponse, NSError *error);

@interface SVHTTPClient : NSObject

+ (SVHTTPClient*)sharedClient;
+ (SVHTTPClient*)sharedClientWithIdentifier:(NSString*)identifier;

- (void)setBasicAuthWithUsername:(NSString*)username password:(NSString*)password;

- (void)GET:(NSString*)path parameters:(NSDictionary*)parameters completion:(SVHTTPRequestCompletionHandler)completionBlock;
- (void)GET:(NSString*)path parameters:(NSDictionary*)parameters saveToPath:(NSString*)savePath progress:(void (^)(float progress))progressBlock completion:(SVHTTPRequestCompletionHandler)completionBlock;

- (void)POST:(NSString*)path parameters:(NSDictionary*)parameters completion:(SVHTTPRequestCompletionHandler)completionBlock;
- (void)PUT:(NSString*)path parameters:(NSDictionary*)parameters completion:(SVHTTPRequestCompletionHandler)completionBlock;
- (void)DELETE:(NSString*)path parameters:(NSDictionary*)parameters completion:(SVHTTPRequestCompletionHandler)completionBlock;

- (void)HEAD:(NSString*)path parameters:(NSDictionary*)parameters completion:(SVHTTPRequestCompletionHandler)completionBlock;

- (void)cancelRequestsWithPath:(NSString*)path;
- (void)cancelAllRequests;

// header values common to all requests, e.g. API keys
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field;
@property (nonatomic, strong) NSDictionary *baseParameters;

@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *password;
@property (nonatomic, strong) NSString *basePath;
@property (nonatomic, strong) NSString *userAgent;

@property (nonatomic, readwrite) BOOL sendParametersAsJSON;
@property (nonatomic, readwrite) NSURLRequestCachePolicy cachePolicy;
@property (nonatomic, readwrite) NSUInteger timeoutInterval;

@end
