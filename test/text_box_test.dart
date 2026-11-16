import 'package:flutter/painting.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/canvas/_asset_cache.dart';
import 'package:saber/components/canvas/text/editor_text_box.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/page.dart';

void main() {
  EditorTextBox createBox({int id = 1}) => EditorTextBox.empty(
    id: id,
    pageIndex: 0,
    rect: const Rect.fromLTWH(10, 20, 200, 100),
  );

  group('EditorTextBox', () {
    test('has a minimum size', () {
      final box = createBox();
      box.rect = const Rect.fromLTWH(0, 0, 5, 5);
      expect(box.rect.width, EditorTextBox.minSize);
      expect(box.rect.height, EditorTextBox.minSize);
    });

    test('normalizes links', () {
      expect(EditorTextBox.normalizeUrl(null), isNull);
      expect(EditorTextBox.normalizeUrl('   '), isNull);
      expect(EditorTextBox.normalizeUrl('example.com'), 'https://example.com');
      expect(EditorTextBox.normalizeUrl('http://a.b'), 'http://a.b');
      expect(EditorTextBox.normalizeUrl('mailto:a@b.c'), 'mailto:a@b.c');
    });

    test('only saves non-default state', () {
      final json = createBox().toJson();
      expect(json.keys, containsAll(['id', 'x', 'y', 'w', 'h']));
      expect(json.keys, isNot(contains('q')));
      expect(json.keys, isNot(contains('lk')));
      expect(json.keys, isNot(contains('o')));
      expect(json.keys, isNot(contains('u')));
    });

    test('survives a JSON round trip', () {
      final box = createBox(id: 7)
        ..locked = true
        ..opacity = 0.5
        ..link = 'example.com';
      box.quill.controller.document.insert(0, 'hello');
      box.quill.controller.document.format(0, 5, LinkAttribute('https://a.b'));

      final copy = EditorTextBox.fromJson(box.toJson(), pageIndex: 3);
      expect(copy.id, 7);
      expect(copy.pageIndex, 3);
      expect(copy.rect, box.rect);
      expect(copy.locked, true);
      expect(copy.opacity, 0.5);
      expect(copy.link, 'https://example.com');
      expect(copy.quill.controller.document.toPlainText(), 'hello\n');
      expect(
        copy.quill.controller.document.toDelta().toJson(),
        box.quill.controller.document.toDelta().toJson(),
      );
    });

    test('a page keeps its text boxes in order when saved and loaded', () {
      final page = EditorPage();
      expect(page.isEmpty, true);
      page.textBoxes.add(createBox(id: 1));
      page.textBoxes.add(createBox(id: 2));
      expect(page.isEmpty, false);

      final json = page.toJson(OrderedAssetCache());
      final loaded = EditorPage.fromJson(
        json,
        inlineAssets: null,
        readOnly: false,
        fileVersion: EditorCoreInfo.sbnVersion,
        sbnPath: '/test',
        assetCache: AssetCache(),
      );
      expect(loaded.textBoxes.map((b) => b.id), [1, 2]);
    });

    test('a page without text boxes does not write the key', () {
      final json = EditorPage().toJson(OrderedAssetCache());
      expect(json.containsKey('tb'), false);
    });
  });
}
