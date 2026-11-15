import 'dart:convert';
import 'dart:typed_data';

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/canvas/canvas_image_crop_dialog.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/components/theming/adaptive_icon.dart';
import 'package:saber/components/theming/adaptive_switch.dart';
import 'package:saber/components/theming/saber_theme.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';

class CanvasImageDialog extends StatefulWidget {
  const new({
    super.key,
    required this.filePath,
    required this.image,
    required this.redrawImage,
    required this.isBackground,
    required this.toggleAsBackground,
    this.reorderImage,
    this.singleRow = false,
  });

  final String filePath;
  final EditorImage image;
  final VoidCallback redrawImage;

  final bool isBackground;
  final VoidCallback? toggleAsBackground;

  /// Moves the image in front of or behind the other images.
  /// Layer and transform options are hidden for background images
  /// and when this is null.
  final void Function(ImageOrder order)? reorderImage;

  final bool singleRow;

  @override
  State<CanvasImageDialog> createState() => _CanvasImageDialogState();
}

class _CanvasImageDialogState extends State<CanvasImageDialog> {
  void setInvertible([bool? value]) => setState(() {
    widget.image.invertible = value ?? !widget.image.invertible;
    widget.image.onMiscChange?.call();
    widget.redrawImage();
  });

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final image = widget.image;
    final showLayerOptions = !widget.isBackground;
    final children = <Widget>[
      if (showLayerOptions) ...[
        _CanvasImageDialogItem(
          onTap: () => setState(() {
            image.locked = !image.locked;
            image.onMiscChange?.call();
            widget.redrawImage();
          }),
          title: image.locked
              ? t.editor.imageOptions.unlock
              : t.editor.imageOptions.lock,
          child: Icon(image.locked ? Icons.lock_open : Icons.lock),
        ),
        if (!image.locked) ...[
          _CanvasImageDialogItem(
            onTap: () => setState(() {
              image.rotate(clockwise: false);
              widget.redrawImage();
            }),
            title: t.editor.imageOptions.rotateLeft,
            child: const Icon(Icons.rotate_left),
          ),
          _CanvasImageDialogItem(
            onTap: () => setState(() {
              image.rotate();
              widget.redrawImage();
            }),
            title: t.editor.imageOptions.rotateRight,
            child: const Icon(Icons.rotate_right),
          ),
          _CanvasImageDialogItem(
            onTap: () => setState(() {
              image.flip();
              widget.redrawImage();
            }),
            title: t.editor.imageOptions.flip,
            child: const Icon(Icons.flip),
          ),
          if (image is PngEditorImage)
            _CanvasImageDialogItem(
              onTap: () async {
                Navigator.of(context).pop();
                final newCrop = await showCanvasImageCropDialog(
                  context,
                  image: image,
                );
                if (newCrop == null) return;
                image.setCrop(newCrop);
                widget.redrawImage();
              },
              title: t.editor.imageOptions.crop,
              child: const Icon(Icons.crop),
            ),
        ],
        if (widget.reorderImage != null) ...[
          _CanvasImageDialogItem(
            onTap: () => widget.reorderImage!(.toFront),
            title: t.editor.imageOptions.bringToFront,
            child: const Icon(Icons.flip_to_front),
          ),
          _CanvasImageDialogItem(
            onTap: () => widget.reorderImage!(.forward),
            title: t.editor.imageOptions.bringForward,
            child: const Icon(Icons.arrow_upward),
          ),
          _CanvasImageDialogItem(
            onTap: () => widget.reorderImage!(.backward),
            title: t.editor.imageOptions.sendBackward,
            child: const Icon(Icons.arrow_downward),
          ),
          _CanvasImageDialogItem(
            onTap: () => widget.reorderImage!(.toBack),
            title: t.editor.imageOptions.sendToBack,
            child: const Icon(Icons.flip_to_back),
          ),
        ],
      ],
      MergeSemantics(
        child: _CanvasImageDialogItem(
          onTap: stows.editorAutoInvert.value ? setInvertible : null,
          title: t.editor.imageOptions.invertible,
          child: AdaptiveSwitch(
            value: widget.image.invertible,
            onChanged: stows.editorAutoInvert.value ? setInvertible : null,
            thumbIcon: WidgetStateProperty.all(
              widget.image.invertible
                  ? const Icon(Icons.invert_colors)
                  : const Icon(Icons.invert_colors_off),
            ),
          ),
        ),
      ),
      _CanvasImageDialogItem(
        onTap: () async {
          final filePathSanitized = widget.filePath.replaceAll(
            RegExp(r'[^a-zA-Z\d]'),
            '_',
          );
          final imageFileName =
              'image$filePathSanitized${widget.image.id}${widget.image.extension}';
          final Uint8List bytes;
          switch (widget.image) {
            case final PdfEditorImage image:
              bytes =
                  image.pdfBytes ??
                  await image.pdfFile?.readAsBytes() ??
                  (throw ArgumentError.value(
                    image,
                    'image',
                    'PDF image has no bytes or file',
                  ));
            case final SvgEditorImage image:
              bytes = switch (image.svgLoader) {
                (final SvgStringLoader loader) => utf8.encode(
                  loader.provideSvg(null),
                ),
                (final SvgFileLoader loader) => await loader.file.readAsBytes(),
                (_) => throw ArgumentError.value(
                  image.svgLoader,
                  'svgLoader',
                  'Unknown SVG loader type',
                ),
              };
            case final PngEditorImage image:
              if (image.imageProvider is MemoryImage) {
                bytes = (image.imageProvider as MemoryImage).bytes;
              } else if (image.imageProvider is FileImage) {
                bytes = await (image.imageProvider as FileImage).file
                    .readAsBytes();
              } else {
                throw ArgumentError.value(
                  image.imageProvider,
                  'imageProvider',
                  'Unknown image provider type',
                );
              }
          }
          if (!context.mounted) return;
          FileManager.exportFile(
            imageFileName,
            bytes,
            isImage: true,
            context: context,
          );
          Navigator.of(context).pop();
        },
        title: t.editor.imageOptions.download,
        child: const AdaptiveIcon(
          icon: Icons.download,
          cupertinoIcon: CupertinoIcons.arrow_down_circle_fill,
        ),
      ),
      _CanvasImageDialogItem(
        onTap: () {
          widget.toggleAsBackground?.call();
          Navigator.of(context).pop();
        },
        title: widget.isBackground
            ? t.editor.imageOptions.removeAsBackground
            : t.editor.imageOptions.setAsBackground,
        child: const AdaptiveIcon(
          icon: Icons.wallpaper,
          cupertinoIcon: CupertinoIcons.photo_fill_on_rectangle_fill,
        ),
      ),
      _CanvasImageDialogItem(
        onTap: () {
          widget.image.onDeleteImage?.call(widget.image);
          widget.redrawImage();
          Navigator.of(context).pop();
        },
        title: t.editor.imageOptions.delete,
        child: const AdaptiveIcon(
          icon: Icons.delete,
          cupertinoIcon: CupertinoIcons.trash_fill,
        ),
      ),
    ];

