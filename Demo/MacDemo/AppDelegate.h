//
//  AppDelegate.h
//  MacDemo
//
//  Created by Sam Vermette on 09.03.12.
//  Copyright (c) 2012 Home. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSTextField *watchersLabel, *followersLabel, *progressLabel;
    IBOutlet NSImageCell *imageCell;
    IBOutlet NSProgressIndicator *progressIndicator;
}

@property (weak) IBOutlet NSWindow *window;

- (IBAction)watchersRequest:(id)sender;
- (IBAction)twitterRequest:(id)sender;
- (IBAction)progressRequest:(id)sender;

@end
