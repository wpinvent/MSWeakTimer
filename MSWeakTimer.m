//
//  MSWeakTimer.m
//  MindSnacks
//
//  Created by Javier Soto on 1/23/13.
//
//

#import "MSWeakTimer.h"

#if !__has_feature(objc_arc)
    #error MSWeakTimer is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif

@interface MSWeakTimer ()

@property (nonatomic, assign) NSTimeInterval timeInterval;
@property (nonatomic, assign) id<MSWeakTimerDelegate> delegate;
@property (nonatomic, retain) id userInfo;
@property (nonatomic, assign) BOOL repeats;

@property (nonatomic, assign) dispatch_queue_t dispatchQueue;

@property (atomic, assign) dispatch_source_t timer;

- (void)timerFired;

@end

@implementation MSWeakTimer

+ (MSWeakTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)timeInterval
                                       delegate:(id<MSWeakTimerDelegate>)delegate
                                       userInfo:(id)userInfo
                                        repeats:(BOOL)repeats
                                  dispatchQueue:(dispatch_queue_t)dispatchQueue
{
    MSWeakTimer *weakTimer = [[self alloc] init];

    weakTimer.timeInterval = timeInterval;
    weakTimer.delegate = delegate;
    weakTimer.userInfo = userInfo;
    weakTimer.repeats = repeats;

    dispatch_retain(dispatchQueue);
    weakTimer.dispatchQueue = dispatchQueue;

    [weakTimer schedule];

    return weakTimer;
}

- (void)dealloc
{
    [self invalidate];
    dispatch_release(_dispatchQueue);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p> time_interval=%f delegate=%@ userInfo=%@ repeats=%d timer=%@", NSStringFromClass([self class]), self, self.timeInterval, self.delegate, self.userInfo, self.repeats, self.timer];
}

#pragma mark -

- (void)schedule
{
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                        0,
                                        0,
                                        self.dispatchQueue);

    int64_t intervalInNanoseconds = (int64_t)(self.timeInterval * NSEC_PER_SEC);
    dispatch_source_set_timer(self.timer,
                              dispatch_time(DISPATCH_TIME_NOW, intervalInNanoseconds),
                              (uint64_t)intervalInNanoseconds,
                              0);

    __weak typeof(self) weakSelf = self;

    dispatch_source_set_event_handler(self.timer, ^{
        [weakSelf timerFired];

        if (!weakSelf.repeats)
        {
            [weakSelf invalidate];
        }
    });

    dispatch_resume(self.timer);
}

- (void)fire
{
    [self timerFired];
}

- (void)invalidate
{
    @synchronized(self)
    {
        if (self.timer)
        {
            dispatch_source_cancel(self.timer);
            dispatch_release(self.timer);
            self.timer = nil;
        }
    }
}

- (void)timerFired
{
    [self.delegate weakTimerDidFire:self];
}

@end