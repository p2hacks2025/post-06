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
  late final CameraController _controller;
  late final Future<void> _initFuture;

  int _remaining = 0;
  bool _taking = false;

  @override
  void initState() {
    super.initState();

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _initFuture = _controller.initialize();

    // 初期化と並行して残り回数取得
    _loadRemaining();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRemaining() async {
    final r = await Api.fetchRemaining(widget.pageTitle);
    if (!mounted) return;

    if (r <= 0) {
      // もう撮り切ってるなら即ロック画面へ
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
      // 念のため初期化完了を待つ
      await _initFuture;

      final file = await _controller.takePicture();
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
    return Scaffold(
      appBar: AppBar(title: Text("${widget.pageTitle}  残り: $_remaining")),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("カメラ初期化失敗: ${snap.error}"));
          }

          return Column(
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: CameraPreview(_controller),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: (_remaining <= 0 || _taking) ? null : _take,
                      child: Text(_taking ? "撮影中..." : "写真を撮る"),
                    ),

                    // ★ アルバムボタンは削除（撮り切った時だけ開ける仕様にする）
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
