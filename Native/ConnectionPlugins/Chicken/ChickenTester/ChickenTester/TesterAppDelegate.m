//
//  AppDelegate.m
//  ChickenTester
//
//  Created by Felix Deimel on 23.10.12.
//  Copyright (c) 2012 Lemon Mojo. All rights reserved.
//
//  An application to test ChickenVncFramework
//

#import "TesterAppDelegate.h"
#import "ConnectionStatusArguments.h"
#import "ChickenVncViewController.h"

@implementation TesterAppDelegate

@synthesize window;
@synthesize textFieldHostname;
@synthesize textFieldPort;
@synthesize textFieldPassword;
@synthesize viewSession;
@synthesize textFieldStatus;

ChickenVncViewController *ctrl;
rtsConnectionStatus status;

- (void)dealloc {
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    status = rtsConnectionClosed;
}

- (void)awakeFromNib {
    viewSession.delegate = self;
}

- (IBAction)buttonConnect_Action:(id)sender {
    [self connectOrDisconnect];
}

- (void)connectOrDisconnect {
    if (!ctrl) {
        ctrl = (ChickenVncViewController*)getViewControllerForRoyalTsxPlugin(self, self.window);
    }
    
    if (status == rtsConnectionClosed) {
        [self connect];
    } else {
        [self disconnect];
    }
}

- (void)connect {
    NSMutableDictionary *opts = [NSMutableDictionary dictionary];
    opts[@"Hostname"] = textFieldHostname.stringValue;
    opts[@"Port"] = [NSNumber numberWithInt:textFieldPort.intValue];
    opts[@"Password"] = textFieldPassword.stringValue;
    opts[@"ViewOnly"] = [NSNumber numberWithBool:NO];
    opts[@"SharedConnection"] = [NSNumber numberWithBool:NO];
    opts[@"LimitTo256Colors"] = [NSNumber numberWithBool:NO];
    opts[@"EnableCopyRectEncoding"] = [NSNumber numberWithBool:NO];
    opts[@"EnableJpegEncoding"] = [NSNumber numberWithBool:NO];
    opts[@"SshTunnelEnabled"] = [NSNumber numberWithBool:NO];
    opts[@"SshTunnelHost"] = @"";
    opts[@"KeyboardMode"] = [NSNumber numberWithInt:1];
    opts[@"Scaling"] = [NSNumber numberWithBool:YES];
    
    [ctrl connectWithOptions:[[opts copy] autorelease]];
}

- (void)disconnect {
    [ctrl disconnect];
}

- (void)sessionStatusChanged:(ConnectionStatusArguments*)args {
    status = args.status;
    
    if (status == rtsConnectionConnecting) {
        textFieldStatus.stringValue = @"Connecting";
        self.buttonConnect.enabled = NO;
    } else if (status == rtsConnectionConnected) {
        textFieldStatus.stringValue = @"Connected";
        self.buttonConnect.title = @"Disconnect";
        self.buttonConnect.enabled = YES;
        
        ctrl.sessionView.frame = self.viewSession.frame;
        ctrl.sessionView.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin | NSViewWidthSizable | NSViewHeightSizable;
        
        //[ctrl.sessionView scaleUnitSquareToSize:NSMakeSize(0.5, 0.5)];
        
        [self.viewSession addSubview:ctrl.sessionView];
        
        /* [(NSScrollView*)ctrl.sessionView setHasHorizontalScroller:NO];
        [(NSScrollView*)ctrl.sessionView setHasVerticalScroller:NO]; */
        
        //[self.viewSession setBounds:NSMakeRect(0, 0, 500, 500)];
        
        [ctrl focusSession];
    } else if (status == rtsConnectionDisconnecting) {
        textFieldStatus.stringValue = @"Disconnecting";
        self.buttonConnect.enabled = NO;
    } else if (status == rtsConnectionClosed) {
        textFieldStatus.stringValue = @"Closed";
        self.buttonConnect.title = @"Connect";
        self.buttonConnect.enabled = YES;
        [ctrl.sessionView removeFromSuperview];
        
        [ctrl release]; ctrl = nil;
        
        NSAlert *alert = [NSAlert alertWithMessageText:@"Connection closed"
                                         defaultButton:@"OK"
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:args.errorMessage];
        [alert runModal];
    }
}

- (void)viewDidEndLiveResize {
    [self sessionResized];
}

- (void)sessionResized {
    /* NSScrollView* scrollView = (NSScrollView*)ctrl.sessionView;
    
    NSSize contentSize = [ctrl contentSize];
    NSSize containerSize = self.viewSession.frame.size;
    
    NSSize scale = NSMakeSize(containerSize.width / contentSize.width,
                              containerSize.height / contentSize.height);
    
    [scrollView scaleUnitSquareToSize:scale];
    [scrollView setNeedsDisplay:YES];
    [scrollView setHasHorizontalScroller:NO];
    [scrollView setHasVerticalScroller:NO]; */
}

@end
