#import "LMCenteredClipView.h"

@implementation LMCenteredClipView

- (NSRect)constrainBoundsRect:(NSRect)proposedBounds
{
    NSRect rect = [super constrainBoundsRect:proposedBounds];
    
    NSView* containerView = self.documentView;
    
    if (containerView) {
        if (rect.size.width > containerView.frame.size.width) {
            rect.origin.x = (containerView.frame.size.width - rect.size.width) / 2;
        }
        
        if(rect.size.height > containerView.frame.size.height) {
            rect.origin.y = (containerView.frame.size.height - rect.size.height) / 2;
        }
    }
    
    return rect;
}

@end
