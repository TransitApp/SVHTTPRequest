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

@property (nonatomic, readwrite) SVHTTPRequestState state;

@property (nonatomic, retain) NSTimer *timeoutTimer; // see http://stackoverflow.com/questions/2736967

@property (nonatomic, retain) UIProgressView *operationProgressIndicator;
@property (nonatomic, retain) NSNumber *responseSize;
@property (nonatomic, readwrite) NSUInteger intermediateResourceLength;

- (void)addParametersToRequest:(NSDictionary*)paramsDict;
- (void)finish;

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;

@end


@implementation SVHTTPRequest

// private properties
@synthesize operationRequest, operationData, operationConnection, operationFileHandle, state;
@synthesize operationSavePath, operationCompletionBlock, timeoutTimer;
@synthesize operationProgressIndicator, responseSize, intermediateResourceLength;
	
- (void)dealloc {
    [operationData release];
    [operationRequest release];
    [operationConnection cancel];
    [operationConnection release];
    
    self.operationCompletionBlock = nil;
    self.operationFileHandle = nil;
    self.operationSavePath = nil;
    self.timeoutTimer = nil;
    
	[super dealloc];
}

#pragma mark - Convenience Methods

+ (SVHTTPRequest*)GET:(NSString *)address parameters:(NSDictionary *)parameters completion:(void (^)(id, NSError*))block {
    SVHTTPRequest *requestObject = [[self alloc] initRequestWithAddress:address method:@"GET" parameters:parameters saveToPath:nil progressIndicator:nil completion:block];
    [requestObject start];
    
    return [requestObject autorelease];
}

+ (SVHTTPRequest*)GET:(NSString *)address parameters:(NSDictionary *)parameters saveToPath:(NSString *)savePath completion:(void (^)(id, NSError *))block {
    SVHTTPRequest *requestObject = [[self alloc] initRequestWithAddress:address method:@"GET" parameters:parameters saveToPath:savePath                        progressIndicator:nil completion:block];
    [requestObject start];
    
    return [requestObject autorelease];
}

+ (SVHTTPRequest*)GET:(NSString*)address parameters:(NSDictionary*)parameters saveToPath:(NSString*)savePath progressIndicator:(UIProgressView*)progressIndicator completion:(void (^)(id response, NSError *error))block{
    SVHTTPRequest *requestObject = [[self alloc] initRequestWithAddress:address method:@"GET" parameters:parameters saveToPath:savePath                        progressIndicator:progressIndicator completion:block];
    [requestObject start];
    
    return [requestObject autorelease];
}

+ (SVHTTPRequest*)POST:(NSString *)address parameters:(NSDictionary *)parameters completion:(void (^)(id, NSError*))block {
    SVHTTPRequest *requestObject = [[self alloc] initRequestWithAddress:address method:@"POST" parameters:parameters saveToPath:nil progressIndicator:nil completion:block];
    [requestObject start];
    
    return [requestObject autorelease];
}

+ (SVHTTPRequest*)PUT:(NSString *)address parameters:(NSDictionary *)parameters completion:(void (^)(id, NSError*))block {
    SVHTTPRequest *requestObject = [[self alloc] initRequestWithAddress:address method:@"PUT" parameters:parameters saveToPath:nil progressIndicator:nil completion:block];
    [requestObject start];
    
    return [requestObject autorelease];
}

+ (SVHTTPRequest*)DELETE:(NSString *)address parameters:(NSDictionary *)parameters completion:(void (^)(id, NSError*))block {
    SVHTTPRequest *requestObject = [[self alloc] initRequestWithAddress:address method:@"DELETE" parameters:parameters saveToPath:nil progressIndicator:nil completion:block];
    [requestObject start];
    
    return [requestObject autorelease];
}


#pragma mark -

- (SVHTTPRequest*)initRequestWithAddress:(NSString*)urlString method:(NSString*)method parameters:(NSDictionary*)parameters saveToPath:(NSString*)savePath                        progressIndicator:(UIProgressView*)progressIndicator completion:(void (^)(id, NSError*))block  {
    self = [super init];
    self.operationCompletionBlock = block;
    self.operationSavePath = savePath;

    self.operationRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]]; 
    [self.operationRequest setTimeoutInterval:kSVHTTPRequestTimeoutInterval];
    [self.operationRequest setHTTPMethod:method];
    
    if(parameters)
        [self addParametersToRequest:parameters];
    
    if (progressIndicator) {
        self.operationProgressIndicator = progressIndicator;
    }
    
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
    
    self.operationConnection = [[NSURLConnection alloc] initWithRequest:self.operationRequest delegate:self startImmediately:YES];
    NSLog(@"[%@] %@", self.operationRequest.HTTPMethod, self.operationRequest.URL.absoluteString);
}

// private method; not part of NSOperation
- (void)finish {
    [self.operationConnection cancel];
    [self.operationConnection release];
    operationConnection = nil;
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    self.state = SVHTTPRequestStateFinished;    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

- (void)cancel {
    if([self isFinished])
        return;
    
    [super cancel];
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

#pragma mark -
#pragma mark Delegate Methods

- (void)requestTimeout {
    NSError *timeoutError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    [self connection:nil didFailWithError:timeoutError];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.responseSize = [NSNumber numberWithLongLong:[response expectedContentLength]];
    self.intermediateResourceLength = 0;
    NSLog(@"content-length: %@ bytes", self.responseSize);
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if(self.operationSavePath)
        [self.operationFileHandle writeData:data];
    else
        [self.operationData appendData:data];
    
    //If its -1 that means the header does not have the content size value
    if ([self.responseSize intValue]!=-1) {
        self.intermediateResourceLength += [data length];
        [self.operationProgressIndicator setProgress:(self.intermediateResourceLength / [self.responseSize floatValue]) animated:YES];
    } else {
        //set download progress bar style as intermediate
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    self.timeoutTimer = nil;
    id response = nil;
    
    if(self.operationData && self.operationData.length > 0) {
        response = [NSData dataWithData:self.operationData];
        
        // try to parse JSON. If image or XML, will return raw NSData object
        NSDictionary *jsonObject = [response objectFromJSONData];
        
        if(jsonObject)
            response = jsonObject;
    }
    
    if(self.operationCompletionBlock)
        self.operationCompletionBlock(response, nil);
        
    [self finish];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.timeoutTimer = nil;
	[self.operationProgressIndicator setProgress:0.0 animated:YES];
	NSLog(@"requestFailed: %@", [error localizedDescription]);
	self.operationCompletionBlock(nil, error);
    
    [self finish];
}

@end

#pragma mark - Utility methods

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


