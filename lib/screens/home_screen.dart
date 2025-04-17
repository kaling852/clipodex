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
  Key _tagsKey = UniqueKey();
  bool _isInitialLoad = true;
  bool _needsReorder = false;

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

  void _refreshTags() {
    setState(() {
      _tagsKey = UniqueKey();
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
    try {
      final clips = await _db.getAllClips();
      
      if (_selectedFilters.isEmpty) {
        if (_isInitialLoad) {
          // On initial load, sort by copy count
          final sortedClips = List<ClipItem>.from(clips)
            ..sort((a, b) => b.copyCount.compareTo(a.copyCount));
          
          // Update positions based on new order
          for (var i = 0; i < sortedClips.length; i++) {
            final clip = sortedClips[i];
            if (clip.position != i) {
              final updatedClip = ClipItem(
                id: clip.id,
                title: clip.title,
                content: clip.content,
                position: i,
                copyCount: clip.copyCount,
                isMasked: clip.isMasked,
                createdAt: clip.createdAt,
              );
              await _db.updateClip(updatedClip, await _db.getTagsForClip(clip.id));
            }
          }
          
          setState(() {
            _clips = sortedClips;
            _isInitialLoad = false;
            _needsReorder = false;
          });
        } else {
          // During runtime, maintain current order
          final sortedClips = List<ClipItem>.from(clips)
            ..sort((a, b) => a.position.compareTo(b.position));
          
          // Check if current order matches usage order
          bool isOrderedByUsage = true;
          for (int i = 0; i < sortedClips.length - 1; i++) {
            if (sortedClips[i].copyCount < sortedClips[i + 1].copyCount) {
              isOrderedByUsage = false;
              break;
            }
          }
          
          setState(() {
            _clips = sortedClips;
            _needsReorder = !isOrderedByUsage;
          });
        }
        return;
      }

      // Handle filtered clips
      final allTags = await _db.getAllTags();
      final clipTagsMap = <String, List<Tag>>{};
      
      for (final tag in allTags) {
        final clipsWithTag = await _db.getClipsWithTag(tag.id);
        for (final clip in clipsWithTag) {
          clipTagsMap.putIfAbsent(clip.id, () => []).add(tag);
        }
      }

      final filteredClips = clips.where((clip) {
        final clipTags = clipTagsMap[clip.id] ?? [];
        return _selectedFilters.any((filterTag) => 
          clipTags.any((clipTag) => clipTag.id == filterTag.id)
        );
      }).toList();
      
      // Sort filtered clips by position
      filteredClips.sort((a, b) => a.position.compareTo(b.position));
      setState(() => _clips = filteredClips);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading clips: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
          _refreshTags();
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
          _refreshTags();
          _loadClips();
        },
        onDelete: (tagId) {
          _refreshTags();
          _loadClips();
        },
      ),
    );
  }

  Future<void> _refreshByUsage() async {
    try {
      final clips = await _db.getAllClips();
      final sortedClips = List<ClipItem>.from(clips)
        ..sort((a, b) => b.copyCount.compareTo(a.copyCount));
      
      // Update positions based on new order
      for (var i = 0; i < sortedClips.length; i++) {
        final clip = sortedClips[i];
        if (clip.position != i) {
          final updatedClip = ClipItem(
            id: clip.id,
            title: clip.title,
            content: clip.content,
            position: i,
            copyCount: clip.copyCount,
            isMasked: clip.isMasked,
            createdAt: clip.createdAt,
          );
          await _db.updateClip(updatedClip, await _db.getTagsForClip(clip.id));
        }
      }
      
      setState(() {
        _clips = sortedClips;
        _needsReorder = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clips reordered by usage'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing clips: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTagChips({
    required List<Tag> tags,
    required bool isFilter,
    double spacing = 8,
    double runSpacing = 8,
    EdgeInsets? margin,
  }) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: tags.map((tag) => FilterChip(
          label: Text('#${tag.name}'),
          selected: isFilter ? _selectedFilters.any((t) => t.id == tag.id) : false,
          onSelected: isFilter ? (selected) async {
            setState(() {
              if (selected) {
                _selectedFilters.add(tag);
              } else {
                _selectedFilters.removeWhere((t) => t.id == tag.id);
              }
            });
            _loadClips();
          } : null,
        )).toList(),
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
          if (_needsReorder)
            IconButton(
              icon: const Icon(Icons.trending_up),
              onPressed: _refreshByUsage,
              tooltip: 'Reorder by Usage',
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
        itemCount: _clips.length + 1, // Add 1 for the tags section
        itemBuilder: (context, index) {
          if (index == 0) {
            // Tags section
            return FutureBuilder<List<Tag>>(
              key: _tagsKey,
              future: _db.getAllTags(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }
                return _buildTagChips(
                  tags: snapshot.data!,
                  isFilter: true,
                );
              },
            );
          }
          
          // Clip section (index - 1 because index 0 is tags)
          final clipIndex = index - 1;
          final clip = _clips[clipIndex];
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
                          return _buildTagChips(
                            tags: snapshot.data!,
                            isFilter: false,
                            spacing: 4,
                            margin: EdgeInsets.zero,
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