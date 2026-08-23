
import 'dart:html' as html;
import 'package:flutter/material.dart';
// ignore: undefined_hidden_name
import 'dart:ui' as ui;

class SimpleWebSvga extends StatefulWidget {
  final String assetUrl;
  final double width;
  final double height;
  final bool loops;

  const SimpleWebSvga({
    super.key,
    required this.assetUrl,
    required this.width,
    required this.height,
    this.loops = true,
  });

  @override
  State<SimpleWebSvga> createState() => _SimpleWebSvgaState();
}

class _SimpleWebSvgaState extends State<SimpleWebSvga> {
  final String _viewType = 'simple-svga-${UniqueKey().toString()}';
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _register();
  }

  void _register() {
    if (_registered) return;
    _registered = true;
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final div = html.DivElement()
        ..id = 'simple-svga-$viewId'
        ..style.width = '${widget.width}px'
        ..style.height = '${widget.height}px';

      final script = html.ScriptElement()
        ..innerHtml = '''
          setTimeout(function() {
            var div = document.getElementById('simple-svga-$viewId');
            if (div && window.SVGA) {
              var player = new SVGA.Player('#simple-svga-$viewId');
              var parser = new SVGA.Parser('#simple-svga-$viewId');
              player.loops = ${widget.loops ? '0' : '1'};
              parser.load('${widget.assetUrl}', function(videoItem) {
                player.setVideoItem(videoItem);
                player.startAnimation();
                console.log('SVGA Playing');
              }, function(err) {
                console.error('SVGA Error:', err);
              });
            } else {
              console.log('Missing div or SVGA');
            }
          }, 100);
        ''';

      div.append(script);
      return div;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
