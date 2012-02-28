//
//  SVHTTPRequest.m
//
//  Created by Sam Vermette on 20.09.11.
//  Copyright 2011 samvermette.com. All rights reserved.
//
//  https://github.com/samvermette/SVHTTPRequest
//

#import "SVHTTPRequest.h"
#import "JSONKit.h"

#define kSVHTTPRequestTimeoutInterval 20

@interface NSData (Base64)
- (NSString*)base64EncodingWithLineLength:(unsigned int)lineLength;
@end

@interface NSString (OAURLEncodingAdditions)
- (NSString*)encodedURLParameterString;
@end

@interface UIDevice (SVHTTPRequest)
- (NSString*)deviceType;
@end

enum {
    SVHTTPRequestStateReady = 0,
    SVHTTPRequestStateExecuting,
    SVHTTPRequestStateFinished
};

typedef NSUInteger SVHTTPRequestState;

@interface SVHTTPRequest ()

@property (nonatomic, assign) NSMutableURLRequest *operationRequest;
@property (nonatomic, assign) NSMutableData *operationData;
@property (nonatomic, retain) NSFileHandle *operationFileHandle;
@property (nonatomic, assign) NSURLConnection *operationConnection;

@property (nonatomic, retain) NSString *operationSavePath;
@property (nonatomic, copy) void (^operationCompletionBlock)(id response, NSError *error);
@property (nonatomic, copy) void (^operationProgressBlock)(float progress);

@property (nonatomic, readwrite) SVHTTPRequestState state;
@property (nonatomic, retain) NSString *requestPath;

@property (nonatomic, retain) NSTimer *timeoutTimer; // see http://stackoverflow.com/questions/2736967

@property (nonatomic, readwrite) float expectedContentLength;
@property (nonatomic, readwrite) float receivedContentLength;

- (void)addParametersToRequest:(NSDictionary*)paramsDict;
- (void)finish;

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
- (void)callCompletionBlockWithResponse:(id)response error:(NSError*)error;

@end


@implementation SVHTTPRequest

@synthesize sendParametersAsJSON, cachePolicy;

// private properties
@synthesize operationRequest, operationData, operationConnection, operationFileHandle, state;
@synthesize operationSavePath, operationCompletionBlock, operationProgressBlock, timeoutTimer;
@synthesize expectedContentLength, receivedContentLength;
@synthesize requestPath;
	
- (void)dealloc {
    [operationData release];
    [operationRequest release];
    [operationConnection cancel];
    [operationConnection release];
    
    self.operationCompletionBlock = nil;
    self.operationProgressBlock = nil;
    self.operationFileHandle = nil;
    self.operationSavePath = nil;
    self.timeoutTimer = nil;
    self.requestPath = nil;
    
	[super dealloc];
}

#pragma mark - Convenience Methods

+ (SVHTTPRequest*)GET:(NSString *)address parameters:(NSDictionary *)parameters completion:(void (^)(id, NSError*))block {
    SVHTTPRequest *requestObject = [[self alloc] initRequestWithAddress:address method:SVHTTPRequestMethodGET parameters:parameters saveToPath:nil progress:nil completion:block];
    [requestObject start];
    
    return [requestObject autorelease];
}

+ (SVHTTPRequest*)GET:(NSString *)address parameters:(NSDictionary *)parameters saveToPath:(NSString *)savePath completion:(void (^)(id, NSError *))block {
    SVHTTPRequest *requestObject = [[self alloc] initRequestWithAddress:address method:SVHTTPRequestMethodGET parameters:parameters saveToPath:savePath progress:nil completion:block];
    [requestObject start];
    
    return [requestObject autorelease];
}

+ (SVHTTPRequest*)GET:(NSString *)address parameters:(NSDictionary *)parameters saveToPath:(NSString *)savePath progress:(void (^)(float))progressBlock completion:(void (^)(id, NSError *))completionBlock {
    SVHTTPRequest *requestObject = [[self alloc] initRequestWithAddress:address method:SVHTTPRequestMethodGET parameters:parameters saveToPath:savePath progress:progressBlock completion:completionBlock];
    [requestObject start];
    
    return [requestObject autorelease];
}


+ (SVHTTPRequest*)POST:(NSString *)address parameters:(NSDictionary *)parameters completion:(void (^)(id, NSError*))block {
    SVHTTPRequest *requestObject = [[self alloc] initRequestWithAddress:address method:SVHTTPRequestMethodPOST parameters:parameters saveToPath:nil progress:nil completion:block];
    [requestObject start];
    
    return [requestObject autorelease];
}

+ (SVHTTPRequest*)PUT:(NSString *)address parameters:(NSDictionary *)parameters completion:(void (^)(id, NSError*))block {
    SVHTTPRequest *requestObject = [[self alloc] initRequestWithAddress:address method:SVHTTPRequestMethodPUT parameters:parameters saveToPath:nil progress:nil completion:block];
    [requestObject start];
    
    return [requestObject autorelease];
}

