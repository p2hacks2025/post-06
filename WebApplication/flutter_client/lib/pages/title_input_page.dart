import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';
import 'camera_page.dart';
import 'lock_page.dart';

class TitleInputPage extends StatefulWidget {
  const TitleInputPage({super.key});
  @override
  State<TitleInputPage> createState() => _TitleInputPageState();
}

class _TitleInputPageState extends State<TitleInputPage> {
  final _controller = TextEditingController();

  Future<void> _next() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("page_title", title);

      // Avoid hanging when the backend is down by timing out requests
      await Api.saveTitleToServer(title).timeout(const Duration(seconds: 3));
      final remaining = await Api.fetchRemaining(title).timeout(
        const Duration(seconds: 3),
        onTimeout: () => 999,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => remaining <= 0
              ? LockPage(pageTitle: title)
              : CameraPage(pageTitle: title),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("サーバーに接続できません: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("タイトル入力")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: "タイトル"),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _next, child: const Text("次へ")),
          ],
        ),
      ),
    );
  }
}
