//
//  PasteContext.h
//  iTerm
//
//  Created by George Nachman on 3/12/13.
//
//

#import <Foundation/Foundation.h>

@interface PasteContext : NSObject

@property(nonatomic, assign) int bytesPerCall;
@property(nonatomic, assign) float delayBetweenCalls;
@property(nonatomic, assign) BOOL blockAtNewline;
@property(nonatomic, assign) BOOL isBlocked;
@property(nonatomic, assign) BOOL isUpload;
@property(nonatomic, copy) void (^progress)(NSInteger);
@property(nonatomic, assign) NSInteger bytesWritten;

- (instancetype)initWithBytesPerCallPrefKey:(NSString*)bytesPerCallKey
                     defaultValue:(int)bytesPerCallDefault
         delayBetweenCallsPrefKey:(NSString*)delayBetweenCallsKey
                     defaultValue:(float)delayBetweenCallsDefault;

- (void)updateValues;

@end
