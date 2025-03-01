import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class TagDialog extends StatelessWidget {
  final List<Tag> selectedTags;
  final DatabaseHelper db;

  const TagDialog({
    super.key,
    required this.selectedTags,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    final textController = TextEditingController();

    return AlertDialog(
      title: const Text('Add Tag'),
      content: FutureBuilder<List<Tag>>(
        future: db.getAllTags(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();

          final availableTags = snapshot.data!.where(
            (tag) => !selectedTags.any((selected) => selected.id == tag.id)
          ).toList();

          return Column(
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
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final name = textController.text.trim();
            if (name.isEmpty) return;

            final existingTags = await db.getAllTags();
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
            await db.createTag(tag);
            Navigator.pop(context, tag);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
} 