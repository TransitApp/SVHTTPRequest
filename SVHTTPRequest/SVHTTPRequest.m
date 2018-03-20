//
//  SVHTTPRequest.m
//
//  Created by Sam Vermette on 20.09.11.
//  Copyright 2011 samvermette.com. All rights reserved.
//
//  https://github.com/samvermette/SVHTTPRequest
//

#import <UIKit/UIKit.h>
#import "SVHTTPRequest.h"
#import <UIKit/UIKit.h>

@interface NSData (Base64)
- (NSString*)base64EncodingWithLineLength:(unsigned int)lineLength;
- (NSString *)getImageType;
- (BOOL)isJPG;
- (BOOL)isPNG;
- (BOOL)isGIF;
@end

@interface NSString (OAURLEncodingAdditions)
- (NSString*)encodedURLParameterString;
@end

enum {
    SVHTTPRequestStateReady = 0,
    SVHTTPRequestStateExecuting,
    SVHTTPRequestStateFinished
};

typedef NSUInteger SVHTTPRequestState;

static NSInteger SVHTTPRequestTaskCount = 0;
static NSString *defaultUserAgent;
static NSURLRequestCachePolicy defaultCachePolicy;
static NSTimeInterval SVHTTPRequestTimeoutInterval = 20;

@interface SVHTTPRequest ()

@property (nonatomic, strong) NSDictionary *parameters;
@property (nonatomic, strong) NSMutableData *operationData;
@property (nonatomic, strong) NSFileHandle *operationFileHandle;
@property (nonatomic, strong) NSURLSession *operationSession;
@property (nonatomic, strong) NSURLSessionTask *operationSessionTask;
@property (nonatomic, strong) NSHTTPURLResponse *operationURLResponse;
@property (nonatomic, strong) NSString *operationSavePath;
@property (nonatomic, assign) CFRunLoopRef operationRunLoop;

#if TARGET_OS_IPHONE
@property (nonatomic, readwrite) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
#endif

@property (nonatomic, copy) SVHTTPRequestCompletionHandler operationCompletionBlock;
@property (nonatomic, copy) SVHTTPRequestProgressHandler operationProgressBlock;

@property (nonatomic, readwrite) SVHTTPRequestState state;
@property (nonatomic, strong) NSString *requestPath;
@property (nonatomic, strong) SVHTTPClient *client;

@property (nonatomic, strong) NSTimer *timeoutTimer; // see http://stackoverflow.com/questions/2736967

@property (nonatomic, readwrite) float expectedContentLength;
@property (nonatomic, readwrite) float receivedContentLength;

- (void)addParametersToRequest:(NSDictionary*)paramsDict;
- (void)finish;

- (void)callCompletionBlockWithResponse:(id)response error:(NSError *)error;

@end


@implementation SVHTTPRequest

@synthesize state = _state;

- (void)dealloc {
    [_operationSession invalidateAndCancel];
#if !OS_OBJECT_USE_OBJC
    dispatch_release(_saveDataDispatchGroup);
    dispatch_release(_saveDataDispatchQueue);
#endif
}

+ (void)setDefaultCachePolicy:(NSURLRequestCachePolicy)cachePolicy {
    defaultCachePolicy = cachePolicy;
}

+ (void)setDefaultTimeoutInterval:(NSTimeInterval)interval {
    SVHTTPRequestTimeoutInterval = interval;
}

+ (void)setDefaultUserAgent:(NSString *)userAgent {
    defaultUserAgent = userAgent;
}

- (NSUInteger)timeoutInterval {
    if(_timeoutInterval == 0)
        return SVHTTPRequestTimeoutInterval;
    return _timeoutInterval;
}

- (void)increaseSVHTTPRequestTaskCount {
    SVHTTPRequestTaskCount++;
    [self toggleNetworkActivityIndicator];
}

- (void)decreaseSVHTTPRequestTaskCount {
    SVHTTPRequestTaskCount = MAX(0, SVHTTPRequestTaskCount-1);
    [self toggleNetworkActivityIndicator];
}

- (void)toggleNetworkActivityIndicator {
#if TARGET_OS_IOS && !(defined SV_APP_EXTENSION)
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:(SVHTTPRequestTaskCount > 0)];
    });
#endif
}

#pragma mark - Convenience Methods

