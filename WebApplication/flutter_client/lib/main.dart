import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

late List<CameraDescription> cameras;

// FastAPI を 8001 で起動する前提
const String baseUrl = "http://192.168.11.8:8000"; //"http://自分のPCのIP:8001"

//固定キーの定義（QRコード）
const String unlockKey = "OnionSalmon2025";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<String?> _loadTitle() async {
    final uri = Uri.parse("$baseUrl/site/title");
    final res = await http.get(uri);

    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body);
    if (data["exists"] != true) return null;

    return data["title"] as String;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _loadTitle(),
      builder: (context, snapshot) {
        final title = snapshot.data;

        // 取得中は簡易ローディング
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        // タイトルが保存済みならカメラから開始
        final Widget home = (title != null)
            ? CameraPage(pageTitle: title)
            : const TitleInputPage();

        return MaterialApp(debugShowCheckedModeBanner: false, home: home);
      },
    );
  }
}

/// ① 起動時：タイトル入力画面
class TitleInputPage extends StatefulWidget {
  const TitleInputPage({super.key});

  @override
  State<TitleInputPage> createState() => _TitleInputPageState();
}

class _TitleInputPageState extends State<TitleInputPage> {
  final _controller = TextEditingController();
  String? _error;

  Future<void> _goCamera() async {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      setState(() => _error = "タイトルを入力してください");
      return;
    }

    final uri = Uri.parse("$baseUrl/site/title");
    await http.post(uri, body: {"title": title});

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => CameraPage(pageTitle: title)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ページタイトル入力")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("ページタイトルを入力してください"),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: "タイトル",
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _goCamera(),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _goCamera,
              child: const Text("次へ（カメラ起動）"),
            ),
          ],
        ),
      ),
    );
  }
}

/// ② タイトル入力後：カメラ画面
class CameraPage extends StatefulWidget {
  final String pageTitle;
  const CameraPage({super.key, required this.pageTitle});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late final CameraController _controller;
  bool _initialized = false;
  bool _taking = false;

  int _remaining = 25; // ★残り回数（最初の1枚はノーカウントなので初期は25）
  bool _loadingCount = true;

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

    fetchRemaining();
  }

  Future<void> fetchRemaining() async {
    setState(() => _loadingCount = true);
    try {
      final uri = Uri.parse(
        "$baseUrl/photos/count?title=${Uri.encodeComponent(widget.pageTitle)}",
      );
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final int remaining = (data["remaining"] as num).toInt();

        if (!mounted) return;
        setState(() => _remaining = remaining);

        if (remaining <= 0) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => LockPage(pageTitle: widget.pageTitle),
            ),
            (route) => false,
          );
        }
      }
    } catch (_) {
      // 通信失敗時は黙っておく（必要ならメッセージ表示も可）
    } finally {
      if (mounted) setState(() => _loadingCount = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> takeAndGoPreview() async {
    if (!_initialized || _taking) return;

    // ★残り0なら撮影ボタンを実質無効に
    if (_remaining <= 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LockPage(pageTitle: widget.pageTitle),
        ),
        (route) => false,
      );
      return;
    }

    setState(() => _taking = true);

    try {
      final XFile file = await _controller.takePicture();
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;

      final bool? uploaded = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PreviewPage(
            pageTitle: widget.pageTitle,
            imageBytes: bytes,
            remainingBefore: (_remaining - 1).clamp(0, 25), // ★プレビューにも残り表示
          ),
        ),
      );

      if (!mounted) return;

      // ★アップロード成功で戻ってきたら残り回数を再取得
      if (uploaded == true) {
        await fetchRemaining();
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
      appBar: AppBar(title: Text("${widget.pageTitle}  残り: $_remaining")),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loadingCount)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LinearProgressIndicator(),
                  )
                else
                  Text(
                    "残り撮影回数: $_remaining",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                const SizedBox(height: 8),

                ElevatedButton(
                  onPressed: (_taking || _remaining <= 0)
                      ? null
                      : takeAndGoPreview,
                  child: Text(_taking ? "撮影中..." : "写真を撮る"),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// ③ 撮影後：プレビュー（OKでFastAPIに送る）
class PreviewPage extends StatefulWidget {
  final String pageTitle;
  final Uint8List imageBytes;
  final int remainingBefore; // ★追加

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
        ..fields["title"] = widget.pageTitle
        ..files.add(
          http.MultipartFile.fromBytes(
            "file",
            widget.imageBytes,
            filename: "capture.jpg",
          ),
        );

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final int remaining = (data["remaining"] as num).toInt();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("送信しました！")));

        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;

        // ★残り0なら準備中へ
        if (remaining <= 0) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => LockPage(pageTitle: widget.pageTitle),
            ),
            (route) => false,
          );
        } else {
          // ★アップロード成功を CameraPage に知らせて戻る
          Navigator.of(context).pop(true);
        }
      } else if (res.statusCode == 409) {
        // 制限到達
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => LockPage(pageTitle: widget.pageTitle),
          ),
          (route) => false,
        );
      } else {
        setState(() => _message = "失敗: ${res.statusCode}\n${res.body}");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = "例外: $e");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.pageTitle}（プレビュー）")),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            "残り撮影回数: ${widget.remainingBefore}",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
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
                      : () => Navigator.of(context).pop(false),
                  child: const Text("戻る（撮り直す）"),
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

