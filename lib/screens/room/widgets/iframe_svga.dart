
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class IframeSvga extends StatefulWidget {
  final String assetUrl;
  final double width;
  final double height;
  final bool loops;

  const IframeSvga({
    super.key,
    required this.assetUrl,
    required this.width,
    required this.height,
    this.loops = true,
  });

  @override
  State<IframeSvga> createState() => _IframeSvgaState();
}

class _IframeSvgaState extends State<IframeSvga> {
  static int _idCounter = 0;
  late final String _viewType;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'svga-view-${_idCounter++}';
  }

  @override
  Widget build(BuildContext context) {
    // Register platform view
    if (!_registered) {
      _registered = true;
      // ignore:undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        // Create container div
        final container = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.overflow = 'hidden';

        // Create a div for SVGA Player
        final playerDiv = html.DivElement()
          ..id = 'svga-$viewId'
          ..style.width = '100%'
          ..style.height = '100%';
        container.append(playerDiv);

        // Add SVGA library script
        final libScript = html.ScriptElement()
          ..src = 'https://cdn.jsdelivr.net/npm/svgaplayerweb@2.3.1/build/svga.min.js'
          ..async = false;

        // Add initialization script
        final initScript = html.ScriptElement()
          ..innerHtml = '''
            window.addEventListener('load', function() {
              // Wait for SVGA library to load
              var checkSvga = setInterval(function() {
                if (window.SVGA) {
                  clearInterval(checkSvga);
                  
                  var playerDiv = document.getElementById('svga-$viewId');
                  if (playerDiv) {
                    var parser = new SVGA.Parser(playerDiv);
                    var player = new SVGA.Player(playerDiv);
                    player.clearsAfterStop = true;
                    player.loops = ${widget.loops ? "1000" : "1"};
                    
                    parser.load('${widget.assetUrl}', function(videoItem) {
                      player.setVideoItem(videoItem);
                      player.startAnimation();
                    }, function(err) {
                      console.error('Failed to load SVGA: ', err);
                    });
                  }
                }
              }, 100);
            });
          ''';

        container.append(libScript);
        container.append(initScript);
        return container;
      });
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: HtmlElementView(
        key: UniqueKey(),
        viewType: _viewType,
      ),
    );
  }
}
