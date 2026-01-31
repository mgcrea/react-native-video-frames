# React Native Video Frames

<!-- markdownlint-disable MD033 -->
<p align="center">
  <a href="https://www.npmjs.com/package/@mgcrea/react-native-video-frames">
    <img src="https://img.shields.io/npm/v/@mgcrea/react-native-video-frames.svg?style=for-the-badge" alt="npm version" />
  </a>
  <a href="https://www.npmjs.com/package/@mgcrea/react-native-video-frames">
    <img src="https://img.shields.io/npm/dt/@mgcrea/react-native-video-frames.svg?style=for-the-badge" alt="npm downloads" />
  </a>
  <a href="https://github.com/mgcrea/react-native-video-frames/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/mgcrea/react-native-video-frames.svg?style=for-the-badge" alt="license" />
  </a>
</p>
<!-- markdownlint-enable MD033 -->

## Overview

**React Native Video Frames** is a lightweight native module for extracting image frames from video files at specified timestamps. Built with React Native's new Turbo Module architecture for optimal performance.

- Leverages native APIs: `AVAssetImageGenerator` (iOS) and `MediaMetadataRetriever` (Android)
- Extract frames at precise timestamps with millisecond accuracy
- Configure output dimensions while maintaining aspect ratio
- Configurable JPEG quality (0.0 - 1.0) for optimal file size vs. quality tradeoff
- Production-ready with comprehensive error handling

## Features

- **⚡ Fast & Efficient** — Uses native video processing APIs for optimal performance
- **🎯 Precise Timing** — Extract frames at exact millisecond timestamps
- **📐 Flexible Sizing** — Configure output width/height with automatic aspect ratio preservation
- **🔄 Async by Design** — Background processing with Promise-based API
- **💪 Type-Safe** — Full TypeScript support with exported types
- **🎨 Quality Control** — Configurable JPEG compression quality (0.0-1.0)
- **✅ Production Ready** — Comprehensive validation and error handling

## Installation

### Prerequisites

- React Native >= 0.74
- iOS >= 14.0
- Android SDK >= 24 (Android 7.0)
- Node.js >= 18

### Install Package

```bash
npm install @mgcrea/react-native-video-frames
```

```bash
pnpm add @mgcrea/react-native-video-frames
```

```bash
yarn add @mgcrea/react-native-video-frames
```

### iOS Setup

```bash
cd ios && pod install
```

### Android Setup

Android uses autolinking, so no additional setup is required. Just rebuild your app:

```bash
cd android && ./gradlew assembleDebug
```

## Usage

### Basic Example

```tsx
import { NativeVideoFrames } from "@mgcrea/react-native-video-frames";

// Extract frames at 1s, 2s, and 3s
const frameUris = await NativeVideoFrames.extractFrames(
  "file:///path/to/video.mp4",
  [1000, 2000, 3000], // timestamps in milliseconds
);

// frameUris: ['file:///tmp/vf-1000.jpg', 'file:///tmp/vf-2000.jpg', ...]
```

### With Options

```tsx
import { NativeVideoFrames } from "@mgcrea/react-native-video-frames";

// Extract frames with custom dimensions and quality
const frameUris = await NativeVideoFrames.extractFrames("file:///path/to/video.mp4", [1000, 2000, 3000], {
  width: 400, // Optional: specify width
  height: 300, // Optional: specify height
  quality: 0.8, // Optional: JPEG quality (0.0-1.0, default: 0.9)
});
```

### Complete Integration Example

```tsx
import { useState } from "react";
import { View, Button, Image, ScrollView } from "react-native";
import { launchImageLibrary } from "react-native-image-picker";
import { NativeVideoFrames } from "@mgcrea/react-native-video-frames";

function VideoFrameExtractor() {
  const [frames, setFrames] = useState<string[]>([]);

  const selectAndExtract = async () => {
    // Pick a video
    const result = await launchImageLibrary({ mediaType: "video" });
    const videoUri = result.assets?.[0]?.uri;

    if (!videoUri) return;

    // Extract frames at 1s intervals for first 5 seconds
    const timestamps = [1000, 2000, 3000, 4000, 5000];
    const frameUris = await NativeVideoFrames.extractFrames(videoUri, timestamps, {
      width: 400, // Resize to 400px width
      quality: 0.85, // Reduce quality for smaller files
    });

    setFrames(frameUris);
  };

  return (
    <View>
      <Button title="Select Video & Extract Frames" onPress={selectAndExtract} />
      <ScrollView>
        {frames.map((uri, index) => (
          <Image key={uri} source={{ uri }} style={{ width: "100%", height: 200 }} />
        ))}
      </ScrollView>
    </View>
  );
}
```

## API Reference

### `extractFrames(videoPath, times, options?)`

Extracts image frames from a video file at specified timestamps.

#### Parameters

| Parameter   | Type                   | Required | Description                                   |
| ----------- | ---------------------- | -------- | --------------------------------------------- |
| `videoPath` | `string`               | ✅       | Local file path or `file://` URI to the video |
| `times`     | `number[]`             | ✅       | Array of timestamps in milliseconds           |
| `options`   | `ExtractFramesOptions` | ❌       | Optional sizing configuration                 |

#### Options

```typescript
type ExtractFramesOptions = {
  width?: number; // Output width in pixels
  height?: number; // Output height in pixels
  quality?: number; // JPEG compression quality (0.0-1.0, default: 0.9)
  precise?: boolean; // Extract exact frames vs nearest keyframe (default: false)
};
```