class LockPage extends StatefulWidget {
  final String pageTitle;
  const LockPage({super.key, required this.pageTitle});

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  Uint8List? _firstImage;
  bool _loading = true;
  String _msg = "";

  @override
  void initState() {
    super.initState();
    _fetchFirst();
  }

  Future<void> _fetchFirst() async {
    try {
      final uri = Uri.parse(
        "$baseUrl/photos/first?title=${Uri.encodeComponent(widget.pageTitle)}",
      );
      final res = await http.get(uri);

      if (!mounted) return;

      if (res.statusCode == 200) {
        setState(() {
          _firstImage = res.bodyBytes;
          _msg = "";
        });
      } else if (res.statusCode == 404) {
        setState(() => _msg = "まだ写真がありません");
      } else {
        setState(() => _msg = "取得失敗: ${res.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _msg = "例外: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pageTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "準備中の画面",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (_loading) const LinearProgressIndicator(),

            if (_firstImage != null) ...[
              const SizedBox(height: 12),
              const Text("（タイトル入力後に最初に撮った写真）"),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: Image.memory(_firstImage!, fit: BoxFit.contain),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(_msg),
            ],
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QrScanPage(pageTitle: widget.pageTitle),
                  ),
                );
              },
              child: const Text("QRコードを読み取って解錠"),
            ),
          ],
        ),
      ),
    );
  }
}

class QrScanPage extends StatefulWidget {
  final String pageTitle;
  const QrScanPage({super.key, required this.pageTitle});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  bool _handled = false;
  String _msg = "カメラにQRをかざしてください";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QRコード読み取り")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _msg,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                if (_handled) return;

                final barcodes = capture.barcodes;
                if (barcodes.isEmpty) return;

                final value = barcodes.first.rawValue;
                if (value == null || value.isEmpty) return;

                _handled = true;

                if (value.trim() == unlockKey) {
                  // ✅ 解錠成功 → 振り返り画面へ
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => AlbumPage(pageTitle: widget.pageTitle),
                    ),
                  );
                } else {
                  // ❌ 解錠失敗 → メッセージ表示して再試行可能にする
                  setState(() {
                    _msg = "NG（鍵が違います）\n読み取った値: $value";
                    _handled = false; // 再スキャンできるように戻す
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AlbumPage extends StatefulWidget {
  final String pageTitle;
  const AlbumPage({super.key, required this.pageTitle});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  late Future<List<int>> _idsFuture;
  int _index = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _idsFuture = _fetchIds();

    _pageController = PageController(initialPage: 1000); // 擬似無限スクロール用（真ん中から開始）
  }

  Future<List<int>> _fetchIds() async {
    final uri = Uri.parse(
      "$baseUrl/photos/ids?title=${Uri.encodeComponent(widget.pageTitle)}",
    );
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception("ids取得失敗: ${res.statusCode} ${res.body}");
    }

    final data = jsonDecode(res.body);
    final List ids = data["ids"] as List;
    return ids.map((e) => (e as num).toInt()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.pageTitle}（アルバム）")),
      body: FutureBuilder<List<int>>(
        future: _idsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("エラー: ${snap.error}"));
          }

          final ids = snap.data ?? [];
          if (ids.isEmpty) {
            return const Center(child: Text("写真がありません"));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  "${_index + 1} / ${ids.length}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) {
                    setState(() {
                      _index = i % ids.length;
                    });
                  },
                  itemBuilder: (context, i) {
                    final id = ids[i % ids.length];
                    final url = "$baseUrl/photos/$id";

                    return InteractiveViewer(
                      child: Center(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const CircularProgressIndicator();
                          },
                          errorBuilder: (context, error, stack) {
                            return Text("画像読み込み失敗: $error");
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
