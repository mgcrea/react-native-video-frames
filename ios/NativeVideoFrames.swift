import Foundation

@objc(NativeVideoFrames)
public class NativeVideoFrames: NSObject {
  @objc
  public func add(_ a: NSNumber, b: NSNumber) -> NSNumber {
    let result = a.doubleValue + b.doubleValue
    return NSNumber(value: result)
  }
}
