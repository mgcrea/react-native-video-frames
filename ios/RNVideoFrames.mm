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
              options:(JS::NativeVideoFrames::ExtractFramesOptions &)options
              resolve:(RCTPromiseResolveBlock)resolve
               reject:(RCTPromiseRejectBlock)reject {
  // Convert C++ struct to NSDictionary
  NSMutableDictionary *optionsDict = [NSMutableDictionary new];
  if (options.width().has_value()) {
    optionsDict[@"width"] = @(options.width().value());
  }
  if (options.height().has_value()) {
    optionsDict[@"height"] = @(options.height().value());
  }
  if (options.quality().has_value()) {
    optionsDict[@"quality"] = @(options.quality().value());
  }

  [_swiftVideoFrames extractFrames:videoPath
                             times:times
                           options:optionsDict.count > 0 ? optionsDict : nil
                          resolver:resolve
                          rejecter:reject];
}

@end
