import 'dart:math';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/data/editor/page.dart' show QuillStruct;

/// A movable, resizable text box on a page.
///
/// Each text box has its own Quill document, so text inside it can have
/// links on individual words ([QuillStruct.controller]) and the box as a
/// whole can also be a link ([link]).
///
/// This is listenable for changes to the box's position ([rect]).
class EditorTextBox extends ChangeNotifier {
  /// The smallest width or height of a text box.
  static const double minSize = 40;

  /// id for this box, unique within a page.
  int id;

  int pageIndex;

  final QuillStruct quill;

  /// Called after the user finishes moving or resizing the box,
  /// with the rects from before and after.
  void Function(EditorTextBox box, Rect before, Rect after)? onMove;

  /// Called when the user chooses to delete the box.
  void Function(EditorTextBox box)? onDelete;

  /// Called after a change that is saved but not part of the undo history
  /// (lock, opacity, link, layer order).
  void Function()? onMiscChange;

  /// If the box is new, it will be active (movable) and focused when built.
  var isNew = false;

  Rect _rect;
  Rect get rect => _rect;
  set rect(Rect rect) {
    _rect = Rect.fromLTWH(
      rect.left,
      rect.top,
      max(rect.width, minSize),
      max(rect.height, minSize),
    );
    notifyListeners();
  }

  /// Whether the box is protected from being moved or resized.
  var _locked = false;
  bool get locked => _locked;
  set locked(bool locked) {
    if (_locked == locked) return;
    _locked = locked;
    notifyListeners();
    onMiscChange?.call();
  }

  double _opacity = 1;

  /// From 0 (invisible) to 1 (opaque).
  double get opacity => _opacity;
  set opacity(double opacity) {
    _opacity = opacity.clamp(0.0, 1.0);
    notifyListeners();
  }

  String? _link;

  /// A URL that opens when the whole box is tapped, or null.
  String? get link => _link;
  set link(String? link) {
    final normalized = normalizeUrl(link);
    if (_link == normalized) return;
    _link = normalized;
    notifyListeners();
    onMiscChange?.call();
  }

  new({
    required this.id,
    required this.pageIndex,
    required Rect rect,
    required this.quill,
    bool locked = false,
    double opacity = 1,
    String? link,
    this.isNew = false,
  }) : _rect = Rect.fromLTWH(
         rect.left,
         rect.top,
         max(rect.width, minSize),
         max(rect.height, minSize),
       ),
       _locked = locked,
       _opacity = opacity.clamp(0.0, 1.0),
       _link = normalizeUrl(link);

  /// Creates an empty box.
  factory empty({
    required int id,
    required int pageIndex,
    required Rect rect,
  }) => EditorTextBox(
    id: id,
    pageIndex: pageIndex,
    rect: rect,
    quill: QuillStruct(
      controller: QuillController.basic(),
      focusNode: FocusNode(debugLabel: 'Text Box Focus Node'),
    ),
    isNew: true,
  );

  factory fromJson(Map<String, dynamic> json, {required int pageIndex}) {
    final q = json['q'];
    return EditorTextBox(
      id: (json['id'] as int?) ?? 0,
      pageIndex: pageIndex,
      rect: Rect.fromLTWH(
        ((json['x'] as num?) ?? 0).toDouble(),
        ((json['y'] as num?) ?? 0).toDouble(),
        ((json['w'] as num?) ?? 200).toDouble(),
        ((json['h'] as num?) ?? 80).toDouble(),
      ),
      quill: QuillStruct(
        controller: q is List
            ? QuillController(
                document: Document.fromJson(q),
                selection: const TextSelection.collapsed(offset: 0),
              )
            : QuillController.basic(),
        focusNode: FocusNode(debugLabel: 'Text Box Focus Node'),
      ),
      locked: json['lk'] as bool? ?? false,
      opacity: ((json['o'] as num?) ?? 1).toDouble(),
      link: json['u'] as String?,
    );
  }

  /// Only non-default values are written, so the .sbn stays small.
  Map<String, dynamic> toJson() => {
    'id': id,
    'x': rect.left,
    'y': rect.top,
    'w': rect.width,
    'h': rect.height,
    if (!quill.controller.document.isEmpty())
      'q': quill.controller.document.toDelta().toJson(),
    if (locked) 'lk': true,
    if (opacity != 1) 'o': opacity,
    if (link != null) 'u': link,
  };

  EditorTextBox copy() => EditorTextBox(
    id: id,
    pageIndex: pageIndex,
    rect: rect,
    quill: QuillStruct(
      controller: QuillController(
        document: Document.fromDelta(quill.controller.document.toDelta()),
        selection: const TextSelection.collapsed(offset: 0),
      ),
      focusNode: FocusNode(debugLabel: 'Text Box Focus Node'),
    ),
    locked: locked,
    opacity: opacity,
    link: link,
  );

  /// Clone with its own Quill, to avoid attaching one controller
  /// to two editors while rasterizing the page.
  EditorTextBox cloneForScreenshot() => EditorTextBox(
    id: id,
    pageIndex: pageIndex,
    rect: rect,
    quill: quill.cloneForScreenshot(),
    locked: locked,
    opacity: opacity,
    link: link,
  );

  /// Whether the box has no text.
  bool get isTextEmpty => quill.controller.document.isEmpty();

  /// Adds `https://` when [url] has no scheme. Returns null for blank input.
  static String? normalizeUrl(String? url) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.contains('://') || trimmed.startsWith('mailto:')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  @override
  void dispose() {
    quill.dispose();
    super.dispose();
  }
}
