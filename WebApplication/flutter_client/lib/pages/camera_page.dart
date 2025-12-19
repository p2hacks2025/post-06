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

  // 最初の1回だけ指示を出す
  bool _needGroupShot = true;

  CameraDescription? _currentCamera;

  @override
  void initState() {
    super.initState();

    _loadRemaining();
    _loadGroupShotState();

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

    await old?.dispose();
    await future;
    if (mounted) setState(() {});
  }

  Future<void> _toggleCamera() async {
    if (_switching || _taking) return;
    if (cameras.isEmpty) return;

    final now = _currentCamera;
    if (now == null) return;

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

  Future<void> _loadGroupShotState() async {
    final first = await Api.fetchFirstCreatedAt(widget.pageTitle);
    if (!mounted || first == null) return;
    if (_needGroupShot) {
      setState(() => _needGroupShot = false);
    }
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
        if (_needGroupShot) setState(() => _needGroupShot = false);
        await _loadRemaining();
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

    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    // あなたのUIに近い比率（iPhone 14 っぽい 393x852）
    // カメラ領域: top=109, height=536（852基準）
    final cameraTop = h * (109 / 852);
    final cameraH = h * (536 / 852);

    final shutterTop = h * (667 / 852);
    final shutterLeft = (w - 81) / 2;

    final switchLeft = w * (305 / 393);
    final switchTop = h * (685 / 852);

    final textTop = h * (63 / 852);
    final textLeft = w * (50 / 393);
    final textW = w * (293 / 393);

    final overlayText = _needGroupShot
        ? "５人全員が入った写真を撮ってください"
        : "残り: $_remaining";

    return Scaffold(
      backgroundColor: Colors.black,
      body: (ctrl == null || _initFuture == null)
          ? const Center(
              child: Text("カメラが見つかりません", style: TextStyle(color: Colors.white)),
            )
          : FutureBuilder<void>(
              future: _initFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done ||
                    _switching) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      "カメラ初期化失敗: ${snap.error}",
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }

                return Stack(
                  children: [
                    // 背景黒（あなたのUIのベース）
                    Positioned.fill(child: Container(color: Colors.black)),

                    // カメラ表示エリア（あなたのUIの top=109, height=536 相当）
                    Positioned(
                      left: 0,
                      top: cameraTop,
                      width: w,
                      height: cameraH,
                      child: ClipRect(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: w,
                            height: w / ctrl.value.aspectRatio,
                            child: CameraPreview(ctrl),
                          ),
                        ),
                      ),
                    ),

                    // 上部テキスト（あなたの Text と同じ見た目）
                    Positioned(
                      left: textLeft,
                      top: textTop,
                      width: textW,
                      child: Text(
                        overlayText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w500,
                          height: 1.50,
                          letterSpacing: 0.15,
                        ),
                      ),
                    ),

                    // シャッターボタン（二重丸）
                    Positioned(
                      left: shutterLeft,
                      top: shutterTop,
                      child: GestureDetector(
                        onTap: (_remaining <= 0 || _taking || _switching)
                            ? null
                            : _take,
                        child: Opacity(
                          opacity: (_remaining <= 0 || _taking || _switching)
                              ? 0.5
                              : 1.0,
                          child: Container(
                            width: 81,
                            height: 81,
                            padding: const EdgeInsets.all(5),
                            decoration: ShapeDecoration(
                              color: const Color(0xFF343434),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40.5),
                              ),
                            ),
                            child: Container(
                              width: 71,
                              height: 71,
                              decoration: const ShapeDecoration(
                                color: Colors.white,
                                shape: OvalBorder(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 右下のカメラ切替ボタン（あなたの空Container部分を実装）
                    Positioned(
                      left: switchLeft,
                      top: switchTop,
                      child: GestureDetector(
                        onTap: (_switching || _taking) ? null : _toggleCamera,
                        child: Opacity(
                          opacity: (_switching || _taking) ? 0.5 : 1.0,
                          child: Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.cameraswitch,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    //　撮影中の簡易表示（任意。いらなければ消してOK）
                    if (_taking)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: h * 0.12,
                        child: const Center(
                          child: Text(
                            "撮影中...",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
