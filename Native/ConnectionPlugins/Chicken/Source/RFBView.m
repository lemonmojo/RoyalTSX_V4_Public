/* Copyright (C) 1998-2000  Helmut Maierhofer <helmut.maierhofer@chello.at>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#import "RFBView.h"
#import "EventFilter.h"
#import "RFBConnection.h"
#import "FrameBuffer.h"
#import "Profile.h"
#import <Carbon/Carbon.h>
//#import "RectangleList.h"

@implementation RFBView

// FX EDIT
- (void)viewDidMoveToSuperview
{
    NSScrollView* scrollView = self.enclosingScrollView;
    
    if (!scrollView) {
        return;
    }
    
    scrollView.minMagnification = 0.01;
    scrollView.maxMagnification = 1.0;
    
    scrollView.postsFrameChangedNotifications = YES;
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(scrollViewFrameDidChange:)
                                               name:NSViewFrameDidChangeNotification
                                             object:scrollView];
    
    [self updateMagnification];
}

- (void)scrollViewFrameDidChange:(NSNotification*)notification
{
    [self updateMagnification];
}

// FX EDIT
- (void)updateMagnification
{
    NSScrollView* scrollView = self.enclosingScrollView;
    
    if (!self.scaling ||
        !fbuf ||
        !scrollView) {
        return;
    }
    
    [scrollView magnifyToFitRect:NSMakeRect(0, 0, fbuf.size.width, fbuf.size.height)];
    
    //[scrollView scrollClipView:scrollView.contentView toPoint:NSZeroPoint];
    [scrollView reflectScrolledClipView:scrollView.contentView];
}

// FX Edit
- (BOOL)becomeFirstResponder
{
    if (self.window &&
        self.window.isKeyWindow) {
        [self registerHotKeys];
    }
    
    return YES;
}

- (BOOL)resignFirstResponder
{
    [self deregisterHotKeys];
    
    return YES;
}

- (void)registerHotKeys
{
    if (self.keyboardMode >= 3) {
        oldHotKeyMode = PushSymbolicHotKeyMode(kHIHotKeyModeAllDisabled);
    }
}

- (void)deregisterHotKeys
{
    if (oldHotKeyMode || self.keyboardMode >= 3) {
        PopSymbolicHotKeyMode(oldHotKeyMode);
    }
}
// END FX Edit

/* One-time initializer to read the cursors into memory. */
+ (NSCursor *)_cursorForName: (NSString *)name
{
	static NSDictionary *sMapping = nil;
	if ( ! sMapping )
	{
		NSBundle *mainBundle = ChickenVncFrameworkBundle();
		NSDictionary *entries = [NSDictionary dictionaryWithContentsOfFile: [mainBundle pathForResource: @"cursors" ofType: @"plist"]];
		NSParameterAssert( entries != nil );
		sMapping = [[NSMutableDictionary alloc] init];
		NSEnumerator *cursorNameEnumerator = [entries keyEnumerator];
		NSDictionary *cursorName;
		
		while ( cursorName = [cursorNameEnumerator nextObject] )
		{
			NSDictionary *cursorEntry = [entries objectForKey: cursorName];
			NSString *localPath = [cursorEntry objectForKey: @"localPath"];
			NSString *path = [mainBundle pathForResource: localPath ofType: nil];
			NSImage *image = [[NSImage alloc] initWithContentsOfFile: path];
			
			int hotspotX = [[cursorEntry objectForKey: @"hotspotX"] intValue];
			int hotspotY = [[cursorEntry objectForKey: @"hotspotY"] intValue];
			NSPoint hotspot = {hotspotX, hotspotY};
			
			NSCursor *cursor = [[NSCursor alloc] initWithImage: image hotSpot: hotspot];
			[(NSMutableDictionary *)sMapping setObject: cursor forKey: cursorName];
            [cursor release];
            [image release];
		}
	}
	
	return [sMapping objectForKey: name];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
    return NO;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)setFrameBuffer:(id)aBuffer;
{
    NSRect f = [self frame];
    
    if (fbuf) {
        [fbuf release];
        fbuf = nil;
    }
    
    if (aBuffer) {
        fbuf = [aBuffer retain];
        f.size = [aBuffer size];
    }
    
    //_image = [[NSImage alloc] initWithSize:f.size];
    
    // FX EDIT
    //[self setFrame:f];
    [self performSelectorOnMainThread:@selector(setFrameOnMainThreadAndUpdateMagnification:) withObject:[NSValue valueWithRect:f] waitUntilDone:NO];
}

- (void)setFrameOnMainThreadAndUpdateMagnification:(NSValue*)frameValue
{
    self.frame = frameValue.rectValue;
    
    // FX EDIT
    [self updateMagnification];
}

