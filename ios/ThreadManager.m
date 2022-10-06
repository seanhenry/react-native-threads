#import "ThreadManager.h"
#include <stdlib.h>

@implementation ThreadManager

@synthesize bridge = _bridge;

NSMutableDictionary *threads;
dispatch_queue_t preloadQueue;

// 1. Moves initialization of globals into static `initialize` method.
+ (void)initialize {
  if (threads == nil) {
    // 2. Since we are now accessing `threads` on different threads we must initialize it before any method is
    // called to prevent a race condition.
    threads = [[NSMutableDictionary alloc] init];
    // 3. Create queue so we can preload our threads off the main thread.
    // We use a serial queue so that we can guarantee that events happen in order.
    preloadQueue = dispatch_queue_create("com.threadexample.preload", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0));
  }
}

// 4. Load threads from Info.plist and start each thread
// See Info.plist for a list of threads. This has the advantage of being able to add/remove a worker thread
// without recompiling the app.
+ (void)preloadThreadsWithParentBridge:(RCTBridge *)parentBridge {
  NSArray *preloadedThreads = NSBundle.mainBundle.infoDictionary[@"RNThreadsPreloadedEntryPaths"];
  dispatch_async(preloadQueue, ^{
    [preloadedThreads enumerateObjectsUsingBlock:^(id path, NSUInteger idx, BOOL *stop) {
      [self startThreadWithName:path identifier:(uint32_t)idx parentBridge:parentBridge];
    }];
  });
}

// 5. Since the `threads` dictionary is now accessed concurrently (during preloading), we use the preload queue
// as this bridge module's methodQueue. This means all interactions from JS will be moved to the preload
// queue and thread safety across the global resources is assured.
- (dispatch_queue_t)methodQueue {
  return preloadQueue;
}

RCT_EXPORT_MODULE();

// 6. We extracted this original method into two so the same code can be used to preload threads as well as
// starting threads from JS.
RCT_REMAP_METHOD(startThread,
                 name: (NSString *)name
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  uint32_t threadId = arc4random();
  [ThreadManager startThreadWithName:name
                          identifier:threadId
                        parentBridge:self.bridge];
  resolve(@(threadId));
}

+ (void)startThreadWithName:(NSString *)name
                                identifier:(uint32_t)threadId
                              parentBridge:(RCTBridge *)parentBridge
{
  NSURL *threadURL = [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:name];
  NSLog(@"starting Thread %@", [threadURL absoluteString]);


  RCTBridge *threadBridge = [[RCTBridge alloc] initWithBundleURL:threadURL
                                                  moduleProvider:nil
                                                   launchOptions:nil];

  ThreadSelfManager *threadSelf = [threadBridge moduleForName:@"ThreadSelfManager"];
  [threadSelf setThreadId:threadId];
  [threadSelf setParentBridge:parentBridge];

  [threads setObject:threadBridge forKey:[NSNumber numberWithInt:threadId]];
}

RCT_EXPORT_METHOD(stopThread:(int)threadId)
{
  if (threads == nil) {
    NSLog(@"Empty list of threads. abort stopping thread with id %i", threadId);
    return;
  }

  RCTBridge *threadBridge = threads[[NSNumber numberWithInt:threadId]];
  if (threadBridge == nil) {
    NSLog(@"Thread is NIl. abort stopping thread with id %i", threadId);
    return;
  }

  [threadBridge invalidate];
  [threads removeObjectForKey:[NSNumber numberWithInt:threadId]];
}

RCT_EXPORT_METHOD(postThreadMessage: (int)threadId message:(NSString *)message)
{
  if (threads == nil) {
    NSLog(@"Empty list of threads. abort posting to thread with id %i", threadId);
    return;
  }

  RCTBridge *threadBridge = threads[[NSNumber numberWithInt:threadId]];
  if (threadBridge == nil) {
    NSLog(@"Thread is NIl. abort posting to thread with id %i", threadId);
    return;
  }

  [threadBridge.eventDispatcher sendAppEventWithName:@"ThreadMessage"
                                                body:message];
}

// 8. React does not call `invalidate` using the `methodQueue` so we make sure this is thread safe too.
- (void)invalidate {
  dispatch_async(preloadQueue, ^{
    if (threads == nil) {
      return;
    }

    for (NSNumber *threadId in threads) {
      RCTBridge *threadBridge = threads[threadId];
      [threadBridge invalidate];
    }

    [threads removeAllObjects];
  });
}

@end
