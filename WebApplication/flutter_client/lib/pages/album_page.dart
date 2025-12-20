import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/api.dart';
import '../models/photo_meta.dart';

class AlbumPage extends StatefulWidget {
  final String pageTitle;
  const AlbumPage({super.key, required this.pageTitle});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  late Future<List<PhotoMeta>> _photosFuture;
  late PageController _pageController;

  int _index = 0;
  static const int _virtualCount = 100000;

  @override
  void initState() {
    super.initState();
    _photosFuture = Api.fetchAlbum(widget.pageTitle);
    _pageController = PageController(initialPage: _virtualCount ~/ 2);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double s(BuildContext context, double v) {
    final size = MediaQuery.of(context).size;
    final scale = math.min(size.width / 393, size.height / 852);
    return v * scale;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<PhotoMeta>>(
        future: _photosFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("エラー: ${snap.error}"));
          }

          final photos = snap.data ?? [];
          if (photos.isEmpty) {
            return const Center(child: Text("写真がありません"));
          }

          return Stack(
            children: [
              /// ===== メイン =====
              Positioned(
                top: s(context, 154),
                left: 0,
                right: 0,
                child: SizedBox(
                  height: s(context, 600),
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _virtualCount,
                    onPageChanged: (p) {
                      setState(() => _index = p % photos.length);
                    },
                    itemBuilder: (context, page) {
                      final p = photos[page % photos.length];

                      return Center(
                        child: SizedBox(
                          width: s(context, 332),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// 画像
                              SizedBox(
                                height: s(context, 445),
                                width: double.infinity,
                                child: Image.network(
                                  "$baseUrl/photos/${p.id}",
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 8),

                              /// タイトル
                              Text(
                                widget.pageTitle,
                                style: const TextStyle(
                                  color: Color(0xFF989898),
                                  fontSize: 12,
                                  height: 1.66,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 4),

                              /// コメント枠
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.black.withOpacity(0.09),
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  p.comment.isEmpty ? "コメント：なし" : p.comment,
                                  style: TextStyle(
                                    color: Colors.black.withOpacity(0.87),
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              /// ===== ヘッダー =====
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: s(context, 103),
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: s(context, 68),
                    height: s(context, 68),
                    child: Image.asset(
                      'images/logo_square.png',
                      fit: BoxFit.cover,
                    ),
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
