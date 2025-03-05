import 'dart:math';
import 'package:clipodex/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/database_helper.dart';
import '../widgets/clip_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<ClipItem> _clips = [];
  bool _isEditing = false;
  List<Tag> _selectedFilters = [];

  @override
  void initState() {
    super.initState();
    _loadClips();
  }

  Future<void> _loadClips() async {
    final clips = await _db.getAllClips();
    
    if (_selectedFilters.isEmpty) {
      final sortedClips = List<ClipItem>.from(clips)
        ..sort((a, b) {
          if (a.copyCount != b.copyCount) {
            return b.copyCount.compareTo(a.copyCount);
          }
          return a.position.compareTo(b.position);
        });
      
      setState(() => _clips = sortedClips);
      return;
    }

    final filteredClips = <ClipItem>[];
    for (final clip in clips) {
      final clipTags = await _db.getTagsForClip(clip.id);
      if (_selectedFilters.any((filterTag) => 
        clipTags.any((clipTag) => clipTag.id == filterTag.id)
      )) {
        filteredClips.add(clip);
      }
    }
    
    filteredClips.sort((a, b) {
      if (a.copyCount != b.copyCount) {
        return b.copyCount.compareTo(a.copyCount);
      }
      return a.position.compareTo(b.position);
    });
    
    setState(() => _clips = filteredClips);
  }

  Future<void> _showClipDialog({ClipItem? clip}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClipDialog(
        clip: clip,
        db: _db,
        onSave: (title, content, tags, isMasked) async {
          final position = clip?.position ?? await _getNextPosition();
          final clipData = ClipItem(
            id: clip?.id ?? DateTime.now().toString(),
            title: title,
            content: content,
            position: position,
            isMasked: isMasked,
            createdAt: clip?.createdAt ?? DateTime.now(),
          );
          
          if (clip != null) {
            await _db.updateClip(clipData, tags);
          } else {
            await _db.insertClip(clipData, tags);
          }
          _loadClips();
        },
      ),
    );
  }

  Future<int> _getNextPosition() async {
    final clips = await _db.getAllClips();
    return clips.isEmpty ? 0 : clips.map((c) => c.position).reduce(max) + 1;
  }

  Future<Tag?> _showTagDialog({List<Tag> selectedTags = const []}) async {
    final textController = TextEditingController();
    final existingTags = await _db.getAllTags();
    
    final availableTags = existingTags.where(
      (tag) => !selectedTags.any((selected) => selected.id == tag.id)
    ).toList();

    return showDialog<Tag>(
      context: context,
      barrierDismissible: false,
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
                // Check for duplicate tag names
                if (existingTags.any((t) => t.name.toLowerCase() == name.toLowerCase())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tag "$name" already exists')),
                  );
                  return;
                }
                
                // Check tag limit (15)
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
                await _db.createTag(tag);
                Navigator.pop(context, tag);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    final allTags = await _db.getAllTags();
    // Create a new list from current filters
    List<Tag> tempSelectedFilters = List.from(_selectedFilters);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Filter by Tags'),
              if (tempSelectedFilters.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_all),
                  onPressed: () {
                    setState(() {
                      tempSelectedFilters.clear();
                    });
                  },
                  tooltip: 'Clear Filters',
                ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allTags.map((tag) => FilterChip(
                  label: Text('#${tag.name}'),
                  // Compare by ID instead of object
                  selected: tempSelectedFilters.any((t) => t.id == tag.id),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        tempSelectedFilters.add(tag);
                      } else {
                        tempSelectedFilters.removeWhere((t) => t.id == tag.id);
                      }
                    });
                  },
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
              onPressed: () {
                // Update parent state and reload
                this.setState(() {
                  _selectedFilters = List.from(tempSelectedFilters);
                });
                _loadClips();
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTagManagementDialog() async {
    final allTags = await _db.getAllTags();
    final Map<String, int> tagUsage = {};
    
    // Count usage for each tag
    for (var tag in allTags) {
      final clips = await _db.getClipsWithTag(tag.id);
      tagUsage[tag.id] = clips.length;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Manage Tags'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...allTags.map((tag) {
                  final useCount = tagUsage[tag.id] ?? 0;
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
                          onPressed: () => _showTagRenameDialog(tag, onRenamed: () {
                            Navigator.pop(context);
                            _showTagManagementDialog(); // Refresh
                          }),
                          tooltip: 'Rename Tag',
                        ),
                        if (useCount == 0)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () async {
                              await _db.deleteTag(tag.id);
                              Navigator.pop(context);
                              _showTagManagementDialog(); // Refresh
                            },
                            tooltip: 'Delete Unused Tag',
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTagRenameDialog(Tag tag, {required Function onRenamed}) async {
    final textController = TextEditingController(text: tag.name);
    final existingTags = await _db.getAllTags();

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

              await _db.renameTag(tag.id, newName);
              Navigator.pop(context);
              onRenamed();
              _loadClips(); // Refresh clips to update tags
            },
            child: const Text('Rename'),
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
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.sell_outlined),
              onPressed: _showTagManagementDialog,
              tooltip: 'Manage Tags',
            ),
          IconButton(
            icon: Badge(
              isLabelVisible: _selectedFilters.isNotEmpty,
              label: Text(_selectedFilters.length.toString()),
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () async {
              final hasTags = await _db.getAllTags().then((tags) => tags.isNotEmpty);
              final hasTaggedClips = await _db.hasClipsWithTags();
              
              if (!hasTags || !hasTaggedClips) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No tags available'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              
              _showFilterDialog();
            },
            tooltip: 'Filter by Tags',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showClipDialog(),
            tooltip: 'Add New Clip',
          ),
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
            },
            tooltip: _isEditing ? 'Save' : 'Edit',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: kToolbarHeight + 16),
        itemCount: _clips.length,
        itemBuilder: (context, index) {
          final clip = _clips[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Row(
                    children: [
                      Expanded(child: Text(clip.title)),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clip.displayContent,
                        style: TextStyle(
                          fontFamily: clip.isMasked ? 'Monospace' : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<List<Tag>>(
                        future: _db.getTagsForClip(clip.id),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Wrap(
                            spacing: 4,
                            children: snapshot.data!.map((tag) => Chip(
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              label: Text(
                                '#${tag.name}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              padding: const EdgeInsets.all(0),
                              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                            )).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                  trailing: _isEditing ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_note, size: 20),
                        onPressed: () => _showClipDialog(clip: clip),
                        tooltip: clip.isMasked ? 'Only title and tags can be edited' : 'Edit Clip',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () async {
                          await _db.deleteClip(clip.id);
                          
                          // Check if we need to clear filters
                          final hasTaggedClips = await _db.hasClipsWithTags();
                          if (!hasTaggedClips) {
                            setState(() {
                              _selectedFilters.clear();  // Clear filters if no tagged clips remain
                            });
                          }
                          
                          _loadClips();
                        },
                        tooltip: 'Delete Clip',
                      ),
                    ],
                  ) : null,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: clip.content));
                    await _db.incrementCopyCount(clip.id);
                    _loadClips(); // Refresh to update order
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied: ${clip.content.length > 50 ? '${clip.content.substring(0, 50)}...' : clip.content}'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 