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
    SVHTTPRequestMethodDELETE
};

typedef NSUInteger SVHTTPRequestMethod;


@interface SVHTTPRequest : NSOperation

+ (SVHTTPRequest*)GET:(NSString*)address parameters:(NSDictionary*)parameters completion:(void (^)(id response, NSError *error))block;
+ (SVHTTPRequest*)GET:(NSString*)address parameters:(NSDictionary*)parameters saveToPath:(NSString*)savePath completion:(void (^)(id response, NSError *error))block DEPRECATED_ATTRIBUTE;
+ (SVHTTPRequest*)GET:(NSString*)address parameters:(NSDictionary*)parameters saveToPath:(NSString*)savePath progress:(void (^)(float progress))progressBlock completion:(void (^)(id response, NSError *error))completionBlock;

+ (SVHTTPRequest*)POST:(NSString*)address parameters:(NSDictionary*)parameters completion:(void (^)(id response, NSError *error))block;
+ (SVHTTPRequest*)PUT:(NSString*)address parameters:(NSDictionary*)parameters completion:(void (^)(id response, NSError *error))block;
+ (SVHTTPRequest*)DELETE:(NSString*)address parameters:(NSDictionary*)parameters completion:(void (^)(id response, NSError *error))block;

- (SVHTTPRequest*)initRequestWithAddress:(NSString*)urlString 
                                  method:(SVHTTPRequestMethod)method 
                              parameters:(NSDictionary*)parameters 
                              completion:(void (^)(id, NSError*))completionBlock;

@property (nonatomic, readwrite) BOOL sendParametersAsJSON;
@property (nonatomic, readwrite) NSURLRequestCachePolicy cachePolicy;

@end


// the following methods are only to be accessed from SVHTTPRequest.m and SVHTTPClient.m

@protocol SVHTTPRequestPrivateMethods <NSObject>

@property (nonatomic, retain) NSString *requestPath;

- (SVHTTPRequest*)initRequestWithAddress:(NSString*)urlString 
                                  method:(SVHTTPRequestMethod)method 
                              parameters:(NSDictionary*)parameters 
                              saveToPath:(NSString*)savePath
                                progress:(void (^)(float))progressBlock
                              completion:(void (^)(id, NSError*))completionBlock;

- (void)signRequestWithUsername:(NSString*)username password:(NSString*)password;

@end