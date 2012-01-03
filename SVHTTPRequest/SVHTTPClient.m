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

- (void)queueRequest:(NSString*)urlString 
          withMethod:(NSString*)method 
          parameters:(NSDictionary*)parameters 
          saveToPath:(NSString*)savePath 
            progress:(void (^)(float))progressBlock
          completion:(void (^)(id, NSError*))completionBlock;

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

- (void)GET:(NSString *)path parameters:(NSDictionary *)parameters completion:(void (^)(id, NSError*))completionBlock {
    [self queueRequest:path withMethod:@"GET" parameters:parameters saveToPath:nil progress:nil completion:completionBlock];
}

- (void)GET:(NSString *)path parameters:(NSDictionary *)parameters saveToPath:(NSString *)savePath completion:(void (^)(id, NSError *))completionBlock {
    [self queueRequest:path withMethod:@"GET" parameters:parameters saveToPath:savePath progress:nil completion:completionBlock];
}

- (void)GET:(NSString *)path parameters:(NSDictionary *)parameters saveToPath:(NSString *)savePath progress:(void (^)(float))progressBlock completion:(void (^)(id, NSError *))completionBlock {
    [self queueRequest:path withMethod:@"GET" parameters:parameters saveToPath:savePath progress:progressBlock completion:completionBlock];
}

- (void)POST:(NSString *)path parameters:(NSDictionary *)parameters completion:(void (^)(id, NSError*))completionBlock {
    [self queueRequest:path withMethod:@"POST" parameters:parameters saveToPath:nil progress:nil completion:completionBlock];
}

- (void)PUT:(NSString *)path parameters:(NSDictionary *)parameters completion:(void (^)(id, NSError*))completionBlock {
    [self queueRequest:path withMethod:@"PUT" parameters:parameters saveToPath:nil progress:nil completion:completionBlock];
}

- (void)DELETE:(NSString *)path parameters:(NSDictionary *)parameters completion:(void (^)(id, NSError*))completionBlock {
    [self queueRequest:path withMethod:@"DELETE" parameters:parameters saveToPath:nil progress:nil completion:completionBlock];
}

- (void)cancelAllRequests {
    [self.operationQueue cancelAllOperations];
}

#pragma mark -

- (void)queueRequest:(NSString*)urlString 
          withMethod:(NSString*)method 
          parameters:(NSDictionary*)parameters 
          saveToPath:(NSString*)savePath 
            progress:(void (^)(float))progressBlock 
          completion:(void (^)(id, NSError *))completionBlock  {
    
    NSString *completeURLString = [NSString stringWithFormat:@"%@%@", self.basePath?self.basePath:@"", urlString];
    SVHTTPRequest *requestOperation = [(id<SVHTTPRequestPrivateMethods>)[SVHTTPRequest alloc] initRequestWithAddress:completeURLString method:method parameters:parameters saveToPath:savePath progress:progressBlock completion:completionBlock];
    
    if(self.username && self.password)
        [(id<SVHTTPRequestPrivateMethods>)requestOperation signRequestWithUsername:self.username password:self.password];
    
    [self.operationQueue addOperation:requestOperation];
    [requestOperation release];
}

@end
