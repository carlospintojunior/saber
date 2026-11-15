import 'package:material_ui/material_ui.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/i18n/strings.g.dart';

/// Asks the user which part of [image] to keep.
///
/// Returns the new crop as fractions (0 to 1) of the whole image,
/// or null if the user cancelled.
Future<Rect?> showCanvasImageCropDialog(
  BuildContext context, {
  required EditorImage image,
}) {
  return showDialog<Rect>(
    context: context,
    builder: (context) => _CanvasImageCropDialog(image: image),
  );
}

/// The edges of a crop rectangle that a drag moves.
@visibleForTesting
enum CropEdges {
  topLeft(movesLeft: true, movesTop: true),
  top(movesTop: true),
  topRight(movesRight: true, movesTop: true),
  left(movesLeft: true),
  right(movesRight: true),
  bottomLeft(movesLeft: true, movesBottom: true),
  bottom(movesBottom: true),
  bottomRight(movesRight: true, movesBottom: true),

  /// Moves the whole rectangle without resizing it.
  all();

  new({
    this.movesLeft = false,
    this.movesTop = false,
    this.movesRight = false,
    this.movesBottom = false,
  });

  final bool movesLeft, movesTop, movesRight, movesBottom;
}

/// Drags [edges] of [crop] by [delta] (in fractions of the whole image).
///
/// The result stays inside [EditorImage.fullCrop] and is never smaller
/// than [minSize] along either axis.
@visibleForTesting
Rect dragCrop(
  Rect crop,
  CropEdges edges,
  Offset delta, {
  double minSize = 0.05,
}) {
  if (edges == CropEdges.all) {
    final dx = delta.dx.clamp(-crop.left, 1 - crop.right);
    final dy = delta.dy.clamp(-crop.top, 1 - crop.bottom);
    return crop.shift(Offset(dx, dy));
  }

  var left = crop.left,
      top = crop.top,
      right = crop.right,
      bottom = crop.bottom;
  if (edges.movesLeft) left = (left + delta.dx).clamp(0.0, right - minSize);
  if (edges.movesRight) right = (right + delta.dx).clamp(left + minSize, 1.0);
  if (edges.movesTop) top = (top + delta.dy).clamp(0.0, bottom - minSize);
  if (edges.movesBottom) bottom = (bottom + delta.dy).clamp(top + minSize, 1.0);
  return Rect.fromLTRB(left, top, right, bottom);
}

class _CanvasImageCropDialog extends StatefulWidget {
  const new({required this.image});

  final EditorImage image;

  @override
  State<_CanvasImageCropDialog> createState() => _CanvasImageCropDialogState();
}

class _CanvasImageCropDialogState extends State<_CanvasImageCropDialog> {
  /// How close (in logical pixels) a touch must be to an edge to grab it.
  static const _grabDistance = 28.0;

  late var crop = widget.image.crop;
  CropEdges? dragging;

  CropEdges _edgesAt(Offset position, Size size) {
    final rect = Rect.fromLTRB(
      crop.left * size.width,
      crop.top * size.height,
      crop.right * size.width,
      crop.bottom * size.height,
    );
    final nearLeft = (position.dx - rect.left).abs() < _grabDistance;
    final nearRight = (position.dx - rect.right).abs() < _grabDistance;
    final nearTop = (position.dy - rect.top).abs() < _grabDistance;
    final nearBottom = (position.dy - rect.bottom).abs() < _grabDistance;

    if (nearTop && nearLeft) return .topLeft;
    if (nearTop && nearRight) return .topRight;
    if (nearBottom && nearLeft) return .bottomLeft;
    if (nearBottom && nearRight) return .bottomRight;
    if (nearTop) return .top;
    if (nearBottom) return .bottom;
    if (nearLeft) return .left;
    if (nearRight) return .right;
    return .all;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final naturalSize = widget.image.naturalSize;
    final aspectRatio = naturalSize.isEmpty
        ? 1.0
        : naturalSize.width / naturalSize.height;

    return AlertDialog(
      title: Text(t.editor.imageOptions.crop),
      content: AspectRatio(
        aspectRatio: aspectRatio,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            return GestureDetector(
              onPanStart: (details) =>
                  dragging = _edgesAt(details.localPosition, size),
              onPanUpdate: (details) => setState(() {
                crop = dragCrop(
                  crop,
                  dragging ?? .all,
                  Offset(
                    details.delta.dx / size.width,
                    details.delta.dy / size.height,
                  ),
                );
              }),
              onPanEnd: (_) => dragging = null,
              child: Stack(
                fit: .expand,
                children: [
                  widget.image.buildImageWidget(
                    context: context,
                    overrideBoxFit: .fill,
                    isBackground: false,
                    invert: false,
                  ),
                  CustomPaint(
                    painter: _CropPainter(
                      crop: crop,
                      shade: Colors.black54,
                      border: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => crop = EditorImage.fullCrop),
          child: Text(t.editor.imageOptions.cropReset),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(crop),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}

/// Darkens everything outside of [crop] and outlines [crop].
class _CropPainter extends CustomPainter {
  const new({required this.crop, required this.shade, required this.border});

  final Rect crop;
  final Color shade, border;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      crop.left * size.width,
      crop.top * size.height,
      crop.right * size.width,
      crop.bottom * size.height,
    );
    final outside = Path()
      ..addRect(Offset.zero & size)
      ..addRect(rect)
      ..fillType = .evenOdd;
    canvas.drawPath(outside, Paint()..color = shade);
    canvas.drawRect(
      rect,
      Paint()
        ..color = border
        ..style = .stroke
        ..strokeWidth = 3,
    );
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      canvas.drawCircle(corner, 8, Paint()..color = border);
    }
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) =>
      crop != oldDelegate.crop ||
      shade != oldDelegate.shade ||
      border != oldDelegate.border;
}
