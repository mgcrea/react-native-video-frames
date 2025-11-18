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
   *   - options: Optional dictionary with width/height for output dimensions.
   *   - resolver: Promise resolve callback, returns `[String]` of `file://` image paths.
   *   - rejecter: Promise reject callback.
   */
  @objc(extractFrames:times:options:resolver:rejecter:)
  public func extractFrames(
    _ videoPath: String,
    times: [NSNumber],
    options: NSDictionary?,
    resolver: @escaping RCTPromiseResolveBlock,
    rejecter: @escaping RCTPromiseRejectBlock
  ) {
    // Early return for empty times array
    guard !times.isEmpty else {
      resolver([])
      return
    }

    // Defensive path handling
    let url: URL
    if videoPath.hasPrefix("file://") {
      guard let fileURL = URL(string: videoPath) else {
        rejecter("E_INVALID_URL", "Invalid video file URL: \(videoPath)", nil)
        return
      }
      url = fileURL
    } else {
      url = URL(fileURLWithPath: videoPath)
    }

    let asset = AVURLAsset(url: url)

    // Validate asset has valid duration
    let duration = asset.duration
    if duration == .zero || CMTIME_IS_INVALID(duration) {
      rejecter("E_INVALID_ASSET", "Could not load video asset or duration is zero", nil)
      return
    }

    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    // Use default tolerances for better reliability and performance
    // generator.requestedTimeToleranceBefore = .zero
    // generator.requestedTimeToleranceAfter = .zero

    // Extract quality option (default: 0.9)
    let quality: CGFloat
    if let options = options, let q = options["quality"] as? NSNumber {
      quality = CGFloat(q.doubleValue)
    } else {
      quality = 0.9
    }

    // Configure output dimensions if options provided
    if let options = options {
      let width = options["width"] as? NSNumber
      let height = options["height"] as? NSNumber

      if let w = width, let h = height {
        // Both dimensions provided - set as maximum size (maintains aspect ratio)
        generator.maximumSize = CGSize(width: w.doubleValue, height: h.doubleValue)
      } else if let w = width {
        // Only width provided - height will scale proportionally
        generator.maximumSize = CGSize(width: w.doubleValue, height: CGFloat.greatestFiniteMagnitude)
      } else if let h = height {
        // Only height provided - width will scale proportionally
        generator.maximumSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: h.doubleValue)
      }
      // If no width or height, use default (original dimensions)
    }

    // Convert ms → CMTime
    let timeValues: [NSValue] = times.map { ms in
      let seconds = ms.doubleValue / 1000.0
      return NSValue(time: CMTimeMakeWithSeconds(seconds, preferredTimescale: 600))
    }

    // Heavy-ish work: off main thread
    DispatchQueue.global(qos: .userInitiated).async {
      var results: [String] = []

      for timeVal in timeValues {
        // Use autoreleasepool to keep memory in check for many frames
        autoreleasepool {
          let cmTime = timeVal.timeValue
          do {
            let imageRef = try generator.copyCGImage(at: cmTime, actualTime: nil)
            let uiImage = UIImage(cgImage: imageRef)

            guard let data = uiImage.jpegData(compressionQuality: quality) else {
              return
            }

            let tmpDir = NSTemporaryDirectory()
            let fileName = "vf-\(Int(cmTime.seconds * 1000)).jpg"
            let fileURL = URL(fileURLWithPath: tmpDir).appendingPathComponent(fileName)

            try data.write(to: fileURL, options: .atomic)
            results.append("file://\(fileURL.path)")
          } catch {
            // Skip failed timestamps instead of rejecting everything
            NSLog("[NativeVideoFrames] frame error at \(cmTime): \(error.localizedDescription)")
          }
        }
      }

      DispatchQueue.main.async {
        resolver(results)
      }
    }
  }

  // Required by RCTBridgeModule protocol
  @objc
  public static func moduleName() -> String! {
    return "NativeVideoFrames"
  }

  @objc
  public static func requiresMainQueueSetup() -> Bool {
    return false
  }
}
