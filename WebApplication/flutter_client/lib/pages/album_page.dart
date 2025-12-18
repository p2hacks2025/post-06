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

  static const int _virtualCount = 100000; // 十分大きければOK

  @override
  void initState() {
    super.initState();
    _photosFuture = Api.fetchAlbum(widget.pageTitle);

    // 真ん中から開始（前後どちらにもスワイプ可能）
    _pageController = PageController(initialPage: _virtualCount ~/ 2);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.pageTitle}（アルバム）")),
      body: FutureBuilder<List<PhotoMeta>>(
        future: _photosFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("エラー: ${snap.error}"));
          }

          final photos = snap.data ?? <PhotoMeta>[];
          if (photos.isEmpty) {
            return const Center(child: Text("写真がありません"));
          }

          return Column(
            children: [
              const SizedBox(height: 8),

              // ★ ページ番号表示（ループ対応）
              Text(
                "${_index + 1} / ${photos.length}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _virtualCount,
                  onPageChanged: (page) {
                    setState(() {
                      _index = page % photos.length;
                    });
                  },
                  itemBuilder: (context, page) {
                    final realIndex = page % photos.length;
                    final p = photos[realIndex];

                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: Image.network(
                                "$baseUrl/photos/${p.id}",
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stack) {
                                  return Text("画像読み込み失敗: $error");
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              p.comment.isEmpty
                                  ? "コメント：なし"
                                  : "コメント：${p.comment}",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
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
