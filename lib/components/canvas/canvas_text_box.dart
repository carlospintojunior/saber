import 'dart:math';

import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/canvas/canvas_image.dart';
import 'package:saber/components/canvas/canvas_text_box_dialog.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/components/canvas/text/editor_text_box.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/data/extensions/change_notifier_extensions.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:url_launcher/url_launcher.dart';

/// How a [CanvasTextBox] reacts to touches.
enum TextBoxMode {
  /// A drawing tool is active (or the page is being exported):
  /// the box only displays its content.
  inert,

  /// The note is read-only: links work, nothing can be changed.
  view,

  /// The select tool is active: links work and the box can be moved,
  /// resized and configured.
  select,

  /// The text tool is active: the text can be edited, and the box can be
  /// moved, resized and configured.
  edit,
}

class CanvasTextBox extends StatefulWidget {
  new({
    required this.filePath,
    required this.box,
    required this.mode,
    required this.pageSize,
    required this.customStyles,
    required this.invert,
    this.reorderTextBox,
  }) : super(key: Key('CanvasTextBox$filePath/${box.pageIndex}/${box.id}'));

  final String filePath;
  final EditorTextBox box;
  final TextBoxMode mode;
  final Size pageSize;
  final DefaultStyles customStyles;
  final bool invert;

  /// Moves the box in front of or behind the other boxes on its page.
  final void Function(EditorTextBox box, ImageOrder order)? reorderTextBox;

  /// When notified, all [CanvasTextBox]es will be de-activated.
  static var activeListener = ChangeNotifier();

  /// The size of the circles used to resize a box.
  static const double handleSize = 32;

  @override
  State<CanvasTextBox> createState() => _CanvasTextBoxState();
}

class _CanvasTextBoxState extends State<CanvasTextBox> {
  var _active = false;

  /// Whether this box shows its resize handles.
  bool get active => _active;
  set active(bool value) {
    if (_active == value) return;

    if (value) {
      // de-activate all other boxes
      CanvasTextBox.activeListener.notifyListenersPlease();
    }

    _active = value;
    if (mounted) {
      try {
        setState(() {});
      } catch (e) {
        // setState throws if the widget is currently building
      }
    }
  }

  final _scrollController = ScrollController();

  Rect dragStartRect = .zero;
  Offset dragTotal = .zero;

  bool get _controlsVisible => widget.mode == .select || widget.mode == .edit;

