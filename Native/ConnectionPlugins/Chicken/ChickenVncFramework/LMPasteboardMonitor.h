#import <Foundation/Foundation.h>

@class LMPasteboardMonitor;

@protocol LMPasteboardMonitorDelegate

- (void)pasteboardDidUpdateWithMatchingType:(LMPasteboardMonitor*)pasteboardMonitor;

@end

@interface LMPasteboardMonitor : NSObject

@property (retain) NSArray<NSPasteboardType>* pasteboardTypes;
@property (assign) id<LMPasteboardMonitorDelegate> delegate;

- (instancetype)initWithPasteboardTypes:(NSArray<NSPasteboardType>*)types;

- (void)stop;
- (void)start;

@end
