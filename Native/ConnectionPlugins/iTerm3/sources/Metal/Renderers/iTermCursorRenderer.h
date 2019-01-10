#import <Foundation/Foundation.h>

#import "iTermMetalCellRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@class iTermCopyModeCursorRenderer;

@interface iTermCursorRendererTransientState : iTermMetalCellRendererTransientState
@property (nonatomic, strong) NSColor *color;
@property (nonatomic) VT100GridCoord coord;
@property (nonatomic) BOOL doubleWidth;
@end

@interface iTermCursorRenderer : NSObject<iTermMetalCellRenderer>

+ (instancetype)newUnderlineCursorRendererWithDevice:(id<MTLDevice>)device;
+ (instancetype)newBarCursorRendererWithDevice:(id<MTLDevice>)device;
+ (instancetype)newIMECursorRendererWithDevice:(id<MTLDevice>)device;
+ (instancetype)newBlockCursorRendererWithDevice:(id<MTLDevice>)device;
+ (instancetype)newFrameCursorRendererWithDevice:(id<MTLDevice>)device;
+ (instancetype)newKeyCursorRendererWithDevice:(id<MTLDevice>)device;

+ (iTermCopyModeCursorRenderer *)newCopyModeCursorRendererWithDevice:(id<MTLDevice>)device;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface iTermCopyModeCursorRendererTransientState : iTermCursorRendererTransientState
@property (nonatomic) BOOL selecting;
@end

@interface iTermCopyModeCursorRenderer : iTermCursorRenderer
@end

@interface iTermFrameCursorRenderer : iTermCursorRenderer
@end

@interface iTermKeyCursorRenderer : iTermCursorRenderer
@end

NS_ASSUME_NONNULL_END
