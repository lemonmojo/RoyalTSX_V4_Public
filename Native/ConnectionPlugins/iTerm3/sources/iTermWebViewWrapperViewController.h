//
//  iTermWebViewWrapperView.h
//  iTerm2
//
//  Created by George Nachman on 11/3/15.
//
//

#import <Cocoa/Cocoa.h>
@class WKWebView;

@interface iTermWebViewWrapperViewController : NSViewController

- (instancetype)initWithWebView:(WKWebView *)webView backupURL:(NSURL *)backupURL;

- (void)terminateWebView;

@end

// Because every WKWebView you create and place in a popover is immortal, I keep a pool of them
// around and reuse them so you generally never have more than one allocated at a time.
@interface iTermWebViewFactory : NSObject
+ (instancetype)sharedInstance;
- (WKWebView *)webView;
@end
