import 'package:clipodex/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // Add this import for Clipboard
import '../data/database_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<ClipItem> _clips = [];
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadClips();
  }

  Future<void> _loadClips() async {
    final clips = await _db.getAllClips();
    setState(() {
      _clips = clips;
    });
  }

  Future<void> _showClipDialog({ClipItem? clip}) async {
    // If clip is provided, we're editing, otherwise we're adding
    final bool isEditing = clip != null;
    final titleController = TextEditingController(text: clip?.title);
    final contentController = TextEditingController(text: clip?.content);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Clip' : 'Add New Clip'),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter clip title',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  hintText: 'Enter clip content',
                  isDense: true,
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
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
                final clipData = ClipItem(
                  id: clip?.id ?? DateTime.now().toString(),
                  title: title,
                  content: content,
                  createdAt: clip?.createdAt ?? DateTime.now(),
                );
                
                if (isEditing) {
                  await _db.updateClip(clipData);
                } else {
                  await _db.insertClip(clipData);
                }
                
                Navigator.pop(context);
                _loadClips();
              }
            },
            child: Text(isEditing ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Clipodex'),
        backgroundColor: AppColors.surface.withOpacity(0.9),
        actions: [
          // Add button
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showClipDialog(),
            tooltip: 'Add New Clip',
          ),
          // Edit toggle button
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
            },
            tooltip: _isEditing ? 'Save' : 'Edit',
          ),
          const SizedBox(width: 8), // Add some padding at the end
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: kToolbarHeight + 16), // AppBar height + extra space
        itemCount: _clips.length,
        itemBuilder: (context, index) {
          final clip = _clips[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(
                clip.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                clip.content,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: _isEditing ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Edit button
                  IconButton(
                    icon: const Icon(Icons.edit_note, size: 20),
                    onPressed: () => _showClipDialog(clip: clip),
                    tooltip: 'Edit Clip',
                  ),
                  // Delete button
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: () async {
                      await _db.deleteClip(clip.id);
                      _loadClips();
                    },
                    tooltip: 'Delete Clip',
                  ),
                ],
              ) : null,
              onTap: () {
                Clipboard.setData(ClipboardData(text: clip.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied: ${clip.content.length > 50 ? '${clip.content.substring(0, 50)}...' : clip.content}'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
} 