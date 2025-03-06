import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeDialog extends StatefulWidget {
  const WelcomeDialog({super.key});

  @override
  State<WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<WelcomeDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: AlertDialog(
        title: const Text('Welcome to Clipodex! 🎉'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Here are a few things to know:'),
            SizedBox(height: 8),
            Text('• 📝 This app is perfect for storing your frequently used text snippets.'),
            SizedBox(height: 4),
            Text('• 🔒 While you can mask content, this is just for convenience - not security.'),
            SizedBox(height: 4),
            Text('• 🔑 For sensitive data like passwords, we recommend using a dedicated password manager instead.'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('has_seen_welcome', true);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Got it! ✨'),
          ),
        ],
      ),
    );
  }
} 