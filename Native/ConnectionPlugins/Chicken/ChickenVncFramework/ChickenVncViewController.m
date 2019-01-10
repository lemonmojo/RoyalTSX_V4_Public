//
//  ChickenVncViewController.m
//  Chicken
//
//  Created by Felix Deimel on 23.10.12.
//
//

#import "ChickenVncViewController.h"
#import "ServerStandAlone.h"
#import "Session.h"
#import "RFBConnection.h"
#import "RFBView.h"
#import "Profile.h"

NSObject* getViewControllerForRoyalTsxPlugin(NSObject<RoyalTsxManagedConnectionControllerProtocol> *parentController, NSWindow *mainWindow) {
    return [[ChickenVncViewController alloc] initWithParentController:parentController andMainWindow:mainWindow];
}

@implementation ChickenVncViewController

@synthesize
sessionView,
vncSession,
parentController,
pasteboardMonitor;

- (id<RoyalTsxNativeConnectionControllerProtocol>)initWithParentController:(id<RoyalTsxManagedConnectionControllerProtocol>)parent andMainWindow:(NSWindow*)window {
    if (![super init])
		return nil;
    
    parentController = parent;
    mainWindow = window;
    
	return self;
}

- (void)dealloc {
    m_released = YES;
    
    NSLog(@"ChickenVNC: Dealloc");
    
    if (sessionView) {
        // INFO: release is now done in managed code if required
        //[sessionView release];
        sessionView = nil;
    }
    
    if (waiter) {
        [waiter release];
        waiter = nil;
    }
    
    if (self.pasteboardMonitor) {
        self.pasteboardMonitor.delegate = nil;
        [self.pasteboardMonitor release]; self.pasteboardMonitor = nil;
    }
    
	[super dealloc];
}

- (RFBConnection*)connection
{
    if (!vncSession) {
        return nil;
    }
    
    return vncSession.theConnection;
}

- (void)connectionStatusChanged:(rtsConnectionStatus)newStatus {
    [self connectionStatusChanged:newStatus
                       andMessage:@""];
}

- (void)connectionStatusChanged:(rtsConnectionStatus)newStatus andMessage:(NSString*)message {
    [self connectionStatusChanged:newStatus
                       andMessage:message
                   andErrorNumber:0];
}

- (void)connectionStatusChanged:(rtsConnectionStatus)newStatus andMessage:(NSString*)message andErrorNumber:(int)errorNumber {
    ConnectionStatusArguments *args = [ConnectionStatusArguments argumentsWithStatus:newStatus
                                                                         errorNumber:errorNumber
                                                                     andErrorMessage:message];

    //NSLog(@"err msg: %@", args.errorMessage);
    
    if (newStatus == rtsConnectionConnected) {
        [self.pasteboardMonitor start];
    } else if (newStatus == rtsConnectionClosed) {
        [self.pasteboardMonitor stop];
    }
    
    if (newStatus != rtsConnectionClosed) {
        if (parentController) {
            [parentController performSelectorOnMainThread:@selector(sessionStatusChanged:) withObject:args waitUntilDone:NO];
        }
    } else {
        if (parentController) {
            [parentController performSelectorOnMainThread:@selector(sessionStatusChanged:) withObject:args waitUntilDone:YES];
        }
    }
}

- (void)connectWithOptions:(NSDictionary *)options {
    ServerStandAlone* server = [[[ServerStandAlone alloc] init] autorelease];
    
    server.host = [options objectForKey:@"Hostname"];
    server.port = [[options objectForKey:@"Port"] intValue];
    server.password = [options objectForKey:@"Password"];
    server.viewOnly = [[options objectForKey:@"ViewOnly"] boolValue];
    server.scaling = [[options objectForKey:@"Scaling"] boolValue];
    server.shared = [[options objectForKey:@"SharedConnection"] boolValue];
    
    if ([[options objectForKey:@"SshTunnelEnabled"] boolValue] &&
        [options objectForKey:@"SshTunnelHost"] &&
        ![[options objectForKey:@"SshTunnelHost"] isEqualToString:@""])
        [server setSshString:[options objectForKey:@"SshTunnelHost"]];
    
    Profile *profile = [[[Profile alloc] init] autorelease];
    [profile setPixelFormatIndex:[[options objectForKey:@"LimitTo256Colors"] boolValue] ? 1 : 0];
    [profile setCopyRectEnabled:[[options objectForKey:@"EnableCopyRectEncoding"] boolValue]];
    [profile setJpegEncodingEnabled:[[options objectForKey:@"EnableJpegEncoding"] boolValue]];
    [profile setKeyboardMode:[[options objectForKey:@"KeyboardMode"] intValue]];
    
    server.profile = profile;
    
    [self connectionStatusChanged:rtsConnectionConnecting];
    waiter = [[ConnectionWaiter waiterForServer:server delegate:self window:nil] retain];
}