+ (SVHTTPRequest*)GET:(NSString *)address parameters:(NSDictionary *)parameters completion:(SVHTTPRequestCompletionHandler)block {
    SVHTTPRequest *requestObject = [[self alloc] initWithAddress:address method:SVHTTPRequestMethodGET parameters:parameters saveToPath:nil progress:nil completion:block];
    [requestObject start];
    
    return requestObject;
}

+ (SVHTTPRequest*)GET:(NSString *)address parameters:(NSDictionary *)parameters saveToPath:(NSString *)savePath progress:(SVHTTPRequestProgressHandler)progressBlock completion:(SVHTTPRequestCompletionHandler)completionBlock {
    SVHTTPRequest *requestObject = [[self alloc] initWithAddress:address method:SVHTTPRequestMethodGET parameters:parameters saveToPath:savePath progress:progressBlock completion:completionBlock];
    [requestObject start];
    
    return requestObject;
}

+ (SVHTTPRequest*)POST:(NSString *)address parameters:(NSObject *)parameters completion:(SVHTTPRequestCompletionHandler)block {
    SVHTTPRequest *requestObject = [[self alloc] initWithAddress:address method:SVHTTPRequestMethodPOST parameters:parameters saveToPath:nil progress:nil completion:block];
    [requestObject start];
    
    return requestObject;
}

+ (SVHTTPRequest*)POST:(NSString *)address parameters:(NSObject *)parameters progress:(SVHTTPRequestProgressHandler)progressBlock completion:(SVHTTPRequestCompletionHandler)completionBlock {
    SVHTTPRequest *requestObject = [[self alloc] initWithAddress:address method:SVHTTPRequestMethodPOST parameters:parameters saveToPath:nil progress:progressBlock completion:completionBlock];
    [requestObject start];
    
    return requestObject;
}

+ (SVHTTPRequest*)PUT:(NSString *)address parameters:(NSObject *)parameters completion:(SVHTTPRequestCompletionHandler)block {
    SVHTTPRequest *requestObject = [[self alloc] initWithAddress:address method:SVHTTPRequestMethodPUT parameters:parameters saveToPath:nil progress:nil completion:block];
    [requestObject start];
    
    return requestObject;
}

+ (SVHTTPRequest*)PUT:(NSString *)address parameters:(NSObject *)parameters progress:(SVHTTPRequestProgressHandler)progressBlock completion:(SVHTTPRequestCompletionHandler)completionBlock {
    SVHTTPRequest *requestObject = [[self alloc] initWithAddress:address method:SVHTTPRequestMethodPUT parameters:parameters saveToPath:nil progress:progressBlock completion:completionBlock];
    [requestObject start];
    
    return requestObject;
}

+ (SVHTTPRequest*)DELETE:(NSString *)address parameters:(NSDictionary *)parameters completion:(SVHTTPRequestCompletionHandler)block {
    SVHTTPRequest *requestObject = [[self alloc] initWithAddress:address method:SVHTTPRequestMethodDELETE parameters:parameters saveToPath:nil progress:nil completion:block];
    [requestObject start];
    
    return requestObject;
}

+ (SVHTTPRequest*)HEAD:(NSString *)address parameters:(NSDictionary *)parameters completion:(SVHTTPRequestCompletionHandler)block {
    SVHTTPRequest *requestObject = [[self alloc] initWithAddress:address method:SVHTTPRequestMethodHEAD parameters:parameters saveToPath:nil progress:nil completion:block];
    [requestObject start];
    
    return requestObject;
}

#pragma mark -

- (SVHTTPRequest*)initWithAddress:(NSString *)urlString method:(SVHTTPRequestMethod)method parameters:(NSDictionary *)parameters completion:(SVHTTPRequestCompletionHandler)completionBlock {
    return [(id<SVHTTPRequestPrivateMethods>)self initWithAddress:urlString method:method parameters:parameters saveToPath:nil progress:NULL completion:completionBlock];
}