  @override
  void initState() {
    super.initState();

    widget.box.quill.focusNode.addListener(_onFocusChange);
    CanvasTextBox.activeListener.addListener(_disableActive);
    CanvasImage.activeListener.addListener(_disableActive);
    _syncReadOnly();

    if (widget.box.isNew) {
      widget.box.isNew = false;
      _active = true;
      if (widget.mode == .edit) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.box.quill.focusNode.requestFocus();
        });
      }
    }
  }

  @override
  void didUpdateWidget(CanvasTextBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) _syncReadOnly();
  }

  void _disableActive() => active = false;

  void _onFocusChange() {
    if (widget.box.quill.focusNode.hasFocus) active = true;
  }

  /// Quill only follows links when it is read-only.
  void _syncReadOnly() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = widget.box.quill.controller;
      final readOnly = widget.mode != .edit;
      if (controller.readOnly != readOnly) controller.readOnly = readOnly;
    });
  }

  @override
  void dispose() {
    try {
      widget.box.quill.focusNode.removeListener(_onFocusChange);
    } catch (_) {
      // the focus node was already disposed (e.g. a screenshot clone)
    }
    CanvasTextBox.activeListener.removeListener(_disableActive);
    CanvasImage.activeListener.removeListener(_disableActive);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openLink() async {
    final link = widget.box.link;
    if (link == null) return;
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // nothing to do if no app can open the link
    }
  }

  void _showOptions() {
    showDialog(
      context: context,
      builder: (context) => AdaptiveAlertDialog(
        title: Text(t.editor.textBoxOptions.title),
        content: CanvasTextBoxDialog(
          box: widget.box,
          reorderTextBox: widget.reorderTextBox == null
              ? null
              : (order) => widget.reorderTextBox!(widget.box, order),
        ),
        actions: const [],
      ),
    );
  }

  void _endDrag() {
    final box = widget.box;
    if (dragStartRect != .zero && dragStartRect != box.rect) {
      box.onMove?.call(box, dragStartRect, box.rect);
    }
    dragStartRect = .zero;
    dragTotal = .zero;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final box = widget.box;

    return ListenableBuilder(
      listenable: box,
      builder: (context, _) {
        if (box.locked) _active = false;
        final rect = box.rect;
        final showHandles = _controlsVisible && active && !box.locked;
        final borderColor = colorScheme.onSurface;

        final editor = QuillEditor(
          controller: box.quill.controller,
          focusNode: box.quill.focusNode,
          scrollController: _scrollController,
          config: QuillEditorConfig(
            customStyles: widget.customStyles,
            scrollable: false,
            autoFocus: false,
            expands: true,
            placeholder: widget.mode == .edit
                ? t.editor.quill.typeSomething
                : null,
            showCursor: widget.mode == .edit,
            keyboardAppearance: widget.invert ? .dark : .light,
            padding: const EdgeInsets.all(8),
            showCodeBlockLineNumbers: false,
          ),
        );

        return Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: box.opacity,
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _controlsVisible
                            ? borderColor.withValues(alpha: active ? 0.9 : 0.25)
                            : Colors.transparent,
                        width: active ? 2 : 1,
                      ),
                    ),
                    child: ClipRect(
                      child: IgnorePointer(
                        ignoring: widget.mode == .inert,
                        child: editor,
                      ),
                    ),
                  ),
                ),
              ),
              if (box.link != null)
                Positioned(
                  top: 2,
                  right: 2,
                  child: IgnorePointer(
                    ignoring: widget.mode == .inert,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _openLink,
                      child: Tooltip(
                        message: box.link!,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.85),
                            shape: .circle,
                          ),
                          child: Icon(
                            Icons.link,
                            size: 16,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_controlsVisible) _buildGrip(context, rect),
              if (showHandles)
                for (double x = -1; x <= 1; x++)
                  for (double y = -1; y <= 1; y++)
                    if (x != 0 || y != 0)
                      _TextBoxResizeHandle(position: Offset(x, y), parent: this),
            ],
          ),
        );
      },
    );
  }

  /// A small bar to move the box (drag), activate it (tap),
  /// and open its options.
  Widget _buildGrip(BuildContext context, Rect rect) {
    final colorScheme = ColorScheme.of(context);
    final box = widget.box;
    const height = 28.0;

    // keep the grip inside the page when the box is at the top
    final top = rect.top < height + 4 ? 2.0 : -height - 2;

    return Positioned(
      top: top,
      left: 0,
      child: DeferPointer(
        paintOnTop: true,
        child: Material(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
          elevation: 2,
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MouseRegion(
                  cursor: box.locked
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.grab,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: box.locked ? null : () => active = !active,
                    onLongPress: _showOptions,
                    onSecondaryTap: _showOptions,
                    onPanStart: box.locked
                        ? null
                        : (details) {
                            active = true;
                            dragStartRect = box.rect;
                            dragTotal = .zero;
                          },
                    onPanUpdate: box.locked
                        ? null
                        : (details) {
                            dragTotal += details.delta;
                            final margin = min(
                              widget.pageSize.width * 0.05,
                              widget.pageSize.height * 0.05,
                            );
                            final start = dragStartRect;
                            box.rect = Rect.fromLTWH(
                              (start.left + dragTotal.dx)
                                  .clamp(
                                    margin - start.width,
                                    widget.pageSize.width - margin,
                                  )
                                  .toDouble(),
                              (start.top + dragTotal.dy)
                                  .clamp(
                                    margin - start.height,
                                    widget.pageSize.height - margin,
                                  )
                                  .toDouble(),
                              start.width,
                              start.height,
                            );
                          },
                    onPanEnd: box.locked ? null : (_) => _endDrag(),
                    onPanCancel: box.locked ? null : _endDrag,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        box.locked ? Icons.lock : Icons.drag_indicator,
                        size: 18,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _showOptions,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.more_horiz,
                      size: 18,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextBoxResizeHandle extends StatelessWidget {
  const new({required this.position, required this.parent});

  /// Each component is -1, 0 or 1: which edge(s) this handle moves.
  final Offset position;
  final _CanvasTextBoxState parent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final box = parent.widget.box;
    const size = CanvasTextBox.handleSize;
    final rect = box.rect;

    return Positioned(
      left: (position.dx + 1) / 2 * rect.width - size / 2,
      top: (position.dy + 1) / 2 * rect.height - size / 2,
      child: DeferPointer(
        paintOnTop: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            parent.dragStartRect = box.rect;
            parent.dragTotal = .zero;
          },
          onPanUpdate: (details) {
            parent.dragTotal += details.delta;
            final start = parent.dragStartRect;
            final delta = parent.dragTotal;

            var left = start.left, top = start.top;
            var right = start.right, bottom = start.bottom;
            if (position.dx < 0) left += delta.dx;
            if (position.dx > 0) right += delta.dx;
            if (position.dy < 0) top += delta.dy;
            if (position.dy > 0) bottom += delta.dy;

            // never smaller than the minimum, keeping the opposite edge fixed
            const minSize = EditorTextBox.minSize;
            if (right - left < minSize) {
              if (position.dx < 0) {
                left = right - minSize;
              } else {
                right = left + minSize;
              }
            }
            if (bottom - top < minSize) {
              if (position.dy < 0) {
                top = bottom - minSize;
              } else {
                bottom = top + minSize;
              }
            }

            box.rect = Rect.fromLTRB(left, top, right, bottom);
          },
          onPanEnd: (_) => parent._endDrag(),
          onPanCancel: parent._endDrag,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            child: Container(
              width: size / 2,
              height: size / 2,
              decoration: BoxDecoration(
                color: colorScheme.onSurface,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