- (void)disconnect {
    NSLog(@"ChickenVNC: Disconnecting");
    
    if (vncSession) {
        [vncSession terminateConnection:nil];
    } else if (waiter) {
        [waiter cancel];
        [self connectionStatusChanged:rtsConnectionClosed];
    }
}

- (void)focusSession {
    if (sessionView != nil) {
        [[sessionView window] makeFirstResponder:sessionView];
    }
}

- (void)refreshScreen {
    if (vncSession)
        [vncSession requestFrameBufferUpdate:self];
}

- (NSImage*)getScreenshot {
    if (!sessionView ||
        ![(NSScrollView*)sessionView documentView]) {
        return nil;
    }
    
    NSView *v = [(NSScrollView*)sessionView documentView];
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSBitmapImageRep *imageRep = [v bitmapImageRepForCachingDisplayInRect:[v bounds]];
    [v cacheDisplayInRect:[v bounds] toBitmapImageRep:imageRep];
    
    NSImage *image = [[NSImage alloc] initWithSize:v.bounds.size];
    [image addRepresentation:imageRep];
    
    [pool release];
    
    return [image autorelease];
}

- (void)sendKeys:(NSString*)keys {
    if (vncSession) {
        if ([keys isEqualToString:@"CmdOptEsc"])
             [vncSession sendCmdOptEsc:self];
        else if ([keys isEqualToString:@"CtrlAltDel"])
            [vncSession sendCtrlAltDel:self];
        else if ([keys isEqualToString:@"Insert"])
            [vncSession sendInsertKeyCode:self];
        else if ([keys isEqualToString:@"Delete"])
            [vncSession sendDeleteKeyCode:self];
        else if ([keys isEqualToString:@"Pause"])
            [vncSession sendPauseKeyCode:self];
        else if ([keys isEqualToString:@"Break"])
            [vncSession sendBreakKeyCode:self];
        else if ([keys isEqualToString:@"Print"])
            [vncSession sendPrintKeyCode:self];
        else if ([keys isEqualToString:@"Execute"])
            [vncSession sendExecuteKeyCode:self];
    }
}

- (void)sendKeyCode:(unsigned short)keyCode characters:(NSString*)characters down:(BOOL)down
{
    if (m_released) {
        return;
    }
    
    NSEvent *ev = [NSEvent keyEventWithType:down ? NSEventTypeKeyDown : NSEventTypeKeyUp
                                   location:NSZeroPoint
                              modifierFlags:0
                                  timestamp:0
                               windowNumber:0
                                    context:nil
                                 characters:characters
                charactersIgnoringModifiers:characters
                                  isARepeat:NO
                                    keyCode:keyCode];
    
    if (down) {
        [self performSelectorOnMainThread:@selector(sendKeyDownEvent:) withObject:ev waitUntilDone:YES];
    } else {
        [self performSelectorOnMainThread:@selector(sendKeyUpEvent:) withObject:ev waitUntilDone:YES];
    }
}

- (void)sendKeyDownEvent:(NSEvent*)ev
{
    if (m_released ||
        !self.vncSession.theView) {
        return;
    }
    
    [self.vncSession.theView keyDown:ev];
}

- (void)sendKeyUpEvent:(NSEvent*)ev
{
    if (m_released ||
        !self.vncSession.theView) {
        return;
    }
    
    [self.vncSession.theView keyUp:ev];
}

- (void)sendModifierFlags:(NSEventModifierFlags)modifierFlags
{
    if (m_released) {
        return;
    }
    
    NSEvent *ev = [NSEvent keyEventWithType:NSEventTypeFlagsChanged
                                   location:NSZeroPoint
                              modifierFlags:modifierFlags
                                  timestamp:0
                               windowNumber:0
                                    context:nil
                                 characters:@""
                charactersIgnoringModifiers:@""
                                  isARepeat:NO
                                    keyCode:0];
    
    [self performSelectorOnMainThread:@selector(sendModifierEvent:) withObject:ev waitUntilDone:YES];
}

- (void)sendModifierEvent:(NSEvent*)ev
{
    if (m_released ||
        !self.vncSession.theView) {
        return;
    }
    
    [self.vncSession.theView flagsChanged:ev];
}

- (void)pasteToServer {
    if (vncSession) {
        [vncSession paste:self];
    }
}

