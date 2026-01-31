package io.mgcrea.rnvideoframes

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.util.Log
import com.facebook.fbreact.specs.NativeVideoFramesSpec
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

class NativeVideoFramesModule(
    reactContext: ReactApplicationContext
) : NativeVideoFramesSpec(reactContext) {

    companion object {
        const val NAME = "NativeVideoFramesModule"
        private const val TAG = "NativeVideoFrames"
        private const val MAX_DIMENSION = 16000.0
        private const val DEFAULT_QUALITY = 0.9
    }

    // Single-thread executor for sequential frame extraction
    private val executor = Executors.newSingleThreadExecutor()

    override fun getName(): String = NAME

    override fun extractFrames(
        videoPath: String,
        times: ReadableArray,
        options: ReadableMap?,
        promise: Promise
    ) {
        // Early return for empty times
        if (times.size() == 0) {
            promise.resolve(Arguments.createArray())
            return
        }

        // Parse options
        val width = options?.takeIf { it.hasKey("width") }?.getDouble("width")
        val height = options?.takeIf { it.hasKey("height") }?.getDouble("height")
        val quality = options?.takeIf { it.hasKey("quality") }?.getDouble("quality") ?: DEFAULT_QUALITY
        val precise = options?.takeIf { it.hasKey("precise") }?.getBoolean("precise") ?: false

        // Validate quality
        if (quality < 0.0 || quality > 1.0) {
            promise.reject("E_INVALID_ARGS", "Quality must be between 0.0 and 1.0, got $quality")
            return
        }

        // Validate dimensions
        width?.let {
            if (it <= 0 || it > MAX_DIMENSION) {
                promise.reject("E_INVALID_ARGS", "Width must be between 1 and ${MAX_DIMENSION.toInt()}, got ${it.toInt()}")
                return
            }
        }
        height?.let {
            if (it <= 0 || it > MAX_DIMENSION) {
                promise.reject("E_INVALID_ARGS", "Height must be between 1 and ${MAX_DIMENSION.toInt()}, got ${it.toInt()}")
                return
            }
        }

        // Convert times to List<Long> (milliseconds)
        val timesList = mutableListOf<Long>()
        for (i in 0 until times.size()) {
            timesList.add(times.getDouble(i).toLong())
        }

        // Execute on background thread
        executor.execute {
            extractFramesInternal(videoPath, timesList, width, height, quality, precise, promise)
        }
    }

    private fun extractFramesInternal(
        videoPath: String,
        times: List<Long>,
        width: Double?,
        height: Double?,
        quality: Double,
        precise: Boolean,
        promise: Promise
    ) {
        val retriever = MediaMetadataRetriever()
        val results = mutableListOf<String>()
        val failedTimestamps = mutableListOf<Pair<Long, String>>()

        try {
            // Parse video path (handle file:// URIs and absolute paths)
            val uri = parseVideoPath(videoPath)
            if (uri == null) {
                promise.reject("E_INVALID_URL", "Invalid video file URL: $videoPath")
                return
            }

            // Set data source
            try {
                when (uri.scheme) {
                    "content" -> retriever.setDataSource(reactApplicationContext, uri)
                    "file" -> retriever.setDataSource(uri.path)
                    else -> retriever.setDataSource(uri.path)
                }
            } catch (e: Exception) {
                promise.reject("E_INVALID_ASSET", "Could not load video asset: ${e.message}")
                return
            }

            // Validate asset has duration
            val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            val duration = durationStr?.toLongOrNull() ?: 0L
            if (duration <= 0) {
                promise.reject("E_INVALID_ASSET", "Could not load video asset or duration is zero")
                return
            }

            // Get video dimensions for scaling calculations
            val videoWidthStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            val videoHeightStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            val videoWidth = videoWidthStr?.toIntOrNull() ?: 0
            val videoHeight = videoHeightStr?.toIntOrNull() ?: 0

            // Calculate target dimensions
            val (targetWidth, targetHeight) = calculateTargetDimensions(
                videoWidth, videoHeight, width?.toInt(), height?.toInt()
            )

            // Determine extraction option based on precise flag
            // OPTION_CLOSEST requires API 28+, fallback to OPTION_CLOSEST_SYNC
            val option = if (precise && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                MediaMetadataRetriever.OPTION_CLOSEST
            } else {
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC
            }

            // Get cache directory for output files
            val cacheDir = reactApplicationContext.cacheDir

            // Extract frames
            for (timeMs in times) {
                try {
                    val timeUs = timeMs * 1000 // Convert ms to microseconds

                    // Extract frame
                    val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1 && targetWidth > 0 && targetHeight > 0) {
                        // API 27+: Use getScaledFrameAtTime for better performance
                        retriever.getScaledFrameAtTime(timeUs, option, targetWidth, targetHeight)
                    } else {
                        // Older API: Get full frame and scale manually if needed
                        retriever.getFrameAtTime(timeUs, option)?.let { frame ->
                            if (targetWidth > 0 && targetHeight > 0 &&
                                (frame.width != targetWidth || frame.height != targetHeight)) {
                                val scaled = Bitmap.createScaledBitmap(frame, targetWidth, targetHeight, true)
                                if (scaled !== frame) frame.recycle()
                                scaled
                            } else {
                                frame
                            }
                        }
                    }

                    if (bitmap == null) {
                        failedTimestamps.add(timeMs to "Failed to extract frame")
                        continue
                    }

                    // Save to JPEG
                    val fileName = "vf-$timeMs.jpg"
                    val outputFile = File(cacheDir, fileName)

                    val fos = FileOutputStream(outputFile)
                    try {
                        bitmap.compress(Bitmap.CompressFormat.JPEG, (quality * 100).toInt(), fos)
                    } finally {
                        fos.close()
                    }
                    bitmap.recycle()

                    results.add("file://" + outputFile.absolutePath)
                } catch (e: Exception) {
                    failedTimestamps.add(timeMs to (e.message ?: "Unknown error"))
                    Log.e(TAG, "Frame error at ${timeMs}ms: ${e.message}")
                }
            }

        } catch (e: Exception) {
            promise.reject("E_EXTRACTION_FAILED", "Frame extraction failed: ${e.message}")
            return
        } finally {
            try {
                retriever.release()
            } catch (e: Exception) {
                // Ignore release errors
            }
        }

        // Return results
        if (results.isEmpty() && failedTimestamps.isNotEmpty()) {
            val reasons = failedTimestamps.take(5).joinToString("; ") { "${it.first}ms: ${it.second}" }
            val suffix = if (failedTimestamps.size > 5) " (and ${failedTimestamps.size - 5} more)" else ""
            promise.reject("E_EXTRACTION_FAILED", "Failed to extract all ${failedTimestamps.size} frames: $reasons$suffix")
        } else {
            val resultArray = Arguments.createArray()
            results.forEach { resultArray.pushString(it) }
            promise.resolve(resultArray)
        }
    }

    private fun parseVideoPath(videoPath: String): Uri? {
        return try {
            when {
                videoPath.startsWith("file://") -> Uri.parse(videoPath)
                videoPath.startsWith("content://") -> Uri.parse(videoPath)
                videoPath.startsWith("/") -> Uri.fromFile(File(videoPath))
                else -> null
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun calculateTargetDimensions(
        videoWidth: Int,
        videoHeight: Int,
        requestedWidth: Int?,
        requestedHeight: Int?
    ): Pair<Int, Int> {
        if (videoWidth <= 0 || videoHeight <= 0) {
            return 0 to 0 // Can't scale without video dimensions
        }

        val aspectRatio = videoWidth.toFloat() / videoHeight.toFloat()

        return when {
            requestedWidth != null && requestedHeight != null -> {
                // Both dimensions: fit within bounding box maintaining aspect ratio
                val widthRatio = requestedWidth.toFloat() / videoWidth
                val heightRatio = requestedHeight.toFloat() / videoHeight
                val scale = minOf(widthRatio, heightRatio)
                (videoWidth * scale).toInt() to (videoHeight * scale).toInt()
            }
            requestedWidth != null -> {
                // Width only: scale height proportionally
                requestedWidth to (requestedWidth / aspectRatio).toInt()
            }
            requestedHeight != null -> {
                // Height only: scale width proportionally
                (requestedHeight * aspectRatio).toInt() to requestedHeight
            }
            else -> {
                // No dimensions: use original size
                0 to 0
            }
        }
    }
}
