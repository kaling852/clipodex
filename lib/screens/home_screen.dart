import 'dart:math';
import 'package:clipodex/models/clip_item.dart';
import 'package:clipodex/models/tag.dart';
import 'package:clipodex/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database_helper.dart';
import '../dialogs/clip_dialog.dart';
import '../dialogs/filter_dialog.dart';
import '../dialogs/tag_management_dialog.dart';
import '../dialogs/welcome_dialog.dart';

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
    // Add a small delay to ensure the dialog shows up
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _showWelcomeMessage();
      }
    });
  }

  Future<void> _showWelcomeMessage() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenWelcome = prefs.getBool('has_seen_welcome') ?? false;

    if (!hasSeenWelcome && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const WelcomeDialog(),
      );
    }
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

  Future<void> _showFilterDialog() async {
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

    await showDialog(
      context: context,
      builder: (context) => FilterDialog(
        selectedFilters: _selectedFilters,
        db: _db,
        onApply: (filters) {
          setState(() {
            _selectedFilters = filters;
          });
          _loadClips();
        },
      ),
    );
  }

  Future<void> _showTagManagementDialog() async {
    await showDialog(
      context: context,
      builder: (context) => TagManagementDialog(
        db: _db,
        onRename: (tag) {
          _loadClips(); // Refresh clips to update tags
        },
        onDelete: (tagId) {
          _loadClips(); // Refresh clips to update tags
        },
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
                      const SizedBox(height: 4),
                      Text(
                        clip.displayContent,
                        style: TextStyle(
                          fontFamily: clip.isMasked ? 'Monospace' : null,
                          color: Colors.grey[200],
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
                        icon: Icon(clip.isMasked ? Icons.visibility_off : Icons.visibility),
                        onPressed: () async {
                          final updatedClip = ClipItem(
                            id: clip.id,
                            title: clip.title,
                            content: clip.content,
                            position: clip.position,
                            copyCount: clip.copyCount,
                            isMasked: !clip.isMasked,
                            createdAt: clip.createdAt,
                          );
                          await _db.updateClip(updatedClip, await _db.getTagsForClip(clip.id));
                          _loadClips();
                        },
                        tooltip: clip.isMasked ? 'Unmask Content' : 'Mask Content',
                      ),
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
                        content: Text('Copied: ${clip.isMasked ? '••••••••' : (clip.content.length > 50 ? '${clip.content.substring(0, 50)}...' : clip.content)}'),
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