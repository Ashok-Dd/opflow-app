import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../l10n/lang.dart';
import '../theme/text.dart';
import '../theme/tokens.dart';
import 'op_button.dart';

/// The photo patients see is a portrait, 4:5, saved at 800 × 1000.
const _outW = 800.0;
const _frameRatio = 4 / 5;

/// Asks the doctor to frame their photo: drag to move, pinch (or the slider) to zoom, inside a fixed portrait frame.
/// Returns the cropped picture as PNG bytes, or null when they go back.
Future<Uint8List?> cropPhoto(BuildContext context, Uint8List original) {
  return Navigator.of(context, rootNavigator: true).push<Uint8List>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => _CropPage(original: original)),
  );
}

class _CropPage extends StatefulWidget {
  const _CropPage({required this.original});
  final Uint8List original;

  @override
  State<_CropPage> createState() => _CropPageState();
}

class _CropPageState extends State<_CropPage> {
  final _boundary = GlobalKey();
  final _ctl = TransformationController();
  ui.Image? _image;
  double _zoom = 1;
  bool _saving = false;
  bool _failed = false;
  Size _frame = Size.zero;
  Size _child = Size.zero;

  @override
  void initState() {
    super.initState();
    ui.decodeImageFromList(widget.original, (img) {
      if (mounted) setState(() => _image = img);
    });
    // decodeImageFromList never reports a bad file; give up after a moment.
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _image == null) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  /// Picture sized to just cover the frame, centred.
  void _layout(Size frame) {
    final img = _image!;
    final scale = (frame.width / img.width) > (frame.height / img.height) ? frame.width / img.width : frame.height / img.height;
    _frame = frame;
    _child = Size(img.width * scale, img.height * scale);
    _ctl.value = Matrix4.identity()..translateByDouble((frame.width - _child.width) / 2, (frame.height - _child.height) / 2, 0, 1);
    _zoom = 1;
  }

  void _setZoom(double z) {
    // Zoom around the middle of the frame.
    final m = _ctl.value.clone();
    final k = z / m.getMaxScaleOnAxis();
    final c = Offset(_frame.width / 2, _frame.height / 2);
    final step = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(k, k, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    _ctl.value = step * m;
    setState(() => _zoom = z);
  }

  Future<void> _done() async {
    setState(() => _saving = true);
    try {
      final b = _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final out = await b.toImage(pixelRatio: _outW / _frame.width);
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      Navigator.pop(context, data!.buffer.asUint8List());
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OpColors.ink,
      appBar: AppBar(
        backgroundColor: OpColors.ink,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Crop your photo'.tr, style: OpText.bodyStrong.copyWith(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(OpSpace.gutter),
          child: Column(
            children: [
              Text('Move and zoom so your face is in the middle.'.tr, style: OpText.small.copyWith(color: Colors.white70)),
              const SizedBox(height: 14),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  if (_failed) {
                    return Center(
                      child: Text('This photo could not be opened. Please choose another one.'.tr, style: OpText.body.copyWith(color: Colors.white), textAlign: TextAlign.center),
                    );
                  }
                  if (_image == null) return const Center(child: CircularProgressIndicator(color: Colors.white));
                  var w = box.maxWidth;
                  var h = w / _frameRatio;
                  if (h > box.maxHeight) {
                    h = box.maxHeight;
                    w = h * _frameRatio;
                  }
                  if (_frame != Size(w, h)) _layout(Size(w, h));
                  return Center(
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: Stack(
                        children: [
                          RepaintBoundary(
                            key: _boundary,
                            child: ClipRect(
                              child: InteractiveViewer(
                                transformationController: _ctl,
                                constrained: false,
                                minScale: 1,
                                maxScale: 6,
                                boundaryMargin: EdgeInsets.zero,
                                onInteractionUpdate: (_) {
                                  final z = _ctl.value.getMaxScaleOnAxis();
                                  if ((z - _zoom).abs() > 0.01) setState(() => _zoom = z.clamp(1, 6).toDouble());
                                },
                                child: SizedBox(width: _child.width, height: _child.height, child: RawImage(image: _image, fit: BoxFit.fill)),
                              ),
                            ),
                          ),
                          // The frame and the thirds grid sit above, so they are not part of the saved photo.
                          IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 1.5), borderRadius: BorderRadius.circular(2)),
                              child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.zoom_out, color: Colors.white70, size: 20),
                  Expanded(
                    child: Slider(
                      value: _zoom.clamp(1, 6).toDouble(),
                      min: 1,
                      max: 6,
                      activeColor: OpColors.leaf,
                      inactiveColor: Colors.white24,
                      onChanged: _image == null ? null : _setZoom,
                    ),
                  ),
                  const Icon(Icons.zoom_in, color: Colors.white70, size: 20),
                ],
              ),
              const SizedBox(height: 6),
              OpButton(label: 'Use this photo'.tr, loading: _saving, onPressed: _image == null || _saving ? null : _done),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white38
      ..strokeWidth = 0.8;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(size.width * i / 3, 0), Offset(size.width * i / 3, size.height), p);
      canvas.drawLine(Offset(0, size.height * i / 3), Offset(size.width, size.height * i / 3), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
