//
//  SVHTTPRequest.h
//
//  Created by Sam Vermette on 20.09.11.
//  Copyright 2011 samvermette.com. All rights reserved.
//
//  https://github.com/samvermette/SVHTTPRequest
//

#import <Foundation/Foundation.h>
#import <AvailabilityMacros.h>

#import "SVHTTPClient.h"

enum {
	SVHTTPRequestMethodGET = 0,
    SVHTTPRequestMethodPOST,
    SVHTTPRequestMethodPUT,
    SVHTTPRequestMethodDELETE,
    SVHTTPRequestMethodHEAD
};
typedef NSUInteger SVHTTPRequestMethod;

@interface SVHTTPRequest : NSOperation

+ (SVHTTPRequest*)GET:(NSString*)address parameters:(NSDictionary*)parameters completion:(SVHTTPRequestCompletionHandler)block;
+ (SVHTTPRequest*)GET:(NSString*)address parameters:(NSDictionary*)parameters saveToPath:(NSString*)savePath progress:(void (^)(float progress))progressBlock completion:(SVHTTPRequestCompletionHandler)completionBlock;

+ (SVHTTPRequest*)POST:(NSString*)address parameters:(NSObject*)parameters completion:(SVHTTPRequestCompletionHandler)block;
+ (SVHTTPRequest*)POST:(NSString *)address parameters:(NSObject *)parameters progress:(void (^)(float))progressBlock completion:(SVHTTPRequestCompletionHandler)completionBlock;
+ (SVHTTPRequest*)PUT:(NSString*)address parameters:(NSObject*)parameters completion:(SVHTTPRequestCompletionHandler)block;

+ (SVHTTPRequest*)DELETE:(NSString*)address parameters:(NSDictionary*)parameters completion:(SVHTTPRequestCompletionHandler)block;
+ (SVHTTPRequest*)HEAD:(NSString*)address parameters:(NSDictionary*)parameters completion:(SVHTTPRequestCompletionHandler)block;

- (SVHTTPRequest*)initWithAddress:(NSString*)urlString 
                           method:(SVHTTPRequestMethod)method 
                       parameters:(NSObject*)parameters 
                       completion:(SVHTTPRequestCompletionHandler)completionBlock;

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field;

+ (void)setDefaultTimeoutInterval:(NSTimeInterval)interval;
+ (void)setDefaultUserAgent:(NSString*)userAgent;

@property (nonatomic, strong) NSString *userAgent;
@property (nonatomic, readwrite) BOOL sendParametersAsJSON;
@property (nonatomic, readwrite) NSURLRequestCachePolicy cachePolicy;
@property (nonatomic, readwrite) NSUInteger timeoutInterval;
@property (nonatomic, readwrite) NSDictionary *headers;
@property (nonatomic, readwrite) BOOL dismissNSURLAuthenticationMethodServerTrust;

@end


// the following methods are only to be accessed from SVHTTPRequest.m and SVHTTPClient.m

@protocol SVHTTPRequestPrivateMethods <NSObject>

@property (nonatomic, strong) NSString *requestPath;
@property (nonatomic, strong) SVHTTPClient *client;

- (SVHTTPRequest*)initWithAddress:(NSString*)urlString 
                           method:(SVHTTPRequestMethod)method 
                       parameters:(NSObject*)parameters 
                       saveToPath:(NSString*)savePath
                         progress:(void (^)(float))progressBlock
                       completion:(SVHTTPRequestCompletionHandler)completionBlock;

- (void)signRequestWithUsername:(NSString*)username password:(NSString*)password;

@end