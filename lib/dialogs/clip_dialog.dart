import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../models/tag.dart';
import '../models/clip_item.dart';

class ClipDialog extends StatefulWidget {
  final ClipItem? clip;
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
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  List<Tag> _selectedTags = [];
  bool _isMasked = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.clip?.title ?? '');
    _contentController = TextEditingController(text: widget.clip?.content ?? '');
    _isMasked = widget.clip?.isMasked ?? false;
    _loadTags();
  }

  Future<void> _loadTags() async {
    if (widget.clip != null) {
      final tags = await widget.db.getTagsForClip(widget.clip!.id);
      setState(() => _selectedTags = tags);
    }
  }

  Future<Tag?> _showTagDialog() async {
    final textController = TextEditingController();
    final existingTags = await widget.db.getAllTags();
    
    // Check if this clip already has 3 tags
    if (_selectedTags.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum number of tags per clip (3) reached')),
      );
      return null;
    }
    
    final availableTags = existingTags.where(
      (tag) => !_selectedTags.any((selected) => selected.id == tag.id)
    ).toList();

    return showDialog<Tag>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (existingTags.length < 15) TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Tag Name',
                hintText: 'Enter new tag name',
              ),
            ),
            if (availableTags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(existingTags.length >= 15 ? 'Select existing tag:' : 'Or select existing tag:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
          if (existingTags.length < 15) FilledButton(
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                if (existingTags.any((t) => t.name.toLowerCase() == name.toLowerCase())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tag "$name" already exists')),
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
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.clip == null ? 'New Clip' : 'Edit Clip',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Enter clip title',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: 'Content',
                        hintText: 'Enter clip content',
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        ..._selectedTags.map((tag) => Chip(
                          label: Text(tag.name),
                          onDeleted: () => setState(() => _selectedTags.remove(tag)),
                        )),
                        ActionChip(
                          label: const Text('Add Tag'),
                          onPressed: _selectedTags.length >= 3 ? null : () async {
                            final tag = await _showTagDialog();
                            if (tag != null) {
                              setState(() => _selectedTags.add(tag));
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
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
                    final title = _titleController.text.trim();
                    final content = _contentController.text.trim();
                    if (title.isNotEmpty && content.isNotEmpty) {
                      widget.onSave(title, content, _selectedTags, _isMasked);
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