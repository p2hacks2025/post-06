import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api.dart';
import 'lock_page.dart';

class PreviewPage extends StatefulWidget {
  final String pageTitle;
  final Uint8List imageBytes;
  final int remainingBefore;

  const PreviewPage({
    super.key,
    required this.pageTitle,
    required this.imageBytes,
    required this.remainingBefore,
  });

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  final _comment = TextEditingController();

  Future<void> _upload() async {
    final res = await Api.uploadPhoto(
      title: widget.pageTitle,
      comment: _comment.text,
      imageBytes: widget.imageBytes,
    );

    final remaining = (res["remaining"] as num).toInt();
    if (!mounted) return;

    if (remaining <= 0) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LockPage(pageTitle: widget.pageTitle),
        ),
        (_) => false,
      );
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("プレビュー")),
      body: Column(
        children: [
          Expanded(child: Image.memory(widget.imageBytes)),
          TextField(
            controller: _comment,
            decoration: const InputDecoration(labelText: "コメント"),
          ),
          ElevatedButton(onPressed: _upload, child: const Text("送信")),
        ],
      ),
    );
  }
}