- (void)dealloc
{
    if (fbuf) {
        [fbuf release];
        fbuf = nil;
    }
    
    if (_serverCursor) {
        [_serverCursor release];
        _serverCursor = nil;
    }
    
    if (_modifierCursor) {
        [_modifierCursor release];
        _modifierCursor = nil;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // FX Edit
    [self deregisterHotKeys];
    
    [super dealloc];
}

- (void)setCursorTo: (NSString *)name
{
    [_modifierCursor release];
	if (name == nil)
        _modifierCursor = nil;
    else
        _modifierCursor = [[[self class] _cursorForName: name] retain];
    [[self window] invalidateCursorRectsForView: self];
}

- (void)setServerCursorTo: (NSCursor *)aCursor
{
    [_serverCursor release];
    _serverCursor = [aCursor retain];
    if (!_modifierCursor)
        [[self window] invalidateCursorRectsForView: self];
}

- (void)setTint: (NSColor *)aTint
{
    if (![tint isEqual:aTint]) {
        [tint release];
        tint = [aTint retain];
        drawTint = [tint alphaComponent] != 0.0;
        [self setNeedsDisplay:YES];
    }
}

- (void)setDelegate:(RFBConnection *)delegate
{
    _delegate = delegate;
	_eventFilter = [_delegate eventFilter];
	[self setCursorTo: nil];
	[self setPostsFrameChangedNotifications: YES];
	[[NSNotificationCenter defaultCenter] addObserver: _delegate selector: @selector(viewFrameDidChange:) name: NSViewFrameDidChangeNotification object: self];
    
    // FX Edit
    if (self.isFirstResponder &&
        self.window &&
        self.window.isKeyWindow) {
        [self registerHotKeys];
    }
}

- (RFBConnection *)delegate
{
	return _delegate;
}

- (void)drawRect:(NSRect)destRect
{
    NSRect          b = [self bounds];
    const NSRect    *rects;
    NSInteger       numRects;
    int             i;
    
    if (drawTint)
        [tint setFill];
    
    [self getRectsBeingDrawn:&rects count:&numRects];
    for (i = 0; i < numRects; i++) {
        NSRect      r = rects[i];
        r.origin.y = b.size.height - NSMaxY(r);
        [fbuf drawRect:r at:rects[i].origin];
        if (drawTint)
            NSRectFillUsingOperation(rects[i], NSCompositeSourceOver);
    }
}

/* Called by system to set-up cursors for this view */
- (void)resetCursorRects
{
    // FX Edit
    /* float scale = 1.0f;
    float scaleX = 1.0f;
    float scaleY = 1.0f;
    
    NSRect viewRect = self.superview.bounds;
    
    if (viewRect.size.width < fbuf.size.width) {
        scaleX = viewRect.size.width / fbuf.size.width;
    }
    
    if (viewRect.size.height < fbuf.size.height) {
        scaleY = viewRect.size.height / fbuf.size.height;
    }
    
    if (scaleX < scaleY) {
        scale = scaleX;
    } else {
        scale = scaleY;
    }
    
    float scaleRounded = [[NSString stringWithFormat:@"%.2f", scale] floatValue];
    
    NSLog(@"scale: %f", scaleRounded);
    
    [self zoomToActualSize:self];
    [self zoomViewByFactor:scaleRounded]; */
    
    if ([_delegate viewOnly])
        return;

    NSRect cursorRect;
    cursorRect = [self visibleRect];
    if (_modifierCursor)
        [self addCursorRect: cursorRect cursor: _modifierCursor];
    else if (_serverCursor)
        [self addCursorRect: cursorRect cursor: _serverCursor];
    else
        [self addCursorRect: cursorRect cursor: [[self class] _cursorForName: @"rfbCursor"]];
}

- (void)mouseDown:(NSEvent *)theEvent
{  [_eventFilter mouseDown: theEvent];  }

- (void)rightMouseDown:(NSEvent *)theEvent
{  [_eventFilter rightMouseDown: theEvent];  }

- (void)otherMouseDown:(NSEvent *)theEvent
{  [_eventFilter otherMouseDown: theEvent];  }

- (void)mouseUp:(NSEvent *)theEvent
{  [_eventFilter mouseUp: theEvent];  }

- (void)rightMouseUp:(NSEvent *)theEvent
{  [_eventFilter rightMouseUp: theEvent];  }

- (void)otherMouseUp:(NSEvent *)theEvent
{  [_eventFilter otherMouseUp: theEvent];  }

- (void)mouseEntered:(NSEvent *)theEvent
{  [[self window] setAcceptsMouseMovedEvents: YES];  }

- (void)mouseExited:(NSEvent *)theEvent
{  [[self window] setAcceptsMouseMovedEvents: NO];  }

- (void)mouseMoved:(NSEvent *)theEvent
{  [_eventFilter mouseMoved: theEvent];  }

- (void)mouseDragged:(NSEvent *)theEvent
{  [_eventFilter mouseDragged: theEvent];
   [_delegate mouseDragged: theEvent];}

- (void)rightMouseDragged:(NSEvent *)theEvent
{  [_eventFilter rightMouseDragged: theEvent];  }

- (void)otherMouseDragged:(NSEvent *)theEvent
{  [_eventFilter otherMouseDragged: theEvent];  }

- (void)scrollWheel:(NSEvent *)theEvent
{  [_eventFilter scrollWheel: theEvent];  }

- (void)keyDown:(NSEvent *)theEvent
{  [_eventFilter keyDown: theEvent];  }

- (void)keyUp:(NSEvent *)theEvent
{  [_eventFilter keyUp: theEvent];  }

- (void)flagsChanged:(NSEvent *)theEvent
{  [_eventFilter flagsChanged: theEvent];  }


- (void)concludeDragOperation:(id <NSDraggingInfo>)sender {}

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
    return NSDragOperationGeneric;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
    return NSDragOperationGeneric;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    return [_delegate pasteFromPasteboard:[sender draggingPasteboard]];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    return YES;
}

// FX Edit
- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
    if (!(self.keyboardMode >= 2 && self.isFirstResponder)) {
        return NO;
    }
    
    NSUInteger flags = [theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask;
    
    if (flags > 0) {
        //NSLog(@"Chicken: Handled Key Equivalent");
        [_eventFilter queueKeyEventFromEvent:theEvent];
        
        return YES;
    }
    
    return NO;
}

- (BOOL)isFirstResponder
{
    return ([self window] && self == [[self window] firstResponder]);
}

- (int)keyboardMode
{
    if (_delegate && _delegate.profile) {
        return _delegate.profile.keyboardMode;
    }
    
    return 1;
}

@end