+ (SVHTTPRequest*)DELETE:(NSString *)address parameters:(NSDictionary *)parameters completion:(void (^)(id, NSError*))block {
    SVHTTPRequest *requestObject = [[self alloc] initRequestWithAddress:address method:SVHTTPRequestMethodDELETE parameters:parameters saveToPath:nil progress:nil completion:block];
    [requestObject start];
    
    return [requestObject autorelease];
}


#pragma mark -

- (SVHTTPRequest*)initRequestWithAddress:(NSString *)urlString method:(SVHTTPRequestMethod)method parameters:(NSDictionary *)parameters completion:(void (^)(id, NSError *))completionBlock {
    return [(id<SVHTTPRequestPrivateMethods>)self initRequestWithAddress:urlString method:method parameters:parameters saveToPath:nil progress:NULL completion:completionBlock];
}

- (SVHTTPRequest*)initRequestWithAddress:(NSString*)urlString method:(SVHTTPRequestMethod)method parameters:(NSDictionary*)parameters saveToPath:(NSString*)savePath progress:(void (^)(float))progressBlock completion:(void (^)(id, NSError*))completionBlock  {
    self = [super init];
    self.operationCompletionBlock = completionBlock;
    self.operationProgressBlock = progressBlock;
    self.operationSavePath = savePath;

    self.operationRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]]; 
    [self.operationRequest setTimeoutInterval:kSVHTTPRequestTimeoutInterval];
    [self.operationRequest setCachePolicy:self.cachePolicy];
    
    if(method == SVHTTPRequestMethodGET)
        [self.operationRequest setHTTPMethod:@"GET"];
    else if(method == SVHTTPRequestMethodPOST)
        [self.operationRequest setHTTPMethod:@"POST"];
    else if(method == SVHTTPRequestMethodPUT)
        [self.operationRequest setHTTPMethod:@"PUT"];
    else if(method == SVHTTPRequestMethodDELETE)
        [self.operationRequest setHTTPMethod:@"DELETE"];
    
    // USER_AGENT is set as follow: Demo/1.0 iOS/5.0 iPhone3,1 
    NSString *userAgent = [NSString stringWithFormat:@"%@/%@ iOS/%@ %@", 
                           [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"], 
                           [[UIDevice currentDevice] systemVersion],
                           [[UIDevice currentDevice] deviceType]];
    [self.operationRequest setValue:userAgent forHTTPHeaderField:@"USER_AGENT"];
    
    if(parameters)
        [self addParametersToRequest:parameters];
    
    self.state = SVHTTPRequestStateReady;

    return self;
}


