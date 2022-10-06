#ifndef ThreadManager_h
#define ThreadManager_h

#import "ThreadSelfManager.h"
#import <React/RCTBridge.h>
#import <React/RCTBridge+Private.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTBundleURLProvider.h>

@interface ThreadManager : NSObject <RCTBridgeModule>

/**
  Preloads worker threads at launch from Info.plist.

  Add an array called `RNThreadsPreloadedEntryPaths` with entry paths to your JS worker modules. They will be loaded with their id matching
  their index in the array.
 */
+ (void)preloadThreadsWithParentBridge:(RCTBridge *)bridge;

@end

#endif