- (SVHTTPRequest*)initWithAddress:(NSString*)urlString method:(SVHTTPRequestMethod)method parameters:(NSDictionary*)parameters saveToPath:(NSString*)savePath progress:(SVHTTPRequestProgressHandler)progressBlock completion:(SVHTTPRequestCompletionHandler)completionBlock  {
    self = [super init];
    self.operationCompletionBlock = completionBlock;
    self.operationProgressBlock = progressBlock;
    self.operationSavePath = savePath;
    
    NSURL *url = [[NSURL alloc] initWithString:urlString];
    self.operationRequest = [[NSMutableURLRequest alloc] initWithURL:url];
    
    NSString *path = url.path;
    if ([path hasPrefix:@"/"]) {
        path = [path substringFromIndex:1];
    }
    [self setRequestPath:path];
    
    // pipeline all but POST and downloads
    if(method != SVHTTPRequestMethodPOST && !savePath)
        self.operationRequest.HTTPShouldUsePipelining = YES;
    
    if(method == SVHTTPRequestMethodGET)
        [self.operationRequest setHTTPMethod:@"GET"];
    else if(method == SVHTTPRequestMethodPOST)
        [self.operationRequest setHTTPMethod:@"POST"];
    else if(method == SVHTTPRequestMethodPUT)
        [self.operationRequest setHTTPMethod:@"PUT"];
    else if(method == SVHTTPRequestMethodDELETE)
        [self.operationRequest setHTTPMethod:@"DELETE"];
    else if(method == SVHTTPRequestMethodHEAD)
        [self.operationRequest setHTTPMethod:@"HEAD"];
    
    self.state = SVHTTPRequestStateReady;
    
    self.parameters = parameters;
    
    return self;
}

- (void)preprocessParameters {
    if(self.parameters)
        [self addParametersToRequest:self.parameters];
    self.parameters = nil;
}