    final opacitySlider = showLayerOptions
        ? Row(
            children: [
              const Icon(Icons.opacity),
              Expanded(
                child: Slider(
                  value: image.opacity,
                  min: 0.1,
                  semanticFormatterCallback: (value) =>
                      '${t.editor.imageOptions.opacity} ${(value * 100).round()}%',
                  onChanged: (value) => setState(() {
                    image.opacity = value;
                    widget.redrawImage();
                  }),
                  onChangeEnd: (_) => image.onMiscChange?.call(),
                ),
              ),
            ],
          )
        : null;

    final gridView = GridView.count(
      crossAxisCount: widget.singleRow ? children.length : 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      children: children,
    );
    if (showLayerOptions) {
      // many options: let the grid scroll on small screens
      return SizedBox(
        width: 250,
        child: Column(
          mainAxisSize: .min,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: gridView,
              ),
            ),
            ?opacitySlider,
          ],
        ),
      );
    }
    // issues with intrinsic sizes with each type of dialog
    if (platform.isCupertino) {
      return AspectRatio(
        aspectRatio: widget.singleRow ? children.length / 1 : 2,
        child: gridView,
      );
    } else {
      return SizedBox(width: 250, child: gridView);
    }
  }
}

class _CanvasImageDialogItem extends StatelessWidget {
  const new({required this.onTap, required this.title, required this.child});

  final VoidCallback? onTap;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Material(
      color: colorScheme.primary.withValues(alpha: 0.05),
      borderRadius: const .all(.circular(8)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const .symmetric(horizontal: 8, vertical: 16),
          child: Column(
            children: [
              Expanded(child: child),
              Text(title, textAlign: .center),
            ],
          ),
        ),
      ),
    );
  }
}
