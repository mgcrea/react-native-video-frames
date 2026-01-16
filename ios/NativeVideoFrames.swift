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

    // Validate asset has video tracks
    guard asset.tracks(withMediaType: .video).count > 0 else {
      rejecter("E_INVALID_ASSET", "Video file contains no video tracks", nil)
      return
    }

    // Validate asset has valid duration
    let duration = asset.duration
    guard CMTIME_IS_VALID(duration) && duration.value > 0 else {
      rejecter("E_INVALID_ASSET", "Could not load video asset or duration is zero", nil)
      return
    }

    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    // Use default tolerances for better reliability and performance
    // generator.requestedTimeToleranceBefore = .zero
    // generator.requestedTimeToleranceAfter = .zero

    // Extract and validate quality option (default: 0.9, range: 0.0-1.0)
    let quality: CGFloat
    if let options = options, let q = options["quality"] as? NSNumber {
      let qualityValue = q.doubleValue
      guard qualityValue >= 0.0 && qualityValue <= 1.0 else {
        rejecter("E_INVALID_ARGS", "Quality must be between 0.0 and 1.0, got \(qualityValue)", nil)
        return
      }
      quality = CGFloat(qualityValue)
    } else {
      quality = 0.9
    }

    // Configure output dimensions if options provided
    if let options = options {
      let width = options["width"] as? NSNumber
      let height = options["height"] as? NSNumber

      // Validate dimensions if provided (must be positive and reasonable)
      let maxDimension: Double = 16000
      if let w = width {
        let widthValue = w.doubleValue
        guard widthValue > 0 && widthValue <= maxDimension else {
          rejecter("E_INVALID_ARGS", "Width must be between 1 and \(Int(maxDimension)), got \(widthValue)", nil)
          return
        }
      }
      if let h = height {
        let heightValue = h.doubleValue
        guard heightValue > 0 && heightValue <= maxDimension else {
          rejecter("E_INVALID_ARGS", "Height must be between 1 and \(Int(maxDimension)), got \(heightValue)", nil)
          return
        }
      }

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
      var failedTimestamps: [(ms: Int, reason: String)] = []

      for timeVal in timeValues {
        // Use autoreleasepool to keep memory in check for many frames
        autoreleasepool {
          let cmTime = timeVal.timeValue
          let timestampMs = Int(cmTime.seconds * 1000)
          do {
            let imageRef = try generator.copyCGImage(at: cmTime, actualTime: nil)
            let uiImage = UIImage(cgImage: imageRef)

            guard let data = uiImage.jpegData(compressionQuality: quality) else {
              failedTimestamps.append((ms: timestampMs, reason: "Failed to encode JPEG"))
              return
            }

            let tmpDir = NSTemporaryDirectory()
            let fileName = "vf-\(timestampMs).jpg"
            let fileURL = URL(fileURLWithPath: tmpDir).appendingPathComponent(fileName)

            try data.write(to: fileURL, options: .atomic)
            results.append(fileURL.absoluteString)
          } catch {
            // Track failed timestamps for error reporting
            failedTimestamps.append((ms: timestampMs, reason: error.localizedDescription))
            NSLog("[NativeVideoFrames] frame error at \(timestampMs)ms: \(error.localizedDescription)")
          }
        }
      }

      DispatchQueue.main.async {
        // If all frames failed, reject with details
        if results.isEmpty && !failedTimestamps.isEmpty {
          let reasons = failedTimestamps.prefix(5).map { "\($0.ms)ms: \($0.reason)" }.joined(separator: "; ")
          let suffix = failedTimestamps.count > 5 ? " (and \(failedTimestamps.count - 5) more)" : ""
          rejecter("E_EXTRACTION_FAILED", "Failed to extract all \(failedTimestamps.count) frames: \(reasons)\(suffix)", nil)
          return
        }
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
