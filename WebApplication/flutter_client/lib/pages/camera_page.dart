import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../main.dart'; // cameras
import '../services/api.dart';
import 'preview_page.dart';
import 'lock_page.dart';

class CameraPage extends StatefulWidget {
  final String pageTitle;
  const CameraPage({super.key, required this.pageTitle});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  Future<void>? _initFuture;

  int _remaining = 0;
  bool _taking = false;
  bool _switching = false;

  // 現在使っているカメラ
  CameraDescription? _currentCamera;

  @override
  void initState() {
    super.initState();

    // 初期化と並行して残り回数取得
    _loadRemaining();

    // 最初は「背面があれば背面、なければ先頭」
    final back = _findCamera(CameraLensDirection.back);
    _currentCamera = back ?? (cameras.isNotEmpty ? cameras.first : null);

    if (_currentCamera != null) {
      _setupController(_currentCamera!);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  CameraDescription? _findCamera(CameraLensDirection dir) {
    try {
      return cameras.firstWhere((c) => c.lensDirection == dir);
    } catch (_) {
      return null;
    }
  }

  Future<void> _setupController(CameraDescription cam) async {
    // 既存controllerを破棄→新しいcontrollerを作る
    final old = _controller;
    _controller = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    final future = _controller!.initialize();
    setState(() {
      _initFuture = future;
      _currentCamera = cam;
    });

    // 古いcontrollerを最後に破棄（順番大事）
    await old?.dispose();

    // 初期化を待ってからUI更新（エラーはFutureBuilder側で出る）
    await future;
    if (mounted) setState(() {});
  }

  Future<void> _toggleCamera() async {
    if (_switching || _taking) return;
    if (cameras.isEmpty) return;

    final now = _currentCamera;
    if (now == null) return;

    // 反対側を探す（なければ何もしない）
    final targetDir = now.lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    final target = _findCamera(targetDir);
    if (target == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("切り替え先のカメラが見つかりません")));
      return;
    }

    setState(() => _switching = true);
    try {
      await _setupController(target);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("カメラ切替エラー: $e")));
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _loadRemaining() async {
    final r = await Api.fetchRemaining(widget.pageTitle);
    if (!mounted) return;

    if (r <= 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LockPage(pageTitle: widget.pageTitle),
        ),
      );
      return;
    }

    setState(() => _remaining = r);
  }

  Future<void> _take() async {
    if (_taking) return;
    setState(() => _taking = true);

    try {
      final init = _initFuture;
      final ctrl = _controller;
      if (init == null || ctrl == null) {
        throw Exception("カメラが初期化されていません");
      }

      // 念のため初期化完了を待つ
      await init;

      final file = await ctrl.takePicture();
      final Uint8List bytes = await file.readAsBytes();

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

      if (!mounted) return;

      if (uploaded == true) {
        await _loadRemaining(); // 送信成功→残り更新（0ならLockPageへ行く）
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("カメラエラー: $e")));
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.pageTitle}  残り: $_remaining"),
        actions: [
          IconButton(
            onPressed: (_switching || _taking) ? null : _toggleCamera,
            icon: Icon(
              (_currentCamera?.lensDirection == CameraLensDirection.front)
                  ? Icons.cameraswitch
                  : Icons.cameraswitch,
            ),
            tooltip: "内/外カメラ切替",
          ),
        ],
      ),
      body: (ctrl == null || _initFuture == null)
          ? const Center(child: Text("カメラが見つかりません"))
          : FutureBuilder<void>(
              future: _initFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done ||
                    _switching) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text("カメラ初期化失敗: ${snap.error}"));
                }

                return Column(
                  children: [
                    AspectRatio(
                      aspectRatio: ctrl.value.aspectRatio,
                      child: CameraPreview(ctrl),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed:
                                (_remaining <= 0 || _taking || _switching)
                                ? null
                                : _take,
                            child: Text(_taking ? "撮影中..." : "写真を撮る"),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
