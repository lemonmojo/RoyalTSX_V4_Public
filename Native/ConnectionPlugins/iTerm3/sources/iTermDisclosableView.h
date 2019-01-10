//
//  iTermDisclosableView.h
//  iTerm2
//
//  Created by George Nachman on 11/29/16.
//
//

#import <Cocoa/Cocoa.h>

@interface iTermDisclosableView : NSView

@property (nonatomic, copy) void (^requestLayout)(void);
@property (nonatomic, readonly) NSTextView *textView;

- (instancetype)initWithFrame:(NSRect)frameRect prompt:(NSString *)prompt message:(NSString *)message;

@end
