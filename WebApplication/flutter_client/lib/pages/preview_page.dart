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
              height: 103,
              child: Container(color: Colors.black),
            ),

            // ロゴ（仮：画像バイトが無いので placehold 的に Image.memory 使用）
            Positioned(
              top: 35,
              left: (MediaQuery.of(context).size.width - 68) / 2,
              child: SizedBox(
                width: 68,
                height: 68,
                child: Image.asset('images/logo.png', fit: BoxFit.cover),
              ),
            ),

            // メインコンテンツ
            Positioned(
              left: 30,
              right: 30,
              top: 154,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 画像プレビュー
                  SizedBox(
                    width: double.infinity,
                    height: 445,
                    child: Image.memory(widget.imageBytes, fit: BoxFit.cover),
                  ),

                  const SizedBox(height: 27),

                  // コメント入力
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(4),
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: Colors.black.withOpacity(0.09),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: Colors.black.withOpacity(0.09),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 27),

                  // 完了ボタン
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _upload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF212121),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 8,
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
          ],
        ),
      ),
    );
  }
}
