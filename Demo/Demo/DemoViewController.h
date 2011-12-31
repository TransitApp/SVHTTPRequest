//
//  DemoViewController.h
//  Demo
//
//  Created by Sam Vermette on 20.09.11.
//  Copyright 2011 samvermette.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DemoViewController : UIViewController {
    IBOutlet UIImageView *twitterImageView;
    IBOutlet UILabel *watchersLabel, *followersLabel, *downloadLabel;
    IBOutlet UIProgressView *progressIndicator;
}

- (IBAction)watchersRequest;
- (IBAction)twitterRequest;
- (IBAction)downloadRequest;

@end