- (void)addParametersToRequest:(NSObject*)parameters {
    
    NSString *method = self.operationRequest.HTTPMethod;
    
    if([method isEqualToString:@"POST"] || [method isEqualToString:@"PUT"]) {
        if(self.sendParametersAsJSON) {
            if([parameters isKindOfClass:[NSArray class]] || [parameters isKindOfClass:[NSDictionary class]]) {
                [self.operationRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
                NSError *jsonError;
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:&jsonError];
                [self.operationRequest setHTTPBody:jsonData];
            }
            else
                [NSException raise:NSInvalidArgumentException format:@"POST and PUT parameters must be provided as NSDictionary or NSArray when sendParametersAsJSON is set to YES."];
        }
        else if([parameters isKindOfClass:[NSDictionary class]]) {
            __block BOOL hasData = NO;
            NSDictionary *paramsDict = (NSDictionary*)parameters;
            
            [paramsDict.allValues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if([obj isKindOfClass:[NSData class]] || [obj isKindOfClass:[NSURL class]])
                    hasData = YES;
                else if(![obj isKindOfClass:[NSString class]] && ![obj isKindOfClass:[NSNumber class]])
                    [NSException raise:NSInvalidArgumentException format:@"%@ requests only accept NSString and NSNumber parameters.", self.operationRequest.HTTPMethod];
            }];
            
            if(!hasData) {
                const char *stringData = [[self parameterStringForDictionary:paramsDict] UTF8String];
                NSMutableData *postData = [NSMutableData dataWithBytes:stringData length:strlen(stringData)];
                [self.operationRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"]; //added by uzys
                [self.operationRequest setHTTPBody:postData];
            }
            else {
                NSString *boundary = @"SVHTTPRequestBoundary";
                NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
                [self.operationRequest setValue:contentType forHTTPHeaderField: @"Content-Type"];
                
                __block NSMutableData *postData = [NSMutableData data];
                __block int dataIdx = 0;
                // add string parameters
                [paramsDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    if(![obj isKindOfClass:[NSData class]] && ![obj isKindOfClass:[NSURL class]]) {
                        [postData appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
                        [postData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
                        [postData appendData:[[NSString stringWithFormat:@"%@", obj] dataUsingEncoding:NSUTF8StringEncoding]];
                        [postData appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
                    } else {
                        NSString *fileName = nil;
                        NSData *data = nil;
                        NSString *imageExtension = nil;
                        if ([obj isKindOfClass:[NSURL class]]) {
                            fileName = [obj lastPathComponent];
                            data = [NSData dataWithContentsOfURL:obj];
                        }
                        else {
                            imageExtension = [obj getImageType];
                            fileName = [NSString stringWithFormat:@"userfile%d%x", dataIdx, (int)[[NSDate date] timeIntervalSince1970]];
                            if (imageExtension != nil)
                                fileName = [fileName stringByAppendingPathExtension:imageExtension];
                            data = obj;
                        }
                        
                        [postData appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
                        [postData appendData:[[NSString stringWithFormat:@"Content-Disposition: attachment; name=\"%@\"; filename=\"%@\"\r\n", key, fileName] dataUsingEncoding:NSUTF8StringEncoding]];
                        
                        if(imageExtension != nil) {
                            [postData appendData:[[NSString stringWithFormat:@"Content-Type: image/%@\r\n\r\n",imageExtension] dataUsingEncoding:NSUTF8StringEncoding]];
                        }
                        else {
                            [postData appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
                        }
                        
                        [postData appendData:data];
                        [postData appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
                        dataIdx++;
                    }
                }];
                
                [postData appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
                [self.operationRequest setHTTPBody:postData];
            }
        }
        else
            [NSException raise:NSInvalidArgumentException format:@"POST and PUT parameters must be provided as NSDictionary when sendParametersAsJSON is set to NO."];
    }
    else if([parameters isKindOfClass:[NSDictionary class]]) {
        NSDictionary *paramsDict = (NSDictionary*)parameters;
        NSString *baseAddress = self.operationRequest.URL.absoluteString;
        if(paramsDict.count > 0)
            baseAddress = [baseAddress stringByAppendingFormat:@"?%@", [self parameterStringForDictionary:paramsDict]];
        [self.operationRequest setURL:[NSURL URLWithString:baseAddress]];
    }
    else
        [NSException raise:NSInvalidArgumentException format:@"GET and DELETE parameters must be provided as NSDictionary."];
}

- (NSString*)parameterStringForDictionary:(NSDictionary*)parameters {
    NSMutableArray *stringParameters = [NSMutableArray arrayWithCapacity:parameters.count];
    
    [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if([obj isKindOfClass:[NSString class]]) {
            [stringParameters addObject:[NSString stringWithFormat:@"%@=%@", key, [obj encodedURLParameterString]]];
        }
        else if([obj isKindOfClass:[NSNumber class]]) {
            [stringParameters addObject:[NSString stringWithFormat:@"%@=%@", key, obj]];
        }
        else
            [NSException raise:NSInvalidArgumentException format:@"%@ requests only accept NSString, NSNumber and NSData parameters.", self.operationRequest.HTTPMethod];
    }];
    
    return [stringParameters componentsJoinedByString:@"&"];
}


- (void)signRequestWithUsername:(NSString*)username password:(NSString*)password  {
    NSString *authStr = [NSString stringWithFormat:@"%@:%@", username, password];
    NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64EncodingWithLineLength:140]];
    [self.operationRequest setValue:authValue forHTTPHeaderField:@"Authorization"];
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    [self.operationRequest setValue:value forHTTPHeaderField:field];
}

- (void)setTimeoutTimer:(NSTimer *)newTimer {
    
    if(_timeoutTimer) {
        [_timeoutTimer invalidate];
        _timeoutTimer = nil;
    }
    
    if(newTimer)
        _timeoutTimer = newTimer;
}

#pragma mark - NSOperation methods

- (void)start {
    
    if(self.isCancelled) {
        [self finish];
        return;
    }
    
    [self preprocessParameters];

#if TARGET_OS_IPHONE && !(defined SV_APP_EXTENSION)
    // all requests should complete and run completion block unless we explicitely cancel them.
    self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if(self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
            self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }
    }];
#endif
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self increaseSVHTTPRequestTaskCount];
    });
    
    if(self.userAgent)
        [self.operationRequest setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
    else if(defaultUserAgent)
        [self.operationRequest setValue:defaultUserAgent forHTTPHeaderField:@"User-Agent"];
    
    [self.operationRequest setValue:[[NSLocale currentLocale] localeIdentifier]  forHTTPHeaderField:@"Accept-Language"];
    
    [self willChangeValueForKey:@"isExecuting"];
    self.state = SVHTTPRequestStateExecuting;
    [self didChangeValueForKey:@"isExecuting"];
    
    if(self.operationSavePath) {
        [[NSFileManager defaultManager] createFileAtPath:self.operationSavePath contents:nil attributes:nil];
        self.operationFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.operationSavePath];
    } else {
        self.operationData = [[NSMutableData alloc] init];
        self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:self.timeoutInterval target:self selector:@selector(requestTimeout) userInfo:nil repeats:NO];
        [self.operationRequest setTimeoutInterval:self.timeoutInterval];
    }
    
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.operationSession = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
    
    if(defaultCachePolicy)
        [self.operationRequest setCachePolicy:defaultCachePolicy];
    else
        [self.operationRequest setCachePolicy:self.cachePolicy];
    
    if(self.operationSavePath)
        self.operationSessionTask = [self.operationSession downloadTaskWithRequest:self.operationRequest];
    else
        self.operationSessionTask = [self.operationSession dataTaskWithRequest:self.operationRequest];
    
    [self.operationSessionTask resume];
    
