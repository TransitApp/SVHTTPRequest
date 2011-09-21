//
//  SVHTTPRequest.m
//
//  Created by Sam Vermette on 20.09.11.
//  Copyright 2011 samvermette.com. All rights reserved.
//

#import "SVHTTPRequest.h"
#import "JSONKit.h"


@interface NSData (Base64)
- (NSString*)base64EncodingWithLineLength:(unsigned int)lineLength;
@end

@interface NSString (OAURLEncodingAdditions)
- (NSString*)encodedURLParameterString;
@end

@interface SVHTTPRequest ()

@property (nonatomic, assign) NSMutableURLRequest *request;
@property (nonatomic, assign) NSMutableData *requestData;
@property (nonatomic, assign) NSURLConnection *requestConnection;
@property (nonatomic, copy) void (^completionBlock)(NSObject *response);
@property (nonatomic, retain) NSTimer *timeoutTimer; // see http://stackoverflow.com/questions/2736967
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;

+ (SVHTTPRequest*)method:(NSString*)method address:(NSString*)address parameters:(NSDictionary *)parameters username:(NSString *)username password:(NSString *)password completion:(void (^)(NSObject *))block;

- (SVHTTPRequest*)initWithCompletionBlock:(void (^)(NSObject *response))block;

- (void)signRequest;
- (void)addParametersToRequest:(NSDictionary*)paramsDict;
- (void)makeRequest:(NSString*)urlString withMethod:(NSString*)method parameters:(NSDictionary*)parameters;

@end


@implementation SVHTTPRequest

// public properties
@synthesize username, password;

// private properties
@synthesize request, requestData, requestConnection, completionBlock, timeoutTimer;
	
- (void)dealloc {
    [requestData release];
    [request release];
    
    [requestConnection cancel];
    [requestConnection release];
    
    self.completionBlock = nil;
    self.timeoutTimer = nil;
    self.username = nil;
    self.password = nil;
    
	[super dealloc];
}

#pragma mark - Convenience Methods

+ (SVHTTPRequest*)GET:(NSString *)address parameters:(NSDictionary *)parameters completion:(void (^)(NSObject *))block {
    return [self GET:address parameters:parameters username:nil password:nil completion:block];
}

+ (SVHTTPRequest*)POST:(NSString *)address parameters:(NSDictionary *)parameters completion:(void (^)(NSObject *))block {
    return [self POST:address parameters:parameters username:nil password:nil completion:block];
}

+ (SVHTTPRequest *)GET:(NSString *)address parameters:(NSDictionary *)parameters username:(NSString *)username password:(NSString *)password completion:(void (^)(NSObject *))block {
    return [self method:@"GET" address:address parameters:parameters username:username password:password completion:block];
}

+ (SVHTTPRequest *)POST:(NSString *)address parameters:(NSDictionary *)parameters username:(NSString *)username password:(NSString *)password completion:(void (^)(NSObject *))block {
    return [self method:@"POST" address:address parameters:parameters username:username password:password completion:block];
}

+ (SVHTTPRequest*)method:(NSString*)method address:(NSString*)address  parameters:(NSDictionary *)parameters username:(NSString *)username password:(NSString *)password completion:(void (^)(NSObject *))block {
    
    SVHTTPRequest *request = [[[self alloc] initWithCompletionBlock:block] autorelease];
    request.username = username;
    request.password = password;
    [request makeRequest:address withMethod:method parameters:parameters];
    
    return request;
}

#pragma mark - 

- (SVHTTPRequest *)initWithCompletionBlock:(void (^)(NSObject *))block {
    
    if(self = [super init])
        self.completionBlock = block;

	return self;
}


- (void)makeRequest:(NSString*)urlString withMethod:(NSString*)method parameters:(NSDictionary*)parameters {
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
	NSLog(@"[%@] %@", method, urlString);
    
    if(parameters)
        NSLog(@"parameters = %@", parameters);
	
    request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]]; 
    
    [request setHTTPMethod:method];
    [request setTimeoutInterval:kSVHTTPRequestTimeoutInterval];
    
    [self addParametersToRequest:parameters];
    
    if(self.username && self.password)
        [self signRequest];
    
    requestData = [[NSMutableData alloc] init];
    requestConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
    self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:kSVHTTPRequestTimeoutInterval target:self selector:@selector(requestTimeout) userInfo:nil repeats:NO];
}


- (void)addParametersToRequest:(NSDictionary*)paramsDict {
    
    NSMutableArray *paramStringsArray = [NSMutableArray arrayWithCapacity:[[paramsDict allKeys] count]];
    
    for(NSString *key in [paramsDict allKeys]) {
        NSObject *paramValue = [paramsDict valueForKey:key];

        if([paramValue isKindOfClass:[NSString class]])
            paramValue = [(NSString*)paramValue encodedURLParameterString];
        
        [paramStringsArray addObject:[NSString stringWithFormat:@"%@=%@", key, paramValue]];
    }
    
    NSString *paramsString = [paramStringsArray componentsJoinedByString:@"&"];
    
    if([request.HTTPMethod isEqualToString:@"GET"]) {
        NSString *baseAddress = request.URL.absoluteString;
        baseAddress = [baseAddress stringByAppendingFormat:@"?%@", paramsString];
        [request setURL:[NSURL URLWithString:baseAddress]];
    }
    
    else if([request.HTTPMethod isEqualToString:@"POST"]) {
        const char *data = [paramsString UTF8String];
        NSData *paramsData = [NSData dataWithBytes:data length:strlen(data)];
        [request setHTTPBody:paramsData];
    }
}


- (void)signRequest {
    NSString *authStr = [NSString stringWithFormat:@"%@:%@", self.username, self.password];
    NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64EncodingWithLineLength:140]];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
}

- (void)cancel {
    [requestConnection cancel];
}

- (void)setTimeoutTimer:(NSTimer *)newTimer {
    
    if(timeoutTimer)
        [timeoutTimer invalidate], [timeoutTimer release], timeoutTimer = nil;
    
    if(newTimer)
        timeoutTimer = [newTimer retain];
}

#pragma mark -
#pragma mark Delegate Methods

- (void)requestTimeout {
    [self connection:nil didFailWithError:nil];
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [requestData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    self.timeoutTimer = nil;
    
    NSObject *returnedObject = requestData;
    
    // try to parse JSON. If image or XML, will return raw NSData object
    NSDictionary *jsonObject = [requestData objectFromJSONData];
    
	if(jsonObject)
        returnedObject = jsonObject;

    self.completionBlock(returnedObject);
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.timeoutTimer = nil;

	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	
	NSLog(@"requestFailed: %@", [error localizedDescription]);
	self.completionBlock(nil);
}

@end

#pragma mark - Utility methods

// Created by Jon Crosby on 10/19/07.
// Copyright 2007 Kaboomerang LLC. All rights reserved.

@implementation NSString (OAURLEncodingAdditions)

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

@implementation NSData (Base64)

- (NSString *) base64EncodingWithLineLength:(unsigned int) lineLength {
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


