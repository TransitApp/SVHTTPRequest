//
//  SVHTTPClient.m
//
//  Created by Sam Vermette on 15.12.11.
//  Copyright 2011 samvermette.com. All rights reserved.
//
//  https://github.com/samvermette/SVHTTPRequest
//

#import "SVHTTPClient.h"
#import "SVHTTPRequest.h"

@interface SVHTTPClient ()

@property (nonatomic, retain) NSString *basePath;
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;

@property (nonatomic, assign) NSOperationQueue *operationQueue;

- (void)queueRequest:(NSString*)urlString withMethod:(NSString*)method parameters:(NSDictionary*)parameters completion:(void (^)(id, NSError*))block;

@end


@implementation SVHTTPClient

@synthesize username, password, basePath, operationQueue;

- (void)dealloc {
    self.basePath = nil;
    self.username = nil;
    self.password = nil;
    
    [operationQueue release];
    
	[super dealloc];
}

+ (SVHTTPClient*)sharedClient {
	
    static SVHTTPClient *_sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [[self alloc] init];
    });
    
    return _sharedInstance;
}

- (id)init {
    self = [super init];
    self.operationQueue = [[NSOperationQueue alloc] init];
    return self;
}

#pragma mark - Setters

- (void)setBasePath:(NSString *)newBasePath {
    
    if(basePath)
        [basePath release], basePath = nil;
    
    if(newBasePath)
        basePath = [newBasePath retain];
}

- (void)setBasicAuthWithUsername:(NSString *)newUsername password:(NSString *)newPassword {
    
    if(username)
        [username release], username = nil;
    
    if(password)
        [password release], password = nil;
    
    if(newUsername && newPassword) {
        username = [newUsername retain];
        password = [newPassword retain];
    }
}

#pragma mark - Request Methods

- (void)GET:(NSString *)path parameters:(NSDictionary *)parameters completion:(void (^)(id, NSError*))block {
    [self queueRequest:path withMethod:@"GET" parameters:parameters completion:block];
}

- (void)POST:(NSString *)path parameters:(NSDictionary *)parameters completion:(void (^)(id, NSError*))block {
    [self queueRequest:path withMethod:@"POST" parameters:parameters completion:block];
}

- (void)PUT:(NSString *)path parameters:(NSDictionary *)parameters completion:(void (^)(id, NSError*))block {
    [self queueRequest:path withMethod:@"PUT" parameters:parameters completion:block];
}

- (void)DELETE:(NSString *)path parameters:(NSDictionary *)parameters completion:(void (^)(id, NSError*))block {
    [self queueRequest:path withMethod:@"DELETE" parameters:parameters completion:block];
}

- (void)cancelAllRequests {
    [self.operationQueue cancelAllOperations];
}

#pragma mark -

- (void)queueRequest:(NSString*)urlString withMethod:(NSString*)method parameters:(NSDictionary*)parameters completion:(void (^)(id, NSError*))block  {
    NSString *completeURLString = [NSString stringWithFormat:@"%@%@", self.basePath?self.basePath:@"", urlString];
    SVHTTPRequest *requestOperation = [(id<SVHTTPRequestPrivateMethods>)[SVHTTPRequest alloc] initRequestWithAddress:completeURLString method:method parameters:parameters completion:block];
    
    if(self.username && self.password)
        [(id<SVHTTPRequestPrivateMethods>)requestOperation signRequestWithUsername:self.username password:self.password];
    
    [self.operationQueue addOperation:requestOperation];
    [requestOperation release];
}

@end