#if !(defined SVHTTPREQUEST_DISABLE_LOGGING)
    NSLog(@"[%@] %@", self.operationRequest.HTTPMethod, self.operationRequest.URL.absoluteString);
#endif
}

// private method; not part of NSOperation
- (void)finish {
    [self.operationSession invalidateAndCancel];
    self.operationSession = nil;
    
    [self decreaseSVHTTPRequestTaskCount];
    
#if TARGET_OS_IPHONE && !(defined SV_APP_EXTENSION)
    if(self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
        self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }
#endif
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    self.state = SVHTTPRequestStateFinished;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (void)cancel {
    if(![self isExecuting])
        return;
    
    [super cancel];
    self.timeoutTimer = nil;
    [self finish];
}

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isFinished {
    return self.state == SVHTTPRequestStateFinished;
}

- (BOOL)isExecuting {
    return self.state == SVHTTPRequestStateExecuting;
}

- (SVHTTPRequestState)state {
    @synchronized(self) {
        return _state;
    }
}

- (void)setState:(SVHTTPRequestState)newState {
    @synchronized(self) {
        [self willChangeValueForKey:@"state"];
        _state = newState;
        [self didChangeValueForKey:@"state"];
    }
}

#pragma mark -
#pragma mark Delegate Methods

- (void)requestTimeout {
    
    NSURL *failingURL = self.operationRequest.URL;
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"The operation timed out.", NSLocalizedDescriptionKey,
                              failingURL, NSURLErrorFailingURLErrorKey,
                              failingURL.absoluteString, NSURLErrorFailingURLStringErrorKey, nil];
    
    NSError *timeoutError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:userInfo];
    [self URLSession:self.operationSession task:self.operationSessionTask didCompleteWithError:timeoutError];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    self.expectedContentLength = response.expectedContentLength;
    self.receivedContentLength = 0;
    self.operationURLResponse = (NSHTTPURLResponse*)response;
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.operationData appendData:data];
    
    if(self.operationProgressBlock) {
        //If its -1 that means the header does not have the content size value
        if(self.expectedContentLength != -1) {
            self.receivedContentLength += data.length;
            self.operationProgressBlock(self.receivedContentLength, self.expectedContentLength);
        } else {
            //we dont know the full size so always return -1 as the progress
            self.operationProgressBlock(-1, -1);
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    if(self.operationProgressBlock && [self.operationRequest.HTTPMethod isEqualToString:@"POST"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.operationProgressBlock(totalBytesSent, totalBytesExpectedToSend);
        });
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    if(self.operationProgressBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.operationProgressBlock(totalBytesWritten, totalBytesExpectedToWrite);
        });
    }
}


- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSData *fileData = [NSData dataWithContentsOfURL:location];
    [self.operationFileHandle writeData:fileData];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if(error) {
        [self callCompletionBlockWithResponse:nil error:error];
    } else {
        id response = [NSData dataWithData:self.operationData];
        NSError *err = nil;
        
        if ([[self.operationURLResponse MIMEType] isEqualToString:@"application/json"] || [[self.operationURLResponse MIMEType] isEqualToString:@"application/javascript"]) {
            if(self.operationData && self.operationData.length > 0) {
                //We parse the string before, because we need it to be UTF-8 in NSJSONSerialization
                NSString *utf8String = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
                if (utf8String == nil) {
                    utf8String = [[NSString alloc] initWithData:response encoding:NSASCIIStringEncoding];
                }
                
                NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:[utf8String dataUsingEncoding:NSUTF8StringEncoding]
                                                                           options:NSJSONReadingAllowFragments error:&err];
                
                if(jsonObject)
                    response = jsonObject;
            }
        }
        
        [self callCompletionBlockWithResponse:response error:err];
    }
}

- (void)callCompletionBlockWithResponse:(id)response error:(NSError *)error {
    self.timeoutTimer = nil;
    
    if(self.operationRunLoop)
        CFRunLoopStop(self.operationRunLoop);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSError *serverError = error;
        
        if(!serverError) {
            if(self.operationURLResponse.statusCode == 500) {
                serverError = [NSError errorWithDomain:NSURLErrorDomain
                                                  code:NSURLErrorBadServerResponse
                                              userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                        @"Bad Server Response.", NSLocalizedDescriptionKey,
                                                        self.operationRequest.URL, NSURLErrorFailingURLErrorKey,
                                                        self.operationRequest.URL.absoluteString, NSURLErrorFailingURLStringErrorKey, nil]];
            }
            else if(self.operationURLResponse.statusCode > 299) {
                serverError = [NSError errorWithDomain:NSURLErrorDomain
                                                  code:self.operationURLResponse.statusCode
                                              userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                        self.operationRequest.URL, NSURLErrorFailingURLErrorKey,
                                                        self.operationRequest.URL.absoluteString, NSURLErrorFailingURLStringErrorKey, nil]];
                
            }
        }
        
        if(self.operationCompletionBlock && !self.isCancelled)
            self.operationCompletionBlock(response, self.operationURLResponse, serverError);
        
        [self finish];
    });
}

