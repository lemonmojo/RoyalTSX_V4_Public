//
//  NSScreen+iTerm.m
//  iTerm
//
//  Created by George Nachman on 6/28/14.
//
//

#import "NSScreen+iTerm.h"

@implementation NSScreen (iTerm)

- (BOOL)containsCursor {
    NSRect frame = [self frame];
    NSPoint cursor = [NSEvent mouseLocation];
    return NSPointInRect(cursor, frame);
}

+ (NSScreen *)screenWithCursor {
    for (NSScreen *screen in [self screens]) {
        if ([screen containsCursor]) {
            return screen;
        }
    }
    return [self mainScreen];
}

- (NSRect)visibleFrameIgnoringHiddenDock {
  NSRect visibleFrame = [self visibleFrame];
  NSRect actualFrame = [self frame];

  CGFloat visibleLeft = CGRectGetMinX(visibleFrame);
  CGFloat visibleRight = CGRectGetMaxX(visibleFrame);
  CGFloat visibleBottom = CGRectGetMinY(visibleFrame);

  CGFloat actualLeft = CGRectGetMinX(actualFrame);
  CGFloat actualRight = CGRectGetMaxX(actualFrame);
  CGFloat actualBottom = CGRectGetMinY(actualFrame);

  CGFloat leftInset = fabs(visibleLeft - actualLeft);
  CGFloat rightInset = fabs(visibleRight - actualRight);
  CGFloat bottomInset = fabs(visibleBottom - actualBottom);

  NSRect visibleFrameIgnoringHiddenDock = visibleFrame;
  const CGFloat kHiddenDockSize = 4;
  if (leftInset == kHiddenDockSize) {
    visibleFrameIgnoringHiddenDock.origin.x -= kHiddenDockSize;
    visibleFrameIgnoringHiddenDock.size.width += kHiddenDockSize;
  } else if (rightInset == kHiddenDockSize) {
    visibleFrameIgnoringHiddenDock.size.width += kHiddenDockSize;
  } else if (bottomInset == kHiddenDockSize) {
    visibleFrameIgnoringHiddenDock.origin.y -= kHiddenDockSize;
    visibleFrameIgnoringHiddenDock.size.height += kHiddenDockSize;
  }

  return visibleFrameIgnoringHiddenDock;
}

- (NSRect)frameExceptMenuBar {
    if ([[NSScreen screens] firstObject] == self) {
        NSRect frame = self.frame;
        // NSApp.mainMenu.menuBarHeight returns 0 when there's a Lion
        // fullscreen window in another display. I guess it will probably
        // always be 22 :)
        frame.size.height -= 22;
        return frame;
    } else {
        return self.frame;
    }
}

@end