- (void)addParametersToRequest:(NSDictionary*)paramsDict {
    
    NSUInteger parameterCount = [[paramsDict allKeys] count];
    
    NSMutableArray *stringParameters = [NSMutableArray arrayWithCapacity:parameterCount];
    NSMutableArray *dataParameters = [NSMutableArray arrayWithCapacity:parameterCount];
    NSString *method = self.operationRequest.HTTPMethod;
    
    [paramsDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        
        if([obj isKindOfClass:[NSString class]]) {
            NSString *cleanParameter = [obj encodedURLParameterString];
            [stringParameters addObject:[NSString stringWithFormat:@"%@=%@", key, cleanParameter]];
        } 
        
        else if([obj isKindOfClass:[NSNumber class]]) {
            [stringParameters addObject:[NSString stringWithFormat:@"%@=%@", key, obj]];
        } 
        
        else if([obj isKindOfClass:[NSData class]]) {
            if(![method isEqualToString:@"POST"] && ![method isEqualToString:@"PUT"]) {
                NSLog(@"**SVHTTPRequest: You can only send multipart/form-data over a POST and PUT requests.");
                exit(0);
            }
            
            NSString *dataBoundaryString = [NSString stringWithString:@"SVHTTPRequestBoundary"];
            NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", dataBoundaryString];
            [self.operationRequest addValue:contentType forHTTPHeaderField: @"Content-Type"];
            
            NSMutableData *data = [NSMutableData data];
            [data appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", dataBoundaryString] dataUsingEncoding:NSUTF8StringEncoding]];
            [data appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"userfile\"\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
            [data appendData:[[NSString stringWithString:@"Content-Type: application/octet-stream\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
            [data appendData:[NSData dataWithData:obj]];
            [data appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", dataBoundaryString] dataUsingEncoding:NSUTF8StringEncoding]];
            [dataParameters addObject:data];
        }
    }];
    
    NSString *parameterString = [stringParameters componentsJoinedByString:@"&"];
    
    if([method isEqualToString:@"GET"]) {
        NSString *baseAddress = self.operationRequest.URL.absoluteString;
        baseAddress = [baseAddress stringByAppendingFormat:@"?%@", [stringParameters componentsJoinedByString:@"&"]];
        [self.operationRequest setURL:[NSURL URLWithString:baseAddress]];
    }
    else if(self.sendParametersAsJSON) {
        [self.operationRequest setHTTPBody:[paramsDict JSONData]];
    }
    else {
        const char *stringData = [parameterString UTF8String];
        NSMutableData *postData = [NSMutableData dataWithBytes:stringData length:strlen(stringData)];
        
        for(NSData *fileData in dataParameters)
            [postData appendData:fileData];
        
        [self.operationRequest setHTTPBody:postData];
    }
}


- (void)signRequestWithUsername:(NSString*)username password:(NSString*)password  {
    NSString *authStr = [NSString stringWithFormat:@"%@:%@", username, password];
    NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64EncodingWithLineLength:140]];
    [self.operationRequest setValue:authValue forHTTPHeaderField:@"Authorization"];
}


- (void)setTimeoutTimer:(NSTimer *)newTimer {
    
    if(timeoutTimer)
        [timeoutTimer invalidate], [timeoutTimer release], timeoutTimer = nil;
    
    if(newTimer)
        timeoutTimer = [newTimer retain];
}

#pragma mark - NSOperation methods

- (void)start {
    
    if(self.isCancelled) {
        [self finish];
        return;
    }
    
    if(![NSThread isMainThread]) { // NSOperationQueue calls start from a bg thread (through GCD), but NSURLConnection already does that by itself
        [self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
        return;
    }
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    [self willChangeValueForKey:@"isExecuting"];
    self.state = SVHTTPRequestStateExecuting;    
    [self didChangeValueForKey:@"isExecuting"];
    
    if(self.operationSavePath) {
        [[NSFileManager defaultManager] createFileAtPath:self.operationSavePath contents:nil attributes:nil];
        self.operationFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.operationSavePath];
    } else {
        self.operationData = [[NSMutableData alloc] init];
        self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:kSVHTTPRequestTimeoutInterval target:self selector:@selector(requestTimeout) userInfo:nil repeats:NO];
    }
    
    self.operationConnection = [[NSURLConnection alloc] initWithRequest:self.operationRequest delegate:self startImmediately:NO];
    
    if(self.operationSavePath) // schedule on main run loop so scrolling doesn't prevent UI updates of the progress block
        [self.operationConnection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    
    [self.operationConnection start];
    
    NSLog(@"[%@] %@", self.operationRequest.HTTPMethod, self.operationRequest.URL.absoluteString);
}

// private method; not part of NSOperation
- (void)finish {
    [self.operationConnection cancel];
    [operationConnection release];
    operationConnection = nil;
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    self.state = SVHTTPRequestStateFinished;    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (void)cancel {
    if([self isFinished])
        return;
    
    [super cancel];
    [self callCompletionBlockWithResponse:nil error:nil];
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

#pragma mark -
#pragma mark Delegate Methods

- (void)requestTimeout {
    NSError *timeoutError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    [self connection:nil didFailWithError:timeoutError];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.expectedContentLength = response.expectedContentLength;
    self.receivedContentLength = 0;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if(self.operationSavePath)
        [self.operationFileHandle writeData:data];
    else
        [self.operationData appendData:data];
    
    if(self.operationProgressBlock) {
        //If its -1 that means the header does not have the content size value
        if(self.expectedContentLength != -1) {
            self.receivedContentLength += data.length;
            self.operationProgressBlock(self.receivedContentLength/self.expectedContentLength);
        } else {
            //we dont know the full size so always return -1 as the progress
            self.operationProgressBlock(-1);
        }
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    id response = nil;
    
    if(self.operationData && self.operationData.length > 0) {
        response = [NSData dataWithData:self.operationData];
        
        // try to parse JSON. If image or XML, will return raw NSData object
        NSDictionary *jsonObject = [response objectFromJSONData];
        
        if(jsonObject)
            response = jsonObject;
    }
    
    [self callCompletionBlockWithResponse:response error:nil];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self callCompletionBlockWithResponse:nil error:error];
}

- (void)callCompletionBlockWithResponse:(id)response error:(NSError *)error {
    self.timeoutTimer = nil;
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
    if(self.operationCompletionBlock && !self.isCancelled)
        self.operationCompletionBlock(response, error);
    
    [self finish];
}

@end

#pragma mark - Utility methods

@implementation UIDevice (SVHTTPRequest)

#include <sys/socket.h> // Per msqr
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>

- (NSString*)deviceType {
    size_t size;
    
    // Set 'oldp' parameter to NULL to get the size of the data
    // returned so we can allocate appropriate amount of space
    sysctlbyname("hw.machine", NULL, &size, NULL, 0); 
    
    // Allocate the space to store name
    char *name = malloc(size);
    
    // Get the platform name
    sysctlbyname("hw.machine", name, &size, NULL, 0);
    
    // Place name into a string
    NSString *machine = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
    
    // Done with this
    free(name);
    
    return machine;
}

@end

// Created by Jon Crosby on 10/19/07.
// Copyright 2007 Kaboomerang LLC. All rights reserved.

@implementation NSString (SVHTTPRequest)

- (NSString*)encodedURLParameterString {
    NSString *result = (NSString*)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                           (CFStringRef)self,
                                                                           NULL,
                                                                           CFSTR(":/=,!$&'()*+;[]@#?"),
                                                                           kCFStringEncodingUTF8);
	return [result autorelease];
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

@end


