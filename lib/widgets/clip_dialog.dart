import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class ClipDialog extends StatefulWidget {
  final ClipItem? clip;  // null for new clip, existing clip for edit
  final DatabaseHelper db;
  final Function onSave;  // Callback when clip is saved

  const ClipDialog({
    super.key,
    this.clip,
    required this.db,
    required this.onSave,
  });

  @override
  State<ClipDialog> createState() => _ClipDialogState();
}

class _ClipDialogState extends State<ClipDialog> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final selectedTags = <Tag>[];

  @override
  void initState() {
    super.initState();
    titleController.text = widget.clip?.title ?? '';
    contentController.text = widget.clip?.content ?? '';
    _loadExistingTags();
  }

  Future<void> _loadExistingTags() async {
    if (widget.clip != null) {
      final tags = await widget.db.getTagsForClip(widget.clip!.id);
      setState(() {
        selectedTags.addAll(tags);
      });
    }
  }

  Future<Tag?> _showTagDialog() async {
    final textController = TextEditingController();
    final existingTags = await widget.db.getAllTags();
    
    final availableTags = existingTags.where(
      (tag) => !selectedTags.any((selected) => selected.id == tag.id)
    ).toList();

    return showDialog<Tag>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Tag Name',
                hintText: 'Enter new tag name',
              ),
            ),
            if (availableTags.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Or select existing tag:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: availableTags.map((tag) => ActionChip(
                  label: Text(tag.name),
                  onPressed: () => Navigator.pop(context, tag),
                )).toList(),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                if (existingTags.any((t) => t.name.toLowerCase() == name.toLowerCase())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tag "$name" already exists')),
                  );
                  return;
                }
                
                if (existingTags.length >= 15) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Maximum number of tags (15) reached')),
                  );
                  return;
                }
                
                final tag = Tag(
                  id: DateTime.now().toString(),
                  name: name,
                );
                await widget.db.createTag(tag);
                Navigator.pop(context, tag);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          Wrap(
            spacing: 8,
            children: selectedTags.map((tag) => Chip(
              label: Text(tag.name),
              onDeleted: () => setState(() => selectedTags.remove(tag)),
            )).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final title = titleController.text.trim();
            final content = contentController.text.trim();
            
            if (title.isNotEmpty && content.isNotEmpty) {
              await widget.onSave(title, content, selectedTags);
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
} 