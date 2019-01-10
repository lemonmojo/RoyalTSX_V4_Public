//
//  AppDelegate.h
//  ChickenTester
//
//  Created by Felix Deimel on 23.10.12.
//  Copyright (c) 2012 Lemon Mojo. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FxView.h"
#import "RoyalTsxManagedConnectionControllerProtocol.h"

@interface TesterAppDelegate : NSObject <NSApplicationDelegate, RoyalTsxManagedConnectionControllerProtocol> {
    IBOutlet NSWindow *window;
    NSTextField *textFieldHostname;
    NSTextField *textFieldPort;
    NSSecureTextField *textFieldPassword;
    FxView *viewSession;
    NSTextField *textFieldStatus;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextField *textFieldHostname;
@property (assign) IBOutlet NSTextField *textFieldPort;
@property (assign) IBOutlet NSSecureTextField *textFieldPassword;
@property (assign) IBOutlet NSView *viewSession;
@property (assign) IBOutlet NSTextField *textFieldStatus;
@property (assign) IBOutlet NSButton *buttonConnect;
- (IBAction)buttonConnect_Action:(id)sender;

@end
