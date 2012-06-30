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
    
    [SVHTTPRequest GET:@"https://api.github.com/repos/samvermette/SVHTTPRequest"
            parameters:nil
            completion:^(id response, NSHTTPURLResponse *urlResponse, NSError *error) {
                watchersLabel.text = [NSString stringWithFormat:@"SVHTTPRequest has %@ watchers", [response valueForKey:@"watchers"]];
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
                          completion:^(id response, NSHTTPURLResponse *urlResponse, NSError *error) {
                              twitterImageView.image = [UIImage imageWithData:response];
                          }];
    
    [[SVHTTPClient sharedClient] GET:@"users/show.json"
                          parameters:[NSDictionary dictionaryWithObject:@"samvermette" forKey:@"screen_name"]
                          completion:^(id response, NSHTTPURLResponse *urlResponse, NSError *error) {
                              followersLabel.text = [NSString stringWithFormat:@"@samvermette has %@ followers", [response valueForKey:@"followers_count"]];
                          }];
}

- (IBAction)progressRequest {
    
    progressLabel.text = nil;
    
    [SVHTTPRequest GET:@"http://sanjosetransit.com/extras/SJTransit_Icons.zip" 
            parameters:nil 
            saveToPath:@"/Volumes/Data/test2.zip" 
              progress:^(float progress) {
                  progressLabel.text = [NSString stringWithFormat:@"Downloading (%.0f%%)", progress*100];
              } 
            completion:^(id response, NSHTTPURLResponse *urlResponse, NSError *error) {
                progressLabel.text = @"Download complete";
            }];
}


@end
