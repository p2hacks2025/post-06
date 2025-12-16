import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

late List<CameraDescription> cameras;

// FastAPI
const String baseUrl = "http://localhost:8001";

// QR unlock key
const String unlockKey = "OnionSalmon2025";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<String?> _loadTitle() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString("page_title");
    if (t == null || t.trim().isEmpty) return null;
    return t;
  }

  Future<int> _fetchRemaining(String title) async {
    try {
      final uri = Uri.parse(
        "$baseUrl/photos/count?title=${Uri.encodeComponent(title)}",
      );
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data["remaining"] as num).toInt();
      }
    } catch (_) {}
    return 999;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _loadTitle(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        final title = snap.data;
        if (title == null) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: TitleInputPage(),
          );
        }

        return FutureBuilder<int>(
          future: _fetchRemaining(title),
          builder: (context, snap2) {
            if (snap2.connectionState != ConnectionState.done) {
              return const MaterialApp(
                debugShowCheckedModeBanner: false,
                home: Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final remaining = snap2.data ?? 999;
            final Widget home = (remaining <= 0)
                ? LockPage(pageTitle: title)
                : CameraPage(pageTitle: title);

            return MaterialApp(debugShowCheckedModeBanner: false, home: home);
          },
        );
      },
    );
  }
}

/// =====================
/// Title Input
/// =====================
class TitleInputPage extends StatefulWidget {
  const TitleInputPage({super.key});

  @override
  State<TitleInputPage> createState() => _TitleInputPageState();
}

class _TitleInputPageState extends State<TitleInputPage> {
  final _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  Future<void> _goNext() async {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      setState(() => _error = "タイトルを入力してください");
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("page_title", title);

      final uri = Uri.parse("$baseUrl/site/title");
      final req = http.MultipartRequest("POST", uri)..fields["title"] = title;
      await req.send();

      final uri2 = Uri.parse(
        "$baseUrl/photos/count?title=${Uri.encodeComponent(title)}",
      );
      final res2 = await http.get(uri2);

      int remaining = 999;
      if (res2.statusCode == 200) {
        final data = jsonDecode(res2.body);
        remaining = (data["remaining"] as num).toInt();
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => (remaining <= 0)
              ? LockPage(pageTitle: title)
              : CameraPage(pageTitle: title),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("失敗: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
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
              decoration: InputDecoration(
                labelText: "タイトル",
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saving ? null : _goNext,
              child: Text(_saving ? "保存中..." : "次へ"),
            ),
          ],
        ),
      ),
    );
  }
}

/// =====================
/// Camera Page
/// =====================
class CameraPage extends StatefulWidget {
  final String pageTitle;
  const CameraPage({super.key, required this.pageTitle});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _controller;
  bool _initialized = false;
  bool _taking = false;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(cameras.first, ResolutionPreset.medium);
    _init();
    _fetchRemaining();
  }

  Future<void> _init() async {
    await _controller.initialize();
    if (!mounted) return;
    setState(() => _initialized = true);
  }

  Future<void> _fetchRemaining() async {
    final uri = Uri.parse(
      "$baseUrl/photos/count?title=${Uri.encodeComponent(widget.pageTitle)}",
    );
    final res = await http.get(uri);
    if (!mounted) return;

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final r = (data["remaining"] as num).toInt();
      setState(() => _remaining = r);

      if (r <= 0) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LockPage(pageTitle: widget.pageTitle),
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    if (_taking) return;
    _taking = true;

    final file = await _controller.takePicture();
    final bytes = await file.readAsBytes();

    if (!mounted) return;

    final uploaded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PreviewPage(
          pageTitle: widget.pageTitle,
          imageBytes: bytes,
          remainingBefore: (_remaining - 1).clamp(0, 999),
        ),
      ),
    );

    if (uploaded == true) {
      await _fetchRemaining();
    }

    _taking = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.pageTitle} 残り: $_remaining")),
      body: Column(
        children: [
          if (_initialized)
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: CameraPreview(_controller),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: (_remaining <= 0) ? null : _takePhoto,
            child: const Text("写真を撮る"),
          ),
        ],
      ),
    );
  }
}