**Sizing Behavior:**

- **Both dimensions**: Frames fit within the bounding box, maintaining aspect ratio
- **Width only**: Height scales proportionally
- **Height only**: Width scales proportionally
- **No options**: Original video dimensions

**Quality Behavior:**

- Range: `0.0` (maximum compression, smallest file) to `1.0` (minimum compression, best quality)
- Default: `0.9` (high quality with reasonable file size)
- Lower values result in smaller files but reduced image quality
- Higher values preserve quality but increase file size

**Precise Mode:**

- `false` (default): Fast extraction, snaps to nearest keyframe
- `true`: Exact frame extraction at specified timestamp (slower)
- On Android, precise mode requires API 28+ (`OPTION_CLOSEST`); falls back to keyframe on older devices

#### Returns

`Promise<string[]>` — Array of `file://` URIs pointing to extracted JPEG frames in the temporary directory.

#### Errors

The promise rejects with an error object containing:

| Code                  | Description                                                |
| --------------------- | ---------------------------------------------------------- |
| `E_INVALID_URL`       | Invalid video file URL                                     |
| `E_INVALID_ASSET`     | Could not load video, no video tracks, or zero duration    |
| `E_INVALID_ARGS`      | Invalid options (quality out of range, invalid dimensions) |
| `E_EXTRACTION_FAILED` | All frame extractions failed                               |

#### Example

```typescript
try {
  const frames = await NativeVideoFrames.extractFrames("file:///path/to/video.mp4", [1000, 5000, 10000], {
    width: 800,
    quality: 0.95, // Higher quality for important frames
  });
  console.log("Extracted frames:", frames);
} catch (error) {
  if (error.code === "E_INVALID_URL") {
    console.error("Invalid video URL");
  }
}
```

## Architecture

### Turbo Module

This library uses React Native's **new Turbo Module architecture** for optimal performance:

- **Type-Safe Bridge** — Codegen generates type-safe native bindings from TypeScript
- **Synchronous Initialization** — Faster module loading compared to legacy NativeModules
- **C++ Core** — Direct JSI integration without JSON serialization overhead

### iOS Implementation

**Three-Layer Architecture:**

1. **TypeScript Layer** ([src/NativeVideoFrames.ts](src/NativeVideoFrames.ts))
   - Defines the TurboModule interface
   - Exported types for TypeScript consumers

2. **Objective-C++ Bridge** ([ios/RNVideoFrames.mm](ios/RNVideoFrames.mm))
   - Converts JavaScript types to native types
   - Bridges to Swift implementation

3. **Swift Implementation** ([ios/NativeVideoFrames.swift](ios/NativeVideoFrames.swift))
   - Uses `AVAssetImageGenerator` for frame extraction
   - Background processing with `DispatchQueue`
   - Memory-efficient with `autoreleasepool`

**Key Implementation Details:**

- **Aspect Ratio Preservation** — `AVAssetImageGenerator.maximumSize` automatically maintains aspect ratio
- **Rotation Handling** — `appliesPreferredTrackTransform` ensures correct frame orientation
- **Memory Management** — `autoreleasepool` prevents memory buildup during batch extraction
- **Error Handling** — Gracefully skips failed frames instead of rejecting the entire operation

### Android Implementation

**Kotlin TurboModule:**

1. **TypeScript Layer** — Same interface as iOS
2. **Codegen-Generated C++ Bridge** — Automatically generated JNI bindings
3. **Kotlin Implementation** ([android/src/main/java/io/mgcrea/rnvideoframes/NativeVideoFramesModule.kt](android/src/main/java/io/mgcrea/rnvideoframes/NativeVideoFramesModule.kt))
   - Uses `MediaMetadataRetriever` for frame extraction
   - Background processing with `ExecutorService`
   - Memory-efficient with `bitmap.recycle()`

**Key Implementation Details:**

- **Aspect Ratio Preservation** — Calculates target dimensions maintaining original ratio
- **Efficient Scaling** — Uses `getScaledFrameAtTime()` on API 27+ for native scaling
- **Precise Mode** — `OPTION_CLOSEST` (API 28+) for exact frames, `OPTION_CLOSEST_SYNC` fallback
- **URI Support** — Handles `file://`, `content://`, and absolute paths
- **Memory Management** — Explicit `bitmap.recycle()` after each frame to prevent OOM

## Development

### Setup

```bash
# Clone the repository
git clone https://github.com/mgcrea/react-native-video-frames.git
cd react-native-video-frames

# Install dependencies
pnpm install

# Install iOS dependencies
cd ios && pod install && cd ..

# Build the module
pnpm build
```

### Running the Example App

```bash
# Start Metro bundler
pnpm dev

# In another terminal, run iOS
pnpm run install:ios

# Or run Android
cd example/android && ./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

### Testing

```bash
# Type checking
pnpm check

# Linting
pnpm lint

# Run tests
pnpm test
```

## Roadmap

- [x] Android support using `MediaMetadataRetriever`
- [x] Configurable JPEG quality option
- [x] Precise frame extraction mode
- [ ] Support for PNG output format
- [ ] Batch extraction progress callbacks
- [ ] Video thumbnail generation helper

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Authors

- [Olivier Louvignes](https://github.com/mgcrea) - [@mgcrea](https://twitter.com/mgcrea)

## License

```text
The MIT License

Copyright (c) 2025 Olivier Louvignes <olivier@mgcrea.io>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```
