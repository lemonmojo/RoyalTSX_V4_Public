#import "iTermMetalRenderer.h"

#import "iTermMetalFrameData.h"
#import "VT100GridTypes.h"

NS_ASSUME_NONNULL_BEGIN

extern const CGFloat MARGIN_WIDTH;
extern const CGFloat TOP_MARGIN;
extern const CGFloat BOTTOM_MARGIN;

@class iTermMetalCellRendererTransientState;

NS_CLASS_AVAILABLE(10_11, NA)
@interface iTermCellRenderConfiguration : iTermRenderConfiguration
// This is the size of a cell on screen--the distance from the beginning of one character to the next.
@property (nonatomic, readonly) CGSize cellSize;
// The same, but without extra vertical/horizontal spacing.
@property (nonatomic, readonly) CGSize cellSizeWithoutSpacing;
// Maximum size of a glyph part. On 10.14, this is large enough to contain all
// ASCII glyphs on. On earlier OS versions it equals cellSize.
@property (nonatomic, readonly) CGSize glyphSize;
@property (nonatomic, readonly) VT100GridSize gridSize;

// This determines how subpixel antialiasing is done. It's unfortunate that one
// renderer's needs affect the configuration for so many renderers. I need to
// find a better way to pass this info around. The problem is that it's needed
// early on--before the transient state is created--in order for the text
// renderer to be able to set its fragment function.
@property (nonatomic, readonly) BOOL usingIntermediatePass NS_DEPRECATED_MAC(10_12, 10_14);

- (instancetype)initWithViewportSize:(vector_uint2)viewportSize
                               scale:(CGFloat)scale
                  hasBackgroundImage:(BOOL)hasBackgroundImage NS_UNAVAILABLE;

- (instancetype)initWithViewportSize:(vector_uint2)viewportSize
                               scale:(CGFloat)scale
                  hasBackgroundImage:(BOOL)hasBackgroundImage
                            cellSize:(CGSize)cellSize
                           glyphSize:(CGSize)glyphSize
              cellSizeWithoutSpacing:(CGSize)cellSizeWithoutSpacing
                            gridSize:(VT100GridSize)gridSize
               usingIntermediatePass:(BOOL)usingIntermediatePass NS_DESIGNATED_INITIALIZER;

@end

NS_CLASS_AVAILABLE(10_11, NA)
@protocol iTermMetalCellRenderer<NSObject>
@property (nonatomic, readonly) BOOL rendererDisabled;

- (iTermMetalFrameDataStat)createTransientStateStat;
- (void)drawWithFrameData:(iTermMetalFrameData *)frameData
           transientState:(__kindof iTermMetalCellRendererTransientState *)transientState;

- (nullable __kindof iTermMetalRendererTransientState *)createTransientStateForCellConfiguration:(iTermCellRenderConfiguration *)configuration
                                                                                   commandBuffer:(id<MTLCommandBuffer>)commandBuffer;

@optional
- (void)writeDebugInfoToFolder:(NSURL *)folderURL;

@end

NS_CLASS_AVAILABLE(10_11, NA)
@interface iTermMetalCellRendererTransientState : iTermMetalRendererTransientState
@property (nonatomic, readonly) __kindof iTermCellRenderConfiguration *cellConfiguration;
@property (nonatomic, readonly) id<MTLBuffer> offsetBuffer;
@property (nonatomic, strong) id<MTLBuffer> pius;
@property (nonatomic, readonly) NSEdgeInsets margins;

- (instancetype)init NS_UNAVAILABLE;

- (void)setPIUValue:(void *)c coord:(VT100GridCoord)coord;
- (const void *)piuForCoord:(VT100GridCoord)coord;

@end

NS_CLASS_AVAILABLE(10_11, NA)
@interface iTermMetalCellRenderer : iTermMetalRenderer

- (nullable instancetype)initWithDevice:(id<MTLDevice>)device NS_UNAVAILABLE;

- (nullable instancetype)initWithDevice:(id<MTLDevice>)device
                     vertexFunctionName:(NSString *)vertexFunctionName
                   fragmentFunctionName:(NSString *)fragmentFunctionName
                               blending:(nullable iTermMetalBlending *)blending
                    transientStateClass:(Class)transientStateClass NS_UNAVAILABLE;

- (nullable instancetype)initWithDevice:(id<MTLDevice>)device
                     vertexFunctionName:(NSString *)vertexFunctionName
                   fragmentFunctionName:(NSString *)fragmentFunctionName
                               blending:(nullable iTermMetalBlending *)blending
                         piuElementSize:(size_t)piuElementSize
                    transientStateClass:(Class)transientStateClass NS_DESIGNATED_INITIALIZER;

- (nullable __kindof iTermMetalRendererTransientState *)createTransientStateForCellConfiguration:(iTermCellRenderConfiguration *)configuration
                                                                                   commandBuffer:(id<MTLCommandBuffer>)commandBuffer;

@end

NS_ASSUME_NONNULL_END
