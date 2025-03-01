import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class TagManagementDialog extends StatefulWidget {
  final DatabaseHelper db;

  const TagManagementDialog({
    super.key,
    required this.db,
  });

  @override
  State<TagManagementDialog> createState() => _TagManagementDialogState();
}

class _TagManagementDialogState extends State<TagManagementDialog> {
  Map<String, int> tagUsage = {};

  @override
  void initState() {
    super.initState();
    _loadTagUsage();
  }

  Future<void> _loadTagUsage() async {
    final allTags = await widget.db.getAllTags();
    final usage = <String, int>{};
    
    for (var tag in allTags) {
      final clips = await widget.db.getClipsWithTag(tag.id);
      usage[tag.id] = clips.length;
    }

    setState(() {
      tagUsage = usage;
    });
  }

  Future<void> _showRenameDialog(Tag tag) async {
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

              if (existingTags.any((t) => 
                t.id != tag.id && 
                t.name.toLowerCase() == newName.toLowerCase()
              )) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Tag "$newName" already exists')),
                );
                return;
              }

              await widget.db.renameTag(tag.id, newName);
              Navigator.pop(context);
              setState(() {}); // Refresh the list
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Tags'),
      content: FutureBuilder<List<Tag>>(
        future: widget.db.getAllTags(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allTags = snapshot.data!;
          if (allTags.isEmpty) {
            return const Text('No tags created yet');
          }

          // Sort tags by usage count (descending) and then alphabetically
          final sortedTags = List<Tag>.from(allTags)
            ..sort((a, b) {
              final aCount = tagUsage[a.id] ?? 0;
              final bCount = tagUsage[b.id] ?? 0;
              if (aCount != bCount) {
                return bCount.compareTo(aCount); // Sort by count descending
              }
              return a.name.compareTo(b.name); // Then alphabetically
            });

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...sortedTags.map((tag) {
                  final useCount = tagUsage[tag.id] ?? 0;
                  return ListTile(
                    title: Text('#${tag.name}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$useCount clips', 
                          style: TextStyle(
                            color: useCount == 0 ? Colors.red : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showRenameDialog(tag),
                          tooltip: 'Rename Tag',
                        ),
                        if (useCount == 0)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () async {
                              await widget.db.deleteTag(tag.id);
                              setState(() {}); // Refresh the list
                            },
                            tooltip: 'Delete Unused Tag',
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
} 