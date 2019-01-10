#import <Cocoa/Cocoa.h>

/**
 * A view that draws a zoomed-in grid of pixels.
 */
@interface CPKEyedropperView : NSView

/** An array of arrays. The inner arrays have NSColor. This defines a grid to draw. */
@property(nonatomic) NSArray *colors;

/** Called on click. */
@property(nonatomic, copy) void (^click)(void);

/** Called when a key is pressed to cancel picking. */
@property(nonatomic, copy) void (^cancel)(void);

@end
