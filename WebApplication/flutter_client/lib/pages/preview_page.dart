import 'dart:math' as math;
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
    final size = MediaQuery.of(context).size;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final scale = math.min(size.width / 393, size.height / 852);
    double s(double v) => v * scale;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // 背景
            Positioned.fill(child: Container(color: Colors.white)),

            // 上部黒バー
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: s(103),
              child: Container(color: Colors.black),
            ),

            // ロゴ
            Positioned(
              top: s(35),
              left: (size.width - s(68)) / 2,
              child: SizedBox(
                width: s(68),
                height: s(68),
                child: Image.asset('images/logo_square.png', fit: BoxFit.cover),
              ),
            ),

            // メインコンテンツ
            Positioned(
              left: s(30),
              right: s(30),
              top: s(154),
              bottom: 0,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: viewInsets.bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 画像プレビュー
                    SizedBox(
                      width: double.infinity,
                      height: s(445),
                      child: Image.memory(widget.imageBytes, fit: BoxFit.cover),
                    ),

                    SizedBox(height: s(27)),

                    // コメント入力
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(s(4)),
                      ),
                      child: TextField(
                        controller: _comment,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'メッセージを入力（任意）',
                          hintStyle: TextStyle(
                            color: Colors.black.withOpacity(0.38),
                            fontSize: 16,
                            height: 1.5,
                            letterSpacing: 0.15,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: s(12),
                            vertical: s(16),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(s(4)),
                            borderSide: BorderSide(
                              color: Colors.black.withOpacity(0.09),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(s(4)),
                            borderSide: BorderSide(
                              color: Colors.black.withOpacity(0.09),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: s(27)),

                    // 完了ボタン
                    SizedBox(
                      width: double.infinity,
                      height: s(56),
                      child: ElevatedButton(
                        onPressed: _upload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF212121),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(s(4)),
                          ),
                          elevation: 4,
                          padding: EdgeInsets.symmetric(
                            horizontal: s(22),
                            vertical: s(8),
                          ),
                        ),
                        child: const Text(
                          '完了',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.73,
                            letterSpacing: 0.46,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
