import 'package:material_ui/material_ui.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/components/canvas/text/editor_text_box.dart';
import 'package:saber/i18n/strings.g.dart';

/// The options of a text box: link, lock, opacity, layer order and delete.
class CanvasTextBoxDialog extends StatefulWidget {
  const new({super.key, required this.box, this.reorderTextBox});

  final EditorTextBox box;

  /// Moves the box in front of or behind the other boxes.
  final void Function(ImageOrder order)? reorderTextBox;

  @override
  State<CanvasTextBoxDialog> createState() => _CanvasTextBoxDialogState();
}

class _CanvasTextBoxDialogState extends State<CanvasTextBoxDialog> {
  late final _linkController = TextEditingController(text: widget.box.link);

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  void _saveLink() {
    widget.box.link = _linkController.text;
    // show the normalized URL (e.g. with "https://" added)
    _linkController.text = widget.box.link ?? '';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.box;
    final reorder = widget.reorderTextBox;

    return SizedBox(
      width: 320,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _linkController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: t.editor.textBoxOptions.link,
                hintText: 'https://',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: _linkController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: t.editor.textBoxOptions.removeLink,
                        icon: const Icon(Icons.link_off),
                        onPressed: () {
                          _linkController.clear();
                          _saveLink();
                        },
                      ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _saveLink(),
              onTapOutside: (_) => _saveLink(),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                box.locked
                    ? t.editor.textBoxOptions.unlock
                    : t.editor.textBoxOptions.lock,
              ),
              secondary: Icon(box.locked ? Icons.lock : Icons.lock_open),
              value: box.locked,
              onChanged: (value) => setState(() => box.locked = value),
            ),
            Text(t.editor.textBoxOptions.opacity),
            Slider(
              value: box.opacity,
              min: 0.1,
              max: 1,
              onChanged: (value) => setState(() => box.opacity = value),
              onChangeEnd: (_) => box.onMiscChange?.call(),
            ),
            if (reorder != null)
              Wrap(
                spacing: 8,
                children: [
                  for (final (order, label, icon) in [
                    (
                      ImageOrder.toFront,
                      t.editor.textBoxOptions.bringToFront,
                      Icons.flip_to_front,
                    ),
                    (
                      ImageOrder.forward,
                      t.editor.textBoxOptions.bringForward,
                      Icons.arrow_upward,
                    ),
                    (
                      ImageOrder.backward,
                      t.editor.textBoxOptions.sendBackward,
                      Icons.arrow_downward,
                    ),
                    (
                      ImageOrder.toBack,
                      t.editor.textBoxOptions.sendToBack,
                      Icons.flip_to_back,
                    ),
                  ])
                    ActionChip(
                      avatar: Icon(icon, size: 18),
                      label: Text(label),
                      onPressed: () => reorder(order),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.delete),
                label: Text(t.editor.textBoxOptions.delete),
                style: TextButton.styleFrom(
                  foregroundColor: ColorScheme.of(context).error,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  box.onDelete?.call(box);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
