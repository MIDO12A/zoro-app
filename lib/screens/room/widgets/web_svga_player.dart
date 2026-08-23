
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WebSvgaPlayer extends StatefulWidget {
  final String assetPath;
  final double width;
  final double height;
  final bool loops;
  final VoidCallback? onFinished;
  final BoxFit fit;

  const WebSvgaPlayer({
    super.key,
    required this.assetPath,
    required this.width,
    required this.height,
    this.loops = true,
    this.onFinished,
    this.fit = BoxFit.contain,
  });

  @override
  State<WebSvgaPlayer> createState() => _WebSvgaPlayerState();
}

class _WebSvgaPlayerState extends State<WebSvgaPlayer> {
  final String _viewType = UniqueKey().toString();
  String? _assetUrl;

  @override
  void initState() {
    super.initState();
    _loadAssetUrl();
  }

  Future<void> _loadAssetUrl() async {
    // Get the correct asset URL for Flutter web
    final assetBundle = DefaultAssetBundle.of(context);
    // We need to ensure the asset is properly loaded
    await assetBundle.load(widget.assetPath);
    setState(() {
      _assetUrl = 'assets/${widget.assetPath}';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_assetUrl == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: HtmlElementView(
        viewType: _viewType,
        onPlatformViewCreated: (int viewId) {
          _initializePlayer(viewId);
        },
      ),
    );
  }

  void _initializePlayer(int viewId) {
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      final container = html.DivElement()
        ..id = 'svga-container-$viewId'
        ..style.width = '${widget.width}px'
        ..style.height = '${widget.height}px'
        ..style.position = 'relative'
        ..style.overflow = 'hidden';

      // Initialize SVGA player initialization after the view is created
      Future.microtask(() {
        final script = html.ScriptElement()
          ..type = 'text/javascript'
          ..text = '''
            (function() {
              const container = document.getElementById('svga-container-$viewId');
              if (!container) return;
              
              const player = new SVGA.Player('#svga-container-$viewId');
              const parser = new SVGA.Parser('#svga-container-$viewId');
              
              player.loops = ${widget.loops ? '0' : '1'};
              player.clearsAfterStop = true;
              
              player.onFinished(function() {
                console.log('SVGA finished');
              });
              
              parser.load('$_assetUrl', function(videoItem) {
                console.log('SVGA loaded');
                player.setVideoItem(videoItem);
                player.startAnimation();
              }, function(error) {
                console.error('SVGA Error:', error);
              });
            })();
          ''';

        container.append(script);
      });

      return container;
    });
  }
}
