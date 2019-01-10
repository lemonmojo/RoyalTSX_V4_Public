#import "LMPasteboardMonitor.h"

@implementation LMPasteboardMonitor {
    NSTimer* m_timer;
    NSInteger m_changeCount;
}

- (instancetype)initWithPasteboardTypes:(NSArray<NSPasteboardType>*)types
{
    self = [super init];
    
    if (self) {
        self.pasteboardTypes = types;
    }
    
    return self;
}

- (void)dealloc
{
    self.pasteboardTypes = nil;
    
    [self stop];
    
    [super dealloc];
}

- (void)stop
{
    if (m_timer) {
        NSLog(@"ChickenVNC: Stopping Pasteboard Timer");
        [m_timer invalidate]; [m_timer release]; m_timer = nil;
    }
}

- (void)start
{
    [self stop];
    
    m_changeCount = NSPasteboard.generalPasteboard.changeCount;
    
    m_timer = [[NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(timerFired:) userInfo:nil repeats:YES] retain];
}

- (void)timerFired:(NSTimer*)timer
{
    if (!self.delegate) {
        return;
    }
    
    NSPasteboard* pasteboard = NSPasteboard.generalPasteboard;
    
    NSInteger oldChangeCount = m_changeCount;
    NSInteger newChangeCount = pasteboard.changeCount;
    
    if (newChangeCount == oldChangeCount) {
        return;
    }
    
    m_changeCount = newChangeCount;
    
    NSArray<NSPasteboardItem*>* items = pasteboard.pasteboardItems;
    
    if (items.count <= 0) {
        return;
    }
    
    NSPasteboardItem* firstItem = [items objectAtIndex:0];
    
    if (!firstItem) {
        return;
    }
    
    NSArray<NSPasteboardType>* typesInFirstItem = firstItem.types;
    
    BOOL foundMatchingType = NO;
    
    if (!self.pasteboardTypes ||
        self.pasteboardTypes.count <= 0) { // Match all types
        foundMatchingType = YES;
    } else { // Match specific types
        for (NSPasteboardType type in self.pasteboardTypes) {
            if ([typesInFirstItem containsObject:type]) {
                foundMatchingType = YES;
                break;
            }
        }
    }
    
    if (foundMatchingType &&
        self.delegate) {
        [self.delegate pasteboardDidUpdateWithMatchingType:self];
    }
}

@end
