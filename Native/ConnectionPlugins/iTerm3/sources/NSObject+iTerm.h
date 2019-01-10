//
//  NSObject+iTerm.h
//  iTerm
//
//  Created by George Nachman on 12/22/13.
//
//

#import <Foundation/Foundation.h>

@interface iTermDelayedPerform : NSObject
// If set before the block is run, then the block will not be run.
@property(nonatomic, assign) BOOL canceled;

// Set by NSObject just before block is run.
@property(nonatomic, assign) BOOL completed;
@end

@interface NSObject (iTerm)

+ (BOOL)object:(NSObject *)a isEqualToObject:(NSObject *)b;
+ (instancetype)castFrom:(id)object;

- (void)performSelectorOnMainThread:(SEL)selector withObjects:(NSArray *)objects;

// Retains self for |delay| time, whether canceled or not.
// Set canceled=YES on the result to keep the block from running. Its completed flag will be set to
// YES before block is run. The pattern usually looks like this:
//
// @implementation MyClass {
//   __weak iTermDelayedPerform *_delayedPerform;
// }
//
// - (void)scheduleTask {
//   [self cancelScheduledTask];  // Don't this if you don't want to schedule two tasks at once.
//   _delayedPerform = [self performBlock:^() {
//                               [self performTask];
//                               if (_delayedPerform.completed) {
//                                 _delayedPerform = nil;
//                               }
//                             }
//                             afterDelay:theDelay];
// }
//
// - (void)cancelScheduledTask {
//   _delayedPerform.canceled = YES;
//   _delayedPerform = nil;
// }
- (iTermDelayedPerform *)performBlock:(void (^)(void))block afterDelay:(NSTimeInterval)delay;

// Returns nil if this object is an instance of NSNull, otherwise returns self.
- (instancetype)nilIfNull;

- (void)it_setAssociatedObject:(id)associatedObject forKey:(void *)key;
- (id)it_associatedObjectForKey:(void *)key;

@end
