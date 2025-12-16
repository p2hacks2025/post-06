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
    return Scaffold(
      appBar: AppBar(title: const Text("QRスキャン")),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done) return;
          final value = capture.barcodes.first.rawValue;
          if (value == unlockKey) {
            _done = true;
            Navigator.pushReplacement(
              context,
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
