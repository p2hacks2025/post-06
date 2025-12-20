import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../constants.dart';
import 'album_page.dart';

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
    final size = MediaQuery.of(context).size;
    final scale = math.min(size.width / 393, size.height / 852);
    double s(double v) => v * scale;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // 背景
            Positioned.fill(child: Container(color: Colors.white)),

            // QRカメラ（背面）
            Positioned(
              left: s(31),
              right: s(31),
              top: s(154),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // カメラ表示
                  SizedBox(
                    width: double.infinity,
                    height: s(445),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(s(4)),
                      child: MobileScanner(
                        onDetect: (capture) {
                          if (_done) return;
                          final value = capture.barcodes.first.rawValue;
                          if (value == unlockKey) {
                            _done = true;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AlbumPage(pageTitle: widget.pageTitle),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: s(27)),

                  // 説明ボックス
                  Container(
                    width: double.infinity,
                    height: s(173),
                    padding: EdgeInsets.symmetric(
                      horizontal: s(22),
                      vertical: s(8),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(s(4)),
                    ),
                    child: const Center(
                      child: Text(
                        'それぞれが持っているカードを組み合わせて\n'
                        'QRコードを作り、スキャンしてください。',
                        textAlign: TextAlign.center,
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

            // 上部バー
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: s(103),
              child: Container(color: Colors.black),
            ),

            // ロゴ（中央）
            Positioned(
              top: s(35),
              left: (size.width - s(68)) / 2,
              child: SizedBox(
                width: s(68),
                height: s(68),
                child: Image.asset(
                  'images/logo_square.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
