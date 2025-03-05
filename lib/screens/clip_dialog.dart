import 'package:flutter/material.dart';

class ClipDialog extends StatefulWidget {
  final Clip? clip;

  const ClipDialog({Key? key, this.clip}) : super(key: key);

  @override
  _ClipDialogState createState() => _ClipDialogState();
}

class _ClipDialogState extends State<ClipDialog> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();
  bool isMasked = false;
  List<String> selectedTags = [];

  @override
  void initState() {
    super.initState();
    if (widget.clip != null) {
      if (widget.clip!.isMasked) {
        // Don't allow editing of masked clips
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Masked clips cannot be edited')),
        );
        return;
      }
      titleController.text = widget.clip!.title;
      contentController.text = widget.clip!.content;
      isMasked = widget.clip!.isMasked;
      selectedTags = widget.clip!.tags.toList();
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  Future<String?> _showTagDialog() async {
    final tag = await showDialog<String>(
      context: context,
      builder: (context) => TagDialog(),
    );
    return tag;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.clip?.isMasked ?? false) {
      return const SizedBox.shrink(); // Don't show dialog for masked clips
    }
    return AlertDialog(
      title: Text(widget.clip != null ? 'Edit Clip' : 'Add New Clip'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: contentController,
            decoration: const InputDecoration(labelText: 'Content'),
            maxLines: 3,
          ),
          if (widget.clip == null) ...[  // Only show mask option for new clips
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: isMasked,
                  onChanged: (value) => setState(() => isMasked = value ?? false),
                ),
                const Text('Mask Content (Cannot be edited later)'),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Tags (${selectedTags.length}/3):'),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: selectedTags.length >= 3 ? null : () async {
                  final tag = await _showTagDialog();
                  if (tag != null && selectedTags.length < 3) {
                    setState(() => selectedTags.add(tag));
                  }
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(Clip(
            title: titleController.text,
            content: contentController.text,
            isMasked: isMasked,
            tags: selectedTags,
          )),
          child: const Text('Save'),
        ),
      ],
    );
  }
} 