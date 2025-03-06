class ClipItem {
  final String id;
  final String title;
  final String content;
  final int position;
  final DateTime createdAt;
  final int copyCount;
  final bool isMasked;

  ClipItem({
    required this.id,
    required this.title,
    required this.content,
    required this.position,
    this.copyCount = 0,
    this.isMasked = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get displayContent => isMasked ? '•' * 12 : content;
} 