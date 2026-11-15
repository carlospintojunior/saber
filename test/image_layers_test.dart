import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/canvas/_asset_cache.dart';
import 'package:saber/components/canvas/canvas_image_crop_dialog.dart';
import 'package:saber/components/canvas/image/editor_image.dart';

void main() {
  late List<int> imageBytes;
  setUpAll(() async {
    imageBytes = await File('assets/icon/icon.png').readAsBytes();
  });

  PngEditorImage createImage() => PngEditorImage(
    id: 0,
    extension: '.png',
    imageProvider: MemoryImage(Uint8List.fromList(imageBytes)),
    pageIndex: 0,
    pageSize: const Size(1000, 1000),
    dstRect: const Rect.fromLTWH(100, 100, 200, 100),
    srcRect: const Rect.fromLTWH(0, 0, 200, 100),
    naturalSize: const Size(200, 100),
    onMoveImage: null,
    onDeleteImage: null,
    onMiscChange: null,
    assetCache: AssetCache(),
  );

  group('Image layer state', () {
    test('rotating swaps the size around the center', () {
      final image = createImage();
      image.rotate();
      expect(image.quarterTurns, 1);
      expect(image.dstRect.center, const Offset(200, 150));
      expect(image.dstRect.size, const Size(100, 200));

      image.rotate(clockwise: false);
      expect(image.quarterTurns, 0);
      expect(image.dstRect, const Rect.fromLTWH(100, 100, 200, 100));

      image.rotate(clockwise: false);
      expect(image.quarterTurns, 3);
    });

    test('cropping keeps the pixel scale and top-left corner', () {
      final image = createImage();
      image.setCrop(const Rect.fromLTRB(0, 0, 0.5, 0.5));
      expect(image.isCropped, true);
      expect(image.dstRect, const Rect.fromLTWH(100, 100, 100, 50));

      image.setCrop(EditorImage.fullCrop);
      expect(image.isCropped, false);
      expect(image.dstRect, const Rect.fromLTWH(100, 100, 200, 100));
    });

    test('cropping a rotated image crops the unrotated image', () {
      final image = createImage()..rotate();
      expect(image.dstRect.size, const Size(100, 200));

      image.setCrop(const Rect.fromLTRB(0, 0, 0.5, 1));
      expect(image.dstRect.size, const Size(100, 100));
    });

    test('default state is not saved', () {
      final json = createImage().toJson(OrderedAssetCache());
      for (final key in ['r', 'fl', 'o', 'lk', 'cl', 'ct', 'cr', 'cb']) {
        expect(json.containsKey(key), false, reason: key);
      }
    });

    test('state survives toJson, fromJson and copy', () {
      final image = createImage()
        ..quarterTurns = 3
        ..flipped = true
        ..opacity = 0.4
        ..locked = true
        ..crop = const Rect.fromLTRB(0.1, 0.2, 0.9, 0.8);

      final json = image.toJson(OrderedAssetCache());
      final loaded = EditorImage.fromJson(
        json..['b'] = imageBytes,
        inlineAssets: [Uint8List.fromList(imageBytes)],
        sbnPath: '',
        assetCache: AssetCache(),
      );
      final copied = image.copy();

      for (final other in [loaded, copied]) {
        expect(other.quarterTurns, 3);
        expect(other.flipped, true);
        expect(other.opacity, 0.4);
        expect(other.locked, true);
        expect(other.crop, const Rect.fromLTRB(0.1, 0.2, 0.9, 0.8));
      }
    });

    test('invalid saved values are sanitised', () {
      final json = createImage().toJson(OrderedAssetCache())
        ..['r'] = 6
        ..['o'] = 7
        ..['cl'] = 0.8
        ..['cr'] = 0.2;
      final loaded = EditorImage.fromJson(
        json,
        inlineAssets: [Uint8List.fromList(imageBytes)],
        sbnPath: '',
        assetCache: AssetCache(),
      );
      expect(loaded.quarterTurns, 2);
      expect(loaded.opacity, 1);
      expect(loaded.crop, EditorImage.fullCrop);
    });
  });

  group('dragCrop', () {
    const crop = Rect.fromLTRB(0.25, 0.25, 0.75, 0.75);

    test('moves a single edge', () {
      expect(
        dragCrop(crop, CropEdges.left, const Offset(0.1, 0.5)),
        const Rect.fromLTRB(0.35, 0.25, 0.75, 0.75),
      );
      expect(
        dragCrop(crop, CropEdges.bottom, const Offset(0.5, 0.1)),
        const Rect.fromLTRB(0.25, 0.25, 0.75, 0.85),
      );
    });

    test('moves a corner', () {
      final result = dragCrop(crop, CropEdges.topLeft, const Offset(-0.1, 0.1));
      expect(result.left, closeTo(0.15, 1e-9));
      expect(result.top, closeTo(0.35, 1e-9));
      expect(result.right, 0.75);
    });

    test('stays inside the image', () {
      expect(
        dragCrop(crop, CropEdges.topLeft, const Offset(-1, -1)),
        const Rect.fromLTRB(0, 0, 0.75, 0.75),
      );
      expect(
        dragCrop(crop, CropEdges.all, const Offset(1, 1)),
        const Rect.fromLTRB(0.5, 0.5, 1, 1),
      );
    });

    test('cannot become smaller than the minimum size', () {
      final result = dragCrop(crop, CropEdges.left, const Offset(1, 0));
      expect(result.width, closeTo(0.05, 1e-9));
      expect(result.right, 0.75);
    });
  });
}
