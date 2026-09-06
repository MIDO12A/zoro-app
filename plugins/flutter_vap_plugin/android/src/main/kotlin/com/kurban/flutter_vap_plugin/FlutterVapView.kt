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
    private var destroyed = false
    private var deleteOnEnd = false
    private var scaleType: ScaleType = ScaleType.FIT_XY

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
        animView.setAnimListener(this)
        animView.setFetchResource(this)

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "stop" -> {
                    animView.stopPlay()
                    Handler(Looper.getMainLooper()).postDelayed({
                        result.success(animView.isRunning())
                    }, 100)
                }

                "play" -> {
                    val path = call.argument<String>("path")
                    val sourceType = call.argument<String>("sourceType")
                    val repeatCount = call.argument<Int>("repeatCount") ?: 1
                    val delete = call.argument<Boolean>("deleteOnEnd") ?: true
                    val textMap = call.argument<Map<String, String>>("textReplacement") ?: emptyMap()
                    val imageMap = call.argument<Map<String, String>>("imageReplacement") ?: emptyMap()

                    textReplacements = textMap
                    imageReplacements = imageMap

                    if (path != null && sourceType != null) {
                        if (animView.isRunning()) {
                            animView.stopPlay()
                            Handler(Looper.getMainLooper()).postDelayed({
                                playWithParams(path, sourceType, repeatCount, delete)
                            }, 100)
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
                val bmp: Bitmap? = if (targetUrl.startsWith("http://") || targetUrl.startsWith("https://")) {
                    val conn = URL(targetUrl).openConnection() as HttpURLConnection
                    conn.connectTimeout = 6000
                    conn.readTimeout = 6000
                    conn.doInput = true
                    conn.connect()
                    val stream = conn.inputStream
                    BitmapFactory.decodeStream(stream)
                } else {
                    BitmapFactory.decodeFile(targetUrl)
                }

                if (bmp != null) {
                    synchronized(bitmapCache) {
                        bitmapCache[targetUrl] = bmp
                    }
                    result(bmp)
                } else {
                    result(null)
                }
            } catch (e: Exception) {
                Log.e("FlutterVapView", "Error fetching image for tag $tag: ${e.message}")
                result(null)
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

    private fun playWithParams(path: String, sourceType: String, repeatCount: Int, delete: Boolean) {
        try {
            when (sourceType) {
                "file" -> {
                    val file = File(path)
                    if (file.exists()) {
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
            animView.stopPlay()
            methodChannel.setMethodCallHandler(null)
            if (deleteOnEnd) {
                lastPlayedFile?.delete()
            }
            synchronized(bitmapCache) {
                bitmapCache.clear()
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
        if (!destroyed) {
            mainHandler.post {
                methodChannel.invokeMethod("onVideoRender", mapOf("frameIndex" to frameIndex))
            }
        }
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


