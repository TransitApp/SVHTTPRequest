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
    
    [SVHTTPRequest GET:@"http://github.com/api/v2/json/repos/show/samvermette/SVProgressHUD"
            parameters:nil
            completion:^(NSObject *response) {
                NSLog(@"%@", response);
                watchersLabel.text = [NSString stringWithFormat:@"SVHTTPRequest has %@ watchers", [[response valueForKey:@"repository"] valueForKey:@"watchers"]];
            }];
}

- (IBAction)twitterRequest {
    
    twitterImageView.image = nil;
    followersLabel.text = nil;
    
    [SVHTTPRequest GET:@"http://img.tweetimag.es/i/samvermette_o"
            parameters:nil
            completion:^(NSObject *response) {
                twitterImageView.image = [UIImage imageWithData:(NSData*)response];
            }];
    
    [SVHTTPRequest GET:@"http://api.twitter.com/1/users/show.json"
            parameters:[NSDictionary dictionaryWithObject:@"samvermette" forKey:@"screen_name"]
            completion:^(NSObject *response) {
                NSLog(@"%@", response);
                followersLabel.text = [NSString stringWithFormat:@"@samvermette has %@ followers", [response valueForKey:@"followers_count"]];
            }];
}


@end
