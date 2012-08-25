//
//  AppDelegate.m
//  MacDemo
//
//  Created by Sam Vermette on 09.03.12.
//  Copyright (c) 2012 Home. All rights reserved.
//

#import "AppDelegate.h"

#import "SVHTTPRequest.h"

@implementation AppDelegate

@synthesize window = _window;

- (IBAction)watchersRequest:(id)sender {
    
    [watchersLabel setStringValue:@""];

    [SVHTTPRequest GET:@"https://api.github.com/repos/samvermette/SVHTTPRequest"
            parameters:nil
            completion:^(id response, NSHTTPURLResponse *urlResponse, NSError *error) {
                [watchersLabel setStringValue:[NSString stringWithFormat:@"SVHTTPRequest has %@ watchers", [response valueForKey:@"watchers"]]];
            }];
}

- (IBAction)twitterRequest:(id)sender {
    
    [followersLabel setStringValue:@""];
    
    [[SVHTTPClient sharedClient] setBasePath:@"http://api.twitter.com/1/"];
    
    [[SVHTTPClient sharedClient] GET:@"users/profile_image"
                          parameters:[NSDictionary dictionaryWithObjectsAndKeys:
                                      @"samvermette", @"screen_name",
                                      @"original", @"size",
                                      nil]
                          completion:^(id response, NSHTTPURLResponse *urlResponse, NSError *error) {
                              imageCell.image = [[NSImage alloc] initWithData:response]; 
                          }];
    
    [[SVHTTPClient sharedClient] GET:@"users/show.json"
                          parameters:[NSDictionary dictionaryWithObject:@"samvermette" forKey:@"screen_name"]
                          completion:^(id response, NSHTTPURLResponse *urlResponse, NSError *error) {
                              [followersLabel setStringValue:[NSString stringWithFormat:@"@samvermette has %@ followers", [response valueForKey:@"followers_count"]]];
                          }];
}

- (IBAction)progressRequest:(id)sender {
    
    [progressLabel setStringValue:@""];
    
    [SVHTTPRequest GET:@"http://sanjosetransit.com/extras/SJTransit_Icons.zip" 
            parameters:nil 
            saveToPath:@"/Volumes/Data/test2.zip" 
              progress:^(float progress) {
                  [progressIndicator setDoubleValue:progress*100];
              } 
            completion:^(id response, NSHTTPURLResponse *urlResponse, NSError *error) {
                [progressLabel setStringValue:@"Download complete"];
            }];
}

@end
