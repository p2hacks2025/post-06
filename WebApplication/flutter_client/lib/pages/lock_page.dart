import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api.dart';
import 'qr_scan_page.dart';

class LockPage extends StatefulWidget {
  final String pageTitle;
  const LockPage({super.key, required this.pageTitle});

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  Uint8List? _image;
  String _daysText = "";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _image = await Api.fetchFirstImage(widget.pageTitle);
    final first = await Api.fetchFirstCreatedAt(widget.pageTitle);
    if (!mounted) return;

    if (first != null) {
      final days = DateTime.now().difference(first).inDays;
      _daysText = "${widget.pageTitle}から${days}日";
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pageTitle)),
      body: Column(
        children: [
          if (_daysText.isNotEmpty)
            Text(
              _daysText,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          if (_image != null) Expanded(child: Image.memory(_image!)),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QrScanPage(pageTitle: widget.pageTitle),
              ),
            ),
            child: const Text("QRで解錠"),
          ),
        ],
      ),
    );
  }
}
