import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class FilterDialog extends StatefulWidget {
  final List<Tag> selectedFilters;
  final DatabaseHelper db;
  final Function(List<Tag>) onApply;

  const FilterDialog({
    super.key,
    required this.selectedFilters,
    required this.db,
    required this.onApply,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late List<Tag> tempSelectedFilters;

  @override
  void initState() {
    super.initState();
    tempSelectedFilters = List.from(widget.selectedFilters);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Filter by Tags'),
          if (tempSelectedFilters.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () => setState(() => tempSelectedFilters.clear()),
              tooltip: 'Clear Filters',
            ),
        ],
      ),
      content: FutureBuilder<List<Tag>>(
        future: widget.db.getAllTags(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();
          
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: snapshot.data!.map((tag) => FilterChip(
                  label: Text('#${tag.name}'),
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
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onApply(tempSelectedFilters);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
} 