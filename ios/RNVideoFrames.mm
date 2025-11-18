//  RCTNativeVideoFrames.m

#import "RNVideoFrames.h"
#import "RNVideoFrames-Swift.h"
#import "generated/RNVideoFramesSpec/RNVideoFramesSpec.h"

@interface RNVideoFrames ()
@end

@implementation RNVideoFrames {
  NativeVideoFrames *_swiftVideoFrames;
}

RCT_EXPORT_MODULE(NativeVideoFramesModule)

- (id)init {
  if (self = [super init]) {
    _swiftVideoFrames = [NativeVideoFrames new];
  }
  return self;
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeVideoFramesSpecJSI>(params);
}

- (nonnull NSNumber *)add:(double)a b:(double)b {
  // Box doubles into NSNumber to match Swift's @objc signature: add(_:b:)
  NSNumber *na = @(a);
  NSNumber *nb = @(b);
  return [_swiftVideoFrames add:na b:nb];
}

@end
