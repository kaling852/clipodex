import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class ClipDialog extends StatefulWidget {
  final ClipItem? clip;  // null for new clip, existing clip for edit
  final DatabaseHelper db;
  final Function(String title, String content, List<Tag> tags, bool isMasked) onSave;

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
  bool isMasked = false;

  @override
  void initState() {
    super.initState();
    if (widget.clip != null) {
      titleController.text = widget.clip!.title;
      contentController.text = widget.clip!.content;
      isMasked = widget.clip!.isMasked;
      _loadExistingTags();
    }
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
      barrierDismissible: false,  // Prevent tap outside to dismiss
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
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8, // Make dialog wider
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.clip != null ? 'Edit Clip' : 'Add New Clip',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 16),
            if (widget.clip?.isMasked ?? false) 
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: TextEditingController(text: '•' * 12),
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Content (Masked)',
                    ),
                    maxLines: 1,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      'Content cannot be edited in masked clips',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              )
            else
              TextField(
                controller: contentController,
                decoration: const InputDecoration(labelText: 'Content'),
                maxLines: 3,
              ),
            if (widget.clip == null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: isMasked,
                    onChanged: (value) => setState(() => isMasked = value ?? false),
                  ),
                  Expanded(
                    child: const Text('Mask Content (Cannot be modified later)'),
                  ),
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
            Wrap(
              spacing: 8,
              children: selectedTags.map((tag) => Chip(
                label: Text(tag.name),
                onDeleted: () => setState(() => selectedTags.remove(tag)),
              )).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final content = widget.clip?.isMasked ?? false 
                        ? widget.clip!.content
                        : contentController.text.trim();
                    
                    if (title.isNotEmpty && content.isNotEmpty) {
                      widget.onSave(title, content, selectedTags, isMasked);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 