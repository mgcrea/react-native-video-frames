import AVFoundation
import Foundation
import React
import UIKit

@objc(NativeVideoFrames)
public class NativeVideoFrames: NSObject, RCTBridgeModule {
  /**
   * Extract frames at the provided times (in ms) from the given video path.
   *
   * - Parameters:
   *   - videoPath: Local file path or `file://` URI to the video.
   *   - times: Array of timestamps in milliseconds.
   *   - resolver: Promise resolve callback, returns `[String]` of `file://` image paths.
   *   - rejecter: Promise reject callback.
   */
  @objc(extractFrames:times:resolver:rejecter:)
  public func extractFrames(
    _ videoPath: String,
    times: [NSNumber],
    resolver: @escaping RCTPromiseResolveBlock,
    rejecter _: @escaping RCTPromiseRejectBlock
  ) {
    // Normalize path
    let cleanedPath = videoPath.replacingOccurrences(of: "file://", with: "")
    let url = URL(fileURLWithPath: cleanedPath)

    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero

    // Convert ms → CMTime
    let timeValues: [NSValue] = times.map { ms in
      let seconds = ms.doubleValue / 1000.0
      return NSValue(time: CMTimeMakeWithSeconds(seconds, preferredTimescale: 600))
    }

    // Heavy-ish work: off main thread
    DispatchQueue.global(qos: .userInitiated).async {
      var results: [String] = []

      for timeVal in timeValues {
        let cmTime = timeVal.timeValue
        do {
          let imageRef = try generator.copyCGImage(at: cmTime, actualTime: nil)
          let uiImage = UIImage(cgImage: imageRef)

          guard let data = uiImage.jpegData(compressionQuality: 0.9) else {
            continue
          }

          let tmpDir = NSTemporaryDirectory()
          let fileName = "vf-\(Int(cmTime.seconds * 1000)).jpg"
          let fileURL = URL(fileURLWithPath: tmpDir).appendingPathComponent(fileName)

          try data.write(to: fileURL, options: .atomic)
          results.append("file://\(fileURL.path)")
        } catch {
          // Skip failed timestamps instead of rejecting everything
          NSLog("[NativeVideoFrames] frame error at \(cmTime): \(error.localizedDescription)")
          continue
        }
      }

      DispatchQueue.main.async {
        resolver(results)
      }
    }
  }

  // Required by RCTBridgeModule to set the JS module name if needed; default uses class name.
  public static func moduleName() -> String! {
    return "NativeVideoFrames"
  }

  public static func requiresMainQueueSetup() -> Bool {
    return false
  }
}
