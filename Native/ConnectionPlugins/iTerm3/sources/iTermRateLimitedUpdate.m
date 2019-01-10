//
//  iTermRateLimitedUpdate.m
//  iTerm2
//
//  Created by George Nachman on 6/17/17.
//
//

#import "iTermRateLimitedUpdate.h"
#import "NSTimer+iTerm.h"

@implementation iTermRateLimitedUpdate {
    // While nonnil, block will not be performed.
    NSTimer *_timer;
    void (^_block)(void);
}

- (void)invalidate {
    [_timer invalidate];
    _timer = nil;
    _block = nil;
}

- (void)scheduleTimer {
    _timer = [NSTimer scheduledWeakTimerWithTimeInterval:self.minimumInterval
                                                  target:self
                                                selector:@selector(performBlockIfNeeded:)
                                                userInfo:nil
                                                 repeats:NO];
}

- (void)performRateLimitedBlock:(void (^)(void))block {
    if (_timer == nil) {
        block();
        [self scheduleTimer];
    } else {
        _block = [block copy];
    }
}

- (BOOL)tryPerformRateLimitedBlock:(void (^)(void))block {
    if (_timer == nil) {
        block();
        [self scheduleTimer];
        return YES;
    } else {
        return NO;
    }
}

- (void)performRateLimitedSelector:(SEL)selector
                          onTarget:(id)target
                        withObject:(id)object {
    __weak id weakTarget = target;
    [self performRateLimitedBlock:^{
        id strongTarget = weakTarget;
        if (strongTarget) {
            void (*func)(id, SEL, NSTimer *) = (void *)[weakTarget methodForSelector:selector];
            func(weakTarget, selector, object);
        }
    }];
}

- (void)performBlockIfNeeded:(NSTimer *)timer {
    _timer = nil;
    if (_block != nil) {
        void (^block)(void) = _block;
        _block = nil;
        block();
        [self scheduleTimer];
    }
}

@end
