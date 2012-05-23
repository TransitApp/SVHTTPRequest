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

@property (nonatomic, strong) NSOperationQueue *operationQueue;

- (void)queueRequest:(NSString*)path 
              method:(SVHTTPRequestMethod)method 
          parameters:(NSDictionary*)parameters 
          saveToPath:(NSString*)savePath 
            progress:(void (^)(float))progressBlock
          completion:(void (^)(id, NSHTTPURLResponse*, NSError*))completionBlock;

@end


@implementation SVHTTPClient

@synthesize username, password, basePath, userAgent, sendParametersAsJSON, cachePolicy, operationQueue;


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


- (void)setBasicAuthWithUsername:(NSString *)newUsername password:(NSString *)newPassword {
    
    if(username)
        username = nil;
    
    if(password)
        password = nil;
    
    if(newUsername && newPassword) {
        username = newUsername;
        password = newPassword;
    }
}

#pragma mark - Request Methods

- (void)GET:(NSString *)path parameters:(NSDictionary *)parameters completion:(void (^)(id, NSHTTPURLResponse*, NSError*))completionBlock {
    [self queueRequest:path method:SVHTTPRequestMethodGET parameters:parameters saveToPath:nil progress:nil completion:completionBlock];
}

- (void)GET:(NSString *)path parameters:(NSDictionary *)parameters saveToPath:(NSString *)savePath progress:(void (^)(float))progressBlock completion:(void (^)(id, NSHTTPURLResponse*, NSError *))completionBlock {
    [self queueRequest:path method:SVHTTPRequestMethodGET parameters:parameters saveToPath:savePath progress:progressBlock completion:completionBlock];
}

- (void)POST:(NSString *)path parameters:(NSDictionary *)parameters completion:(void (^)(id, NSHTTPURLResponse*, NSError*))completionBlock {
    [self queueRequest:path method:SVHTTPRequestMethodPOST parameters:parameters saveToPath:nil progress:nil completion:completionBlock];
}

- (void)PUT:(NSString *)path parameters:(NSDictionary *)parameters completion:(void (^)(id, NSHTTPURLResponse*, NSError*))completionBlock {
    [self queueRequest:path method:SVHTTPRequestMethodPUT parameters:parameters saveToPath:nil progress:nil completion:completionBlock];
}

- (void)DELETE:(NSString *)path parameters:(NSDictionary *)parameters completion:(void (^)(id, NSHTTPURLResponse*, NSError*))completionBlock {
    [self queueRequest:path method:SVHTTPRequestMethodDELETE parameters:parameters saveToPath:nil progress:nil completion:completionBlock];
}

- (void)HEAD:(NSString *)path parameters:(NSDictionary *)parameters completion:(void (^)(id, NSHTTPURLResponse*, NSError*))completionBlock {
    [self queueRequest:path method:SVHTTPRequestMethodHEAD parameters:parameters saveToPath:nil progress:nil completion:completionBlock];
}

#pragma mark - Operation Cancelling

- (void)cancelRequestsWithPath:(NSString *)path {
    [self.operationQueue.operations enumerateObjectsUsingBlock:^(id request, NSUInteger idx, BOOL *stop) {
        NSString *requestPath = [request valueForKey:@"requestPath"];
        if([requestPath isEqualToString:path])
            [request cancel];
    }];
}

- (void)cancelAllRequests {
    [self.operationQueue cancelAllOperations];
}

#pragma mark -

- (void)queueRequest:(NSString*)path 
              method:(SVHTTPRequestMethod)method 
          parameters:(NSDictionary*)parameters 
          saveToPath:(NSString*)savePath 
            progress:(void (^)(float))progressBlock 
          completion:(void (^)(id, NSHTTPURLResponse*, NSError *))completionBlock  {
    
    NSString *completeURLString = [NSString stringWithFormat:@"%@%@", self.basePath, path];
    SVHTTPRequest *requestOperation = [(id<SVHTTPRequestPrivateMethods>)[SVHTTPRequest alloc] initWithAddress:completeURLString method:method parameters:parameters saveToPath:savePath progress:progressBlock completion:completionBlock];
    requestOperation.sendParametersAsJSON = self.sendParametersAsJSON;
    requestOperation.cachePolicy = self.cachePolicy;
    requestOperation.userAgent = self.userAgent;
    
    if(self.username && self.password)
        [(id<SVHTTPRequestPrivateMethods>)requestOperation signRequestWithUsername:self.username password:self.password];
    
    [(id<SVHTTPRequestPrivateMethods>)requestOperation setRequestPath:path];
    [self.operationQueue addOperation:requestOperation];
}

@end
