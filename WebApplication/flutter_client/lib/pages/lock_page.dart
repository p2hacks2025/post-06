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

            // ロゴ（仮：最初の画像を流用）
            Positioned(
              top: 35,
              left: (MediaQuery.of(context).size.width - 68) / 2,
              child: SizedBox(
                width: 68,
                height: 68,
                child: _image != null
                    ? Image.asset('images/logo_square.png', fit: BoxFit.cover)
                    : const SizedBox(),
              ),
            ),

            // メインコンテンツ
            Positioned(
              left: 31,
              right: 31,
              top: 154,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 日数テキスト
                  if (_daysText.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: widget.pageTitle,
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w400,
                                height: 1.24,
                                letterSpacing: 0.25,
                              ),
                            ),
                            const TextSpan(
                              text: 'から',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                letterSpacing: 0.15,
                              ),
                            ),
                            TextSpan(
                              text: _daysText
                                  .replaceAll(widget.pageTitle, '')
                                  .replaceAll('から', '')
                                  .replaceAll('日', ''),
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w400,
                                height: 1.24,
                                letterSpacing: 0.25,
                              ),
                            ),
                            const TextSpan(
                              text: '日',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                letterSpacing: 0.15,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 27),

                  // 画像
                  if (_image != null)
                    SizedBox(
                      width: double.infinity,
                      height: 441,
                      child: Image.memory(_image!, fit: BoxFit.cover),
                    ),

                  const SizedBox(height: 27),

                  // ボタン
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              QrScanPage(pageTitle: widget.pageTitle),
                        ),
                      ),
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
                        '思い出をみんなで振り返る',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.73,
                          letterSpacing: 0.46,
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
