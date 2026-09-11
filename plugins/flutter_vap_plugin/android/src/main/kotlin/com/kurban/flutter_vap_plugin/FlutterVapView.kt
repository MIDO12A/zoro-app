package com.kurban.flutter_vap_plugin

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.view.View
import com.tencent.qgame.animplayer.AnimView
import com.tencent.qgame.animplayer.inter.IAnimListener
import com.tencent.qgame.animplayer.inter.IFetchResource
import com.tencent.qgame.animplayer.mix.Resource
import com.tencent.qgame.animplayer.util.ScaleType
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import android.util.Log
import io.flutter.FlutterInjector

class FlutterVapView(
    private val context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    args: Any?,
) : PlatformView, IAnimListener, IFetchResource {

    private var animView: AnimView = AnimView(context)
    private val methodChannel: MethodChannel = MethodChannel(messenger, "flutter_vap_plugin_$viewId")
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newCachedThreadPool()
    private var lastPlayedFile: File? = null
    private var lastPlayPath: String? = null
    private var destroyed = false
    private var deleteOnEnd = false
    private var scaleType: ScaleType = ScaleType.FIT_XY
    private var playGeneration = 0

    private var textReplacements: Map<String, String> = emptyMap()
    private var imageReplacements: Map<String, String> = emptyMap()
    private val bitmapCache = HashMap<String, Bitmap>()

    init {
        val layoutParams = android.widget.FrameLayout.LayoutParams(
            android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
            android.widget.FrameLayout.LayoutParams.MATCH_PARENT
        )
        animView.layoutParams = layoutParams

        if (args is Map<*, *>) {
            scaleType = when (args["scaleType"]) {
                "FIT_XY" -> ScaleType.FIT_XY
                "FIT_CENTER" -> ScaleType.FIT_CENTER
                "CENTER_CROP" -> ScaleType.CENTER_CROP
                else -> ScaleType.FIT_XY
            }
        }

        animView.setScaleType(scaleType)
        animView.setMute(true)
        animView.setAnimListener(this)
        animView.setFetchResource(this)

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "stop" -> {
                    playGeneration++
                    lastPlayPath = null
                    animView.stopPlay()
                    result.success(false)
                }

                "play" -> {
                    val path = call.argument<String>("path")
                    val sourceType = call.argument<String>("sourceType")
                    val repeatCount = normalizeLoop(call.argument<Int>("repeatCount") ?: 1)
                    val delete = call.argument<Boolean>("deleteOnEnd") ?: true
                    val textMap = call.argument<Map<String, String>>("textReplacement") ?: emptyMap()
                    val imageMap = call.argument<Map<String, String>>("imageReplacement") ?: emptyMap()

                    textReplacements = textMap
                    imageReplacements = imageMap

                    if (path != null && sourceType != null) {
                        if (path == lastPlayPath && animView.isRunning()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        playGeneration++
                        val gen = playGeneration
                        if (animView.isRunning()) {
                            animView.stopPlay()
                            mainHandler.postDelayed({
                                if (!destroyed && gen == playGeneration) {
                                    playWithParams(path, sourceType, repeatCount, delete)
                                }
                            }, 160)
                        } else {
                            playWithParams(path, sourceType, repeatCount, delete)
                        }
                    }
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun fetchImage(resource: Resource, result: (Bitmap?) -> Unit) {
        val tag = resource.tag ?: ""
        var targetUrl: String? = null

        if (imageReplacements.containsKey(tag)) {
            targetUrl = imageReplacements[tag]
        }
        if (targetUrl == null) {
            val cleanTag = tag.replace("[", "").replace("]", "").trim()
            for ((k, v) in imageReplacements) {
                if (k.replace("[", "").replace("]", "").trim().equals(cleanTag, ignoreCase = true)) {
                    targetUrl = v
                    break
                }
            }
        }
        if (targetUrl == null && imageReplacements.isNotEmpty()) {
            targetUrl = imageReplacements.values.firstOrNull()
        }

        if (targetUrl.isNullOrEmpty()) {
            result(null)
            return
        }

        synchronized(bitmapCache) {
            val cached = bitmapCache[targetUrl]
            if (cached != null && !cached.isRecycled) {
                result(cached)
                return
            }
        }

        executor.execute {
            try {
                val rawBytes = if (targetUrl.startsWith("http://") || targetUrl.startsWith("https://")) {
                    val conn = URL(targetUrl).openConnection() as HttpURLConnection
                    conn.connectTimeout = 4000
                    conn.readTimeout = 4000
                    conn.doInput = true
                    conn.connect()
                    conn.inputStream.use { it.readBytes() }
                } else {
                    File(targetUrl).readBytes()
                }

                val options = BitmapFactory.Options().apply {
                    inJustDecodeBounds = true
                }
                BitmapFactory.decodeByteArray(rawBytes, 0, rawBytes.size, options)

                var sampleSize = 1
                val targetSize = 256
                while (options.outWidth / (sampleSize * 2) >= targetSize && options.outHeight / (sampleSize * 2) >= targetSize) {
                    sampleSize *= 2
                }

                val decodeOptions = BitmapFactory.Options().apply {
                    inSampleSize = sampleSize
                    inPreferredConfig = Bitmap.Config.RGB_565
                }
                val bmp = BitmapFactory.decodeByteArray(rawBytes, 0, rawBytes.size, decodeOptions)

                if (bmp != null) {
                    synchronized(bitmapCache) {
                        bitmapCache[targetUrl] = bmp
                    }
                    mainHandler.post { result(bmp) }
                } else {
                    mainHandler.post { result(null) }
                }
            } catch (e: Exception) {
                Log.e("FlutterVapView", "Error fetching image for tag $tag: ${e.message}")
                mainHandler.post { result(null) }
            }
        }
    }

    override fun fetchText(resource: Resource, result: (String?) -> Unit) {
        val tag = resource.tag ?: ""
        var text: String? = null

        if (textReplacements.containsKey(tag)) {
            text = textReplacements[tag]
        }
        if (text == null) {
            val cleanTag = tag.replace("[", "").replace("]", "").trim()
            for ((k, v) in textReplacements) {
                if (k.replace("[", "").replace("]", "").trim().equals(cleanTag, ignoreCase = true)) {
                    text = v
                    break
                }
            }
        }
        if (text == null && textReplacements.isNotEmpty()) {
            text = textReplacements.values.firstOrNull()
        }

        result(text)
    }

    override fun releaseResource(resources: List<Resource>) {
    }

    private fun loadAsset(assetPath: String): File? {
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            val key = loader.getLookupKeyForAsset(assetPath)
            context.assets.open(key).use { inputStream ->
                val tempFile = File.createTempFile("vap_", null, context.cacheDir)
                FileOutputStream(tempFile).use { outputStream ->
                    inputStream.copyTo(outputStream)
                }
                return tempFile
            }
        } catch (e: Exception) {
            Log.e("FlutterVapView", "Failed to load asset: $assetPath", e)
            mainHandler.post {
                methodChannel.invokeMethod(
                    "onFailed", mapOf(
                        "errorType" to -1,
                        "errorMsg" to "Failed to load asset: ${e.message}"
                    )
                )
            }
            return null
        }
    }

    /**
     * Tencent AnimPlayer playLoop is remaining play count:
     * 1 = play once, N = play N times, Int.MAX_VALUE ≈ infinite.
     * <= 0 or -1 from Dart is treated as infinite.
     */
    private fun normalizeLoop(repeatCount: Int): Int {
        return if (repeatCount <= 0) Int.MAX_VALUE else repeatCount
    }

    private fun playWithParams(path: String, sourceType: String, repeatCount: Int, delete: Boolean) {
        try {
            lastPlayPath = path
            when (sourceType) {
                "file" -> {
                    val file = File(path)
                    if (file.exists()) {
                        animView.setMute(true)
                        animView.setLoop(repeatCount)
                        animView.startPlay(file)
                        lastPlayedFile = file
                        deleteOnEnd = delete
                    } else {
                        onFailed(-1, "File does not exist: $path")
                    }
                }

                "asset" -> {
                    loadAsset(path)?.let { file ->
                        try {
                            animView.setMute(true)
                            animView.setLoop(repeatCount)
                            animView.startPlay(file)
                            file.deleteOnExit()
                        } catch (e: Exception) {
                            onFailed(-1, "Failed to play asset: ${e.message}")
                            file.delete()
                        }
                    }
                }

                else -> {
                    onFailed(-1, "Unsupported source type: $sourceType")
                }
            }
        } catch (e: Exception) {
            onFailed(-1, "Playback error: ${e.message}")
        }
    }

    override fun getView(): View {
        return animView
    }

    override fun dispose() {
        try {
            destroyed = true
            playGeneration++
            lastPlayPath = null
            methodChannel.setMethodCallHandler(null)
            if (animView.isRunning()) {
                animView.stopPlay()
            }
            if (deleteOnEnd) {
                lastPlayedFile?.delete()
            }
            executor.execute {
                synchronized(bitmapCache) {
                    for (bmp in bitmapCache.values) {
                        if (!bmp.isRecycled) {
                            bmp.recycle()
                        }
                    }
                    bitmapCache.clear()
                }
                executor.shutdown()
            }
        } catch (e: Exception) {
            Log.e("FlutterVapView", "Error during dispose", e)
        }
    }

    override fun onVideoStart() {
        if (!destroyed) {
            mainHandler.post {
                methodChannel.invokeMethod("onVideoStart", null)
            }
        }
    }

    override fun onVideoRender(frameIndex: Int, config: com.tencent.qgame.animplayer.AnimConfig?) {
        // Ignored to prevent high-frequency (60fps) bridge IPC flooding unless specifically needed
    }

    override fun onVideoComplete() {
        if (!destroyed) {
            mainHandler.post {
                methodChannel.invokeMethod("onVideoFinish", null)
            }
        }
    }

    override fun onVideoDestroy() {
        mainHandler.post {
            methodChannel.invokeMethod("onVideoDestroy", null)
        }
    }

    override fun onFailed(errorType: Int, errorMsg: String?) {
        mainHandler.post {
            methodChannel.invokeMethod(
                "onFailed", mapOf(
                    "errorType" to errorType,
                    "errorMsg" to (errorMsg ?: "")
                )
            )
        }
    }
}


