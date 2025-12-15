import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

late List<CameraDescription> cameras;

// ★ FastAPIを8001で起動する前提で統一
const String baseUrl = "http://localhost:8001";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraPage(),
    );
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late final CameraController _controller;
  bool _initialized = false;
  bool _taking = false;
  int _count = 0;
  static const int _goal = 25;

  @override
  void initState() {
    super.initState();

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _initialized = true);
    });

    fetchCount();
  }

  Future<void> fetchCount() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/photos/count"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final int c = (data["count"] is num)
            ? (data["count"] as num).toInt()
            : 0;

        if (!mounted) return;

        setState(() => _count = c);

        if (c >= _goal) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const EmptyPage()),
            (route) => false,
          );
        }
      }
    } catch (_) {
      // 通信失敗時は何もしない
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> takeAndGoPreview() async {
    if (!_initialized || _taking) return;
    setState(() => _taking = true);

    try {
      final XFile file = await _controller.takePicture();
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;

      final bool? saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => PreviewPage(imageBytes: bytes)),
      );

      if (!mounted) return;

      if (saved == true) {
        await fetchCount();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("撮影に失敗: $e")));
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("撮影画面  $_count/$_goal")),
      body: Column(
        children: [
          if (_initialized)
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: CameraPreview(_controller),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _taking ? null : takeAndGoPreview,
                child: Text(_taking ? "撮影中..." : "写真を撮って次へ"),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class PreviewPage extends StatefulWidget {
  final Uint8List imageBytes;
  const PreviewPage({super.key, required this.imageBytes});

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  bool _uploading = false;
  String _message = "";

  Future<void> uploadToFastApi() async {
    setState(() {
      _uploading = true;
      _message = "アップロード中...";
    });

    try {
      final uri = Uri.parse("$baseUrl/upload");
      final req = http.MultipartRequest("POST", uri)
        ..files.add(
          http.MultipartFile.fromBytes(
            "file",
            widget.imageBytes,
            filename: "capture.jpg",
          ),
        );

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        if (!mounted) return;

        final data = jsonDecode(res.body);
        final int count = (data["count"] as num).toInt();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("保存しました！")));

        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;

        if (count >= 25) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const EmptyPage()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pop(true);
        }
      } else if (res.statusCode == 409) {
        // 25枚到達（サーバー側制限）
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const EmptyPage()),
          (route) => false,
        );
      } else {
        setState(() => _message = "失敗: ${res.statusCode}\n${res.body}");
      }
    } catch (e) {
      setState(() => _message = "例外: $e");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("プレビュー")),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: Image.memory(widget.imageBytes, fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: _uploading ? null : uploadToFastApi,
                  child: Text(_uploading ? "送信中..." : "OK（FastAPIに送る）"),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _uploading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text("撮り直す（戻る）"),
                ),
                const SizedBox(height: 8),
                SelectableText(_message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyPage extends StatelessWidget {
  const EmptyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text("準備中の画面")));
  }
}
