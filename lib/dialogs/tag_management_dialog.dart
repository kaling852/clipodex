import 'package:clipodex/models/tag.dart';
import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class TagManagementDialog extends StatefulWidget {
  final DatabaseHelper db;
  final Function(Tag tag) onRename;
  final Function(String tagId) onDelete;

  const TagManagementDialog({
    super.key,
    required this.db,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<TagManagementDialog> createState() => _TagManagementDialogState();
}

class _TagManagementDialogState extends State<TagManagementDialog> {
  List<Tag> _allTags = [];
  Map<String, int> _tagUsage = {};

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final allTags = await widget.db.getAllTags();
    final tagUsage = <String, int>{};
    
    await Future.wait(
      allTags.map((tag) => widget.db.getClipsWithTag(tag.id)
        .then((clips) => tagUsage[tag.id] = clips.length)
      ),
    );
    
    setState(() {
      _allTags = allTags;
      _tagUsage = tagUsage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.5,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Manage Tags', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ..._allTags.map((tag) {
                      final useCount = _tagUsage[tag.id] ?? 0;
                      return ListTile(
                        title: Text('#${tag.name}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$useCount clips', 
                              style: TextStyle(
                                color: useCount == 0 ? Colors.red : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showTagRenameDialog(tag),
                              tooltip: 'Rename Tag',
                            ),
                            if (useCount == 0)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () => _confirmDeleteTag(tag),
                                tooltip: 'Delete Unused Tag',
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTagRenameDialog(Tag tag) async {
    final textController = TextEditingController(text: tag.name);
    final existingTags = await widget.db.getAllTags();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'New Tag Name',
              ),
              autofocus: true,
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
              final newName = textController.text.trim();
              if (newName.isEmpty) return;

              // Check for duplicate names
              if (existingTags.any((t) => 
                t.id != tag.id && 
                t.name.toLowerCase() == newName.toLowerCase()
              )) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Tag "$newName" already exists')),
                );
                return;
              }

              final updatedTag = Tag(
                id: tag.id,
                name: newName,
              );
              await widget.db.renameTag(tag.id, newName);
              Navigator.pop(context);
              widget.onRename(updatedTag);
              _loadTags(); // Refresh the tag list
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTag(Tag tag) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag'),
        content: Text('Are you sure you want to delete the tag "#${tag.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await widget.db.deleteTag(tag.id);
              Navigator.pop(context); // Close confirmation dialog
              widget.onDelete(tag.id);
              _loadTags(); // Refresh the tag list
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
} 