/// =====================
/// Preview Page
/// =====================
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
  bool _uploading = false;

  Future<void> _upload() async {
    _uploading = true;

    final uri = Uri.parse("$baseUrl/upload");
    final req = http.MultipartRequest("POST", uri)
      ..fields["title"] = widget.pageTitle
      ..fields["comment"] = _comment.text
      ..files.add(
        http.MultipartFile.fromBytes(
          "file",
          widget.imageBytes,
          filename: "capture.jpg",
        ),
      );

    final res = await http.Response.fromStream(await req.send());
    if (!mounted) return;

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final remaining = (data["remaining"] as num).toInt();

      if (remaining <= 0) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => LockPage(pageTitle: widget.pageTitle),
          ),
          (_) => false,
        );
      } else {
        Navigator.of(context).pop(true);
      }
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
          ElevatedButton(
            onPressed: _uploading ? null : _upload,
            child: const Text("送信"),
          ),
        ],
      ),
    );
  }
}

/// =====================
/// Lock Page
/// =====================
class LockPage extends StatefulWidget {
  final String pageTitle;
  const LockPage({super.key, required this.pageTitle});

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  Uint8List? _image;

  @override
  void initState() {
    super.initState();
    _fetchFirst();
  }

  Future<void> _fetchFirst() async {
    final uri = Uri.parse(
      "$baseUrl/photos/first?title=${Uri.encodeComponent(widget.pageTitle)}",
    );
    final res = await http.get(uri);
    if (!mounted) return;
    if (res.statusCode == 200) {
      setState(() => _image = res.bodyBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pageTitle)),
      body: Column(
        children: [
          const Text("タイトル入力後に最初に撮った写真"),
          if (_image != null) Expanded(child: Image.memory(_image!)),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => QrScanPage(pageTitle: widget.pageTitle),
                ),
              );
            },
            child: const Text("QRで解錠する"),
          ),
        ],
      ),
    );
  }
}

/// =====================
/// QR Scan
/// =====================
class QrScanPage extends StatefulWidget {
  final String pageTitle;
  const QrScanPage({super.key, required this.pageTitle});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QRスキャン")),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done) return;
          final value = capture.barcodes.first.rawValue;
          if (value == unlockKey) {
            _done = true;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AlbumPage(pageTitle: widget.pageTitle),
              ),
            );
          }
        },
      ),
    );
  }
}

/// =====================
/// Album
/// =====================
class PhotoMeta {
  final int id;
  final String comment;
  PhotoMeta(this.id, this.comment);

  factory PhotoMeta.fromJson(Map<String, dynamic> j) =>
      PhotoMeta(j["id"], j["comment"] ?? "");
}

class AlbumPage extends StatefulWidget {
  final String pageTitle;
  const AlbumPage({super.key, required this.pageTitle});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  late Future<List<PhotoMeta>> _photos;

  @override
  void initState() {
    super.initState();
    _photos = _fetch();
  }

  Future<List<PhotoMeta>> _fetch() async {
    final uri = Uri.parse(
      "$baseUrl/photos/list?title=${Uri.encodeComponent(widget.pageTitle)}",
    );
    final res = await http.get(uri);
    final data = jsonDecode(res.body);
    return (data["photos"] as List).map((e) => PhotoMeta.fromJson(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("アルバム")),
      body: FutureBuilder<List<PhotoMeta>>(
        future: _photos,
        builder: (c, s) {
          if (!s.hasData)
            return const Center(child: CircularProgressIndicator());
          return PageView(
            children: s.data!
                .map(
                  (p) => Column(
                    children: [
                      Expanded(child: Image.network("$baseUrl/photos/${p.id}")),
                      Text(p.comment),
                    ],
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}
