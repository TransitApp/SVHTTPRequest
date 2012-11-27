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

- (SVHTTPRequest*)queueRequest:(NSString*)path
                        method:(SVHTTPRequestMethod)method
                    parameters:(NSDictionary*)parameters
                    saveToPath:(NSString*)savePath
                      progress:(void (^)(float))progressBlock
                    completion:(SVHTTPRequestCompletionHandler)completionBlock;

@property (nonatomic, strong) NSMutableDictionary *HTTPHeaderFields;

@end


@implementation SVHTTPClient

@synthesize username, password, basePath, baseParameters, userAgent, sendParametersAsJSON, cachePolicy, timeoutInterval;
@synthesize operationQueue, HTTPHeaderFields;


+ (id)sharedClient {
    return [self sharedClientWithIdentifier:@"master"];
}

+ (id)sharedClientWithIdentifier:(NSString *)identifier {
    SVHTTPClient *sharedClient = [[self sharedClients] objectForKey:identifier];
    
    if(!sharedClient) {
        sharedClient = [[self alloc] init];
        [[self sharedClients] setObject:sharedClient forKey:identifier];
    }
    
    return sharedClient;
}

+ (id)sharedClients {
    static NSMutableDictionary *_sharedClients = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{ _sharedClients = [[NSMutableDictionary alloc] init]; });
    return _sharedClients;
}

- (id)init {
    if (self = [super init]) {
        self.operationQueue = [[NSOperationQueue alloc] init];
        self.basePath = @"";
    }
    
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

- (SVHTTPRequest*)GET:(NSString *)path parameters:(NSDictionary *)parameters completion:(SVHTTPRequestCompletionHandler)completionBlock {
    return [self queueRequest:path method:SVHTTPRequestMethodGET parameters:parameters saveToPath:nil progress:nil completion:completionBlock];
}

- (SVHTTPRequest*)GET:(NSString *)path parameters:(NSDictionary *)parameters saveToPath:(NSString *)savePath progress:(void (^)(float))progressBlock completion:(SVHTTPRequestCompletionHandler)completionBlock {
    return [self queueRequest:path method:SVHTTPRequestMethodGET parameters:parameters saveToPath:savePath progress:progressBlock completion:completionBlock];
}

- (SVHTTPRequest*)POST:(NSString *)path parameters:(NSDictionary *)parameters completion:(SVHTTPRequestCompletionHandler)completionBlock {
    return [self queueRequest:path method:SVHTTPRequestMethodPOST parameters:parameters saveToPath:nil progress:nil completion:completionBlock];
}

- (SVHTTPRequest*)POST:(NSString *)path parameters:(NSDictionary *)parameters progress:(void (^)(float))progressBlock completion:(void (^)(id, NSHTTPURLResponse*, NSError *))completionBlock {
    return [self queueRequest:path method:SVHTTPRequestMethodPOST parameters:parameters saveToPath:nil progress:progressBlock completion:completionBlock];
}

- (SVHTTPRequest*)PUT:(NSString *)path parameters:(NSDictionary *)parameters completion:(SVHTTPRequestCompletionHandler)completionBlock {
    return [self queueRequest:path method:SVHTTPRequestMethodPUT parameters:parameters saveToPath:nil progress:nil completion:completionBlock];
}

- (SVHTTPRequest*)DELETE:(NSString *)path parameters:(NSDictionary *)parameters completion:(SVHTTPRequestCompletionHandler)completionBlock {
    return [self queueRequest:path method:SVHTTPRequestMethodDELETE parameters:parameters saveToPath:nil progress:nil completion:completionBlock];
}

- (SVHTTPRequest*)HEAD:(NSString *)path parameters:(NSDictionary *)parameters completion:(SVHTTPRequestCompletionHandler)completionBlock {
    return [self queueRequest:path method:SVHTTPRequestMethodHEAD parameters:parameters saveToPath:nil progress:nil completion:completionBlock];
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

- (SVHTTPRequest*)queueRequest:(NSString*)path
                        method:(SVHTTPRequestMethod)method
                    parameters:(NSDictionary*)parameters
                    saveToPath:(NSString*)savePath
                      progress:(void (^)(float))progressBlock
                    completion:(SVHTTPRequestCompletionHandler)completionBlock  {
    
    NSString *completeURLString = [NSString stringWithFormat:@"%@%@", self.basePath, path];
    
    NSMutableDictionary *mergedParameters = [NSMutableDictionary dictionary];
    [mergedParameters addEntriesFromDictionary:parameters];
    [mergedParameters addEntriesFromDictionary:self.baseParameters];
    
    SVHTTPRequest *requestOperation = [(id<SVHTTPRequestPrivateMethods>)[SVHTTPRequest alloc] initWithAddress:completeURLString method:method parameters:mergedParameters saveToPath:savePath progress:progressBlock completion:completionBlock];
    requestOperation.sendParametersAsJSON = self.sendParametersAsJSON;
    requestOperation.cachePolicy = self.cachePolicy;
    requestOperation.userAgent = self.userAgent;
    
    [(id<SVHTTPRequestPrivateMethods>)requestOperation setClient:self];
    
    [self.HTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *field, NSString *value, BOOL *stop) {
        [(id<SVHTTPRequestPrivateMethods>)requestOperation setValue:value forHTTPHeaderField:field];
    }];
    
    if(self.username && self.password)
        [(id<SVHTTPRequestPrivateMethods>)requestOperation signRequestWithUsername:self.username password:self.password];
    
    [(id<SVHTTPRequestPrivateMethods>)requestOperation setRequestPath:path];
    [self.operationQueue addOperation:requestOperation];
    
    return requestOperation;
}

@end
