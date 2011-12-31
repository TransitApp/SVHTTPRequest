//
//  DemoViewController.m
//  Demo
//
//  Created by Sam Vermette on 20.09.11.
//  Copyright 2011 samvermette.com. All rights reserved.
//

#import "DemoViewController.h"
#import "SVHTTPRequest.h"

@implementation DemoViewController


- (IBAction)watchersRequest {
    
    watchersLabel.text = nil;
    
    [SVHTTPRequest GET:@"http://github.com/api/v2/json/repos/show/samvermette/SVHTTPRequest"
            parameters:nil
            completion:^(id response, NSError *error) {
                watchersLabel.text = [NSString stringWithFormat:@"SVHTTPRequest has %@ watchers", [[response valueForKey:@"repository"] valueForKey:@"watchers"]];
            }];
}

- (IBAction)twitterRequest {
    
    twitterImageView.image = nil;
    followersLabel.text = nil;
    
    [[SVHTTPClient sharedClient] setBasePath:@"http://api.twitter.com/1/"];
    
    [[SVHTTPClient sharedClient] GET:@"users/profile_image"
                          parameters:[NSDictionary dictionaryWithObjectsAndKeys:
                                      @"samvermette", @"screen_name",
                                      @"original", @"size",
                                      nil]
                          completion:^(id response, NSError *error) {
                              twitterImageView.image = [UIImage imageWithData:response];
                          }];
    
    [[SVHTTPClient sharedClient] GET:@"users/show.json"
                          parameters:[NSDictionary dictionaryWithObject:@"samvermette" forKey:@"screen_name"]
                          completion:^(id response, NSError *error) {
                              followersLabel.text = [NSString stringWithFormat:@"@samvermette has %@ followers", [response valueForKey:@"followers_count"]];
                          }];
}

- (IBAction)downloadRequest {
    
    downloadLabel.text = nil;
    
    [SVHTTPRequest GET:@"http://sanjosetransit.com/extras/iAdInterstitialSuite.zip" 
            parameters:nil 
            saveToPath:@"/Volumes/Data/test.zip" 
     progressIndicator:progressIndicator
            completion:^(id response, NSError *error) {
                downloadLabel.text = @"Download complete.";
            }];
}


@end