- (void)sendPasteboardContentsToServer {
    if (vncSession) {
        [vncSession sendPasteboardToServer:self automaticallyAllowingLossyConversion:YES];
    }
}

- (NSSize)contentSize {
    if (vncSession)
        return vncSession.contentSize;
    
    return NSMakeSize(0, 0);
}

// ConnectionWaiterDelegate
- (void)connectionSucceeded: (RFBConnection *)conn {
    NSLog(@"ChickenVNC: Connection Success");
    
    vncSession = [[Session alloc] initWithConnection:conn andDelegate:self andMainWindow:mainWindow];
    //vncSession.scrollView.backgroundColor = [NSColor controlColor];
    vncSession.scrollView.drawsBackground = NO;
    vncSession.scrollView.scrollerStyle = NSScrollerStyleLegacy;
    vncSession.scrollView.verticalScrollElasticity = NSScrollElasticityNone;
    vncSession.scrollView.horizontalScrollElasticity = NSScrollElasticityNone;
    vncSession.scrollView.hasVerticalScroller = !conn.scaling;
    vncSession.scrollView.hasHorizontalScroller = !conn.scaling;
    [vncSession.scrollView.verticalScroller setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
    [vncSession.scrollView.horizontalScroller setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
    
    /* NSView *view = vncSession.scrollView.documentView;
    [vncSession.scrollView.documentView removeFromSuperview];
    
    //vncSession.scrollView.contentView = [[CenteringClipView alloc] initWithFrame:view.frame];
    vncSession.scrollView.documentView = view;
    vncSession.scrollView.backgroundColor = [NSColor lightGrayColor];
    
    [RmCenteringClipView replaceClipViewInScrollView:vncSession.scrollView]; */
    
    sessionView = vncSession.scrollView;
    [vncSession.scrollView.window orderOut:self];
    [vncSession.scrollView.window close];
    
    LMPasteboardMonitor* pm = [[LMPasteboardMonitor alloc] initWithPasteboardTypes:@[ NSPasteboardTypeString ]];
    pm.delegate = self;
    self.pasteboardMonitor = pm;
    
    [self connectionStatusChanged:rtsConnectionConnected];
}

- (void)pasteboardDidUpdateWithMatchingType:(LMPasteboardMonitor *)pasteboardMonitor
{
    NSLog(@"ChickenVNC: Local clipboard updated. Sending to remote server...");
    
    [self sendPasteboardContentsToServer];
}

- (void)connectionFailed {
    NSLog(@"ChickenVNC: Connection Failed");
    [self connectionStatusChanged:rtsConnectionClosed];
}

- (void)connectionFailedWithError :(NSString *)aError andMessage :(NSString *)aMessage {
    NSLog(@"ChickenVNC: Connection Failed");
    [self connectionStatusChanged:rtsConnectionClosed andMessage:aMessage];
}

- (void)serverClosedWithMessage:(NSString*)aMessage {
    NSLog(@"ChickenVNC: Closed with Message");
    [self connectionStatusChanged:rtsConnectionClosed andMessage:aMessage];
}

- (void)serverClosed {
    NSLog(@"ChickenVNC: Closed");
    [self connectionStatusChanged:rtsConnectionClosed];
}

- (void)authenticationFailed:(NSString*)aMessage {
    NSLog(@"ChickenVNC: Authentication Failed");
    [self connectionStatusChanged:rtsConnectionClosed andMessage:nil andErrorNumber:10001];
}

- (void)sessionResized {
    if (parentController) {
        [parentController performSelectorOnMainThread:@selector(sessionResized) withObject:nil waitUntilDone:NO];
    }
}

- (NSArray*)performARDAuthWithPrime:(NSData*)prime generator:(NSData*)generator peerKey:(NSData*)peerKey keyLength:(NSNumber*)keyLength {
    if (parentController && [parentController respondsToSelector:@selector(performARDAuthWithPrime:generator:peerKey:keyLength:)]) {
        NSArray *ret = [parentController performARDAuthWithPrime:prime
                                                       generator:generator
                                                         peerKey:peerKey
                                                       keyLength:keyLength];
        
        return ret;
    }
    
    return nil;
}

- (NSArray*)performMSLogon2AuthWithGenerator:(NSData*)generator mod:(NSData*)mod resp:(NSData*)resp {
    if (parentController && [parentController respondsToSelector:@selector(performMSLogon2AuthWithGenerator:mod:resp:)]) {
        NSArray *ret = [parentController performMSLogon2AuthWithGenerator:generator
                                                                      mod:mod
                                                                     resp:resp];
        
        return ret;
    }
    
    return nil;
}

@end