@end


// Created by Jon Crosby on 10/19/07.
// Copyright 2007 Kaboomerang LLC. All rights reserved.

@implementation NSString (SVHTTPRequest)

- (NSString*)encodedURLParameterString {
    NSString *result = [self stringByAddingPercentEncodingWithAllowedCharacters: [NSCharacterSet characterSetWithCharactersInString:@":/=,!$&'()*+;[]@#?^%\"`<>{}\\|~ "]];
     return result;
}

@end

// Created by khammond on Mon Oct 29 2001.
// Formatted by Timothy Hatcher on Sun Jul 4 2004.
// Copyright (c) 2001 Kyle Hammond. All rights reserved.
// Original development by Dave Winer.

static char encodingTable[64] = {
    'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
    'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
    'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
    'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/' };

@implementation NSData (SVHTTPRequest)

- (NSString *)base64EncodingWithLineLength:(unsigned int) lineLength {
    const unsigned char	*bytes = [self bytes];
    NSMutableString *result = [NSMutableString stringWithCapacity:[self length]];
    unsigned long ixtext = 0;
    unsigned long lentext = [self length];
    long ctremaining = 0;
    unsigned char inbuf[3], outbuf[4];
    short i = 0;
    unsigned int charsonline = 0;
    short ctcopy = 0;
    unsigned long ix = 0;
    
    while( YES ) {
        ctremaining = lentext - ixtext;
        if( ctremaining <= 0 ) break;
        
        for( i = 0; i < 3; i++ ) {
            ix = ixtext + i;
            if( ix < lentext ) inbuf[i] = bytes[ix];
            else inbuf [i] = 0;
        }
        
        outbuf [0] = (inbuf [0] & 0xFC) >> 2;
        outbuf [1] = ((inbuf [0] & 0x03) << 4) | ((inbuf [1] & 0xF0) >> 4);
        outbuf [2] = ((inbuf [1] & 0x0F) << 2) | ((inbuf [2] & 0xC0) >> 6);
        outbuf [3] = inbuf [2] & 0x3F;
        ctcopy = 4;
        
        switch( ctremaining ) {
            case 1:
                ctcopy = 2;
                break;
            case 2:
                ctcopy = 3;
                break;
        }
        
        for( i = 0; i < ctcopy; i++ )
            [result appendFormat:@"%c", encodingTable[outbuf[i]]];
        
        for( i = ctcopy; i < 4; i++ )
            [result appendFormat:@"%c",'='];
        
        ixtext += 3;
        charsonline += 4;
    }
    
    return result;
}

- (BOOL)isJPG {
    if (self.length > 4) {
        unsigned char buffer[4];
        [self getBytes:&buffer length:4];
        
        return buffer[0]==0xff &&
        buffer[1]==0xd8 &&
        buffer[2]==0xff &&
        buffer[3]==0xe0;
    }
    
    return NO;
}

- (BOOL)isPNG {
    if (self.length > 4) {
        unsigned char buffer[4];
        [self getBytes:&buffer length:4];
        
        return buffer[0]==0x89 &&
        buffer[1]==0x50 &&
        buffer[2]==0x4e &&
        buffer[3]==0x47;
    }
    
    return NO;
}

- (BOOL)isGIF {
    if(self.length >3) {
        unsigned char buffer[4];
        [self getBytes:&buffer length:4];
        
        return buffer[0]==0x47 &&
        buffer[1]==0x49 &&
        buffer[2]==0x46; //Signature ASCII 'G','I','F'
    }
    return  NO;
}

- (NSString *)getImageType {
    NSString *ret;
    if([self isJPG]) {
        ret=@"jpg";
    }
    else if([self isGIF]) {
        ret=@"gif";
    }
    else if([self isPNG]) {
        ret=@"png";
    }
    else {
        ret=nil;
    }
    return ret;
}

@end


