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

- (void)extractFrames:(NSString *)videoPath
                times:(NSArray *)times
              resolve:(RCTPromiseResolveBlock)resolve
               reject:(RCTPromiseRejectBlock)reject {
  [_swiftVideoFrames extractFrames:videoPath
                             times:times
                          resolver:resolve
                          rejecter:reject];
}

@end
