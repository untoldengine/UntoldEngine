//
//  AppDelegate.m
//  Untold4D macOS
//
//  Created by Harold Serrano on 2/6/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#import "AppDelegate.h"
#import "GameViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
//    //get the game view controller reference
//    GameViewController *gameViewController = (GameViewController *)[[NSApplication sharedApplication] mainWindow].contentViewController;
//
//    //make the game view controller the first responder so it can receive keyboard inputs
//    [[[NSApplication sharedApplication] mainWindow] makeFirstResponder:gameViewController];
//
//    [[[NSApplication sharedApplication] mainWindow] center];
    
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}


@end
