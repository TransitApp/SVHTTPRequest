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

@property (nonatomic, strong) NSMutableDictionary *HTTPHeaderFields;

@end


@implementation SVHTTPClient

@synthesize username, password, basePath, userAgent, sendParametersAsJSON, cachePolicy, operationQueue, HTTPHeaderFields;


+ (id)sharedClient {
	
    static SVHTTPClient *_sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [[self alloc] init];
    });
    
    return _sharedInstance;
}

- (id)init {
    if (self = [super init]) {
        self.operationQueue = [[NSOperationQueue alloc] init];
        
        [self.operationQueue addObserver:self
                              forKeyPath:@"operationCount"
                                 options:NSKeyValueObservingOptionNew
                                 context:&self->operationQueue];
    }
    
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"operationCount"]) {
#if TARGET_OS_IPHONE
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL indicatorVisible = self.operationQueue.operationCount > 0;
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:indicatorVisible];
        });
#endif
    }
    else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)dealloc
{
    [self.operationQueue removeObserver:self forKeyPath:@"operationCount" context:&self->operationQueue];
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

- (NSMutableDictionary *)HTTPHeaderFields {
    if(HTTPHeaderFields == nil)
        HTTPHeaderFields = [NSMutableDictionary new];
    
    return HTTPHeaderFields;
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    [self.HTTPHeaderFields setValue:value forKey:field];
}

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
    
    [self.HTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *field, NSString *value, BOOL *stop) {
        [(id<SVHTTPRequestPrivateMethods>)requestOperation setValue:value forHTTPHeaderField:field];
    }];
    
    if(self.username && self.password)
        [(id<SVHTTPRequestPrivateMethods>)requestOperation signRequestWithUsername:self.username password:self.password];
    
    [(id<SVHTTPRequestPrivateMethods>)requestOperation setRequestPath:path];
    [self.operationQueue addOperation:requestOperation];
}

@end
