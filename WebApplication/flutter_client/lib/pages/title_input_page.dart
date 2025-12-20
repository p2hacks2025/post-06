import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';
import 'camera_page.dart';
import 'lock_page.dart';

class TitleInputPage extends StatefulWidget {
  const TitleInputPage({super.key});

  @override
  State<TitleInputPage> createState() => _TitleInputPageState();
}

class _TitleInputPageState extends State<TitleInputPage> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _next() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("page_title", title);

      await Api.saveTitleToServer(title).timeout(const Duration(seconds: 3));

      final remaining = await Api.fetchRemaining(
        title,
      ).timeout(const Duration(seconds: 3), onTimeout: () => 999);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => remaining <= 0
              ? LockPage(pageTitle: title)
              : CameraPage(pageTitle: title),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("サーバーに接続できません: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenSize = media.size;

    /// 元デザイン基準（iPhone16想定）
    const double designWidth = 393.0;

    /// 横幅基準スケール
    const double designHeight = 852.0;
    final double scale = math.min(
      screenSize.width / designWidth,
      screenSize.height / designHeight,
    );
    double s(double v) => v * scale;

    /// SafeArea 上部余白
    final double safeTop = media.padding.top;

    /// 元UI top:216 を SafeArea 考慮で補正
    final double extraTop = (screenSize.height - s(designHeight))
        .clamp(0.0, double.infinity) /
        2;
    final double correctedTop =
        (s(216) - safeTop + extraTop).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              /// 上位置（補正込み）
              SizedBox(height: correctedTop),

              /// ロゴ画像（簡略化）
              Center(
                child: SizedBox(
                  width: s(286),
                  height: s(216),
                  child: Image.asset(
                    'images/logo_triangle.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),

              SizedBox(height: s(47)),

              /// 入力欄・説明・ボタン
              Center(
                child: SizedBox(
                  width: s(286),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// タイトル入力
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: s(12)),
                        decoration: ShapeDecoration(
                          color: const Color(0xFFF5F5F5),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              width: s(1),
                              color: Colors.black.withValues(alpha: 0.06),
                            ),
                            borderRadius: BorderRadius.circular(s(4)),
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          textAlign: TextAlign.left,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'タイトル',
                            hintStyle: TextStyle(
                              color: Color(0xFF989898),
                              fontSize: 16,
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w400,
                              height: 1.50,
                              letterSpacing: 0.15,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),

                      SizedBox(height: s(3)),

                      /// 説明文
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: s(14)),
                        child: const Text(
                          '思い出のタイトルを記入してください',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Color(0xFF989898),
                            fontSize: 12,
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w400,
                            height: 1.66,
                            letterSpacing: 0.40,
                          ),
                        ),
                      ),

                      SizedBox(height: s(47)),

                      /// 完了ボタン
                      GestureDetector(
                        onTap: _next,
                        child: Container(
                          height: s(36),
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: const Color(0xFFBDBDBD),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(s(4)),
                            ),
                            shadows: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 1,
                                offset: Offset(0, 3),
                                spreadRadius: -2,
                              ),
                              BoxShadow(
                                color: Color(0x23000000),
                                blurRadius: 2,
                                offset: Offset(0, 2),
                              ),
                              BoxShadow(
                                color: Color(0x1E000000),
                                blurRadius: 5,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Text(
                            '完了',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w500,
                              height: 1.71,
                              letterSpacing: 0.40,
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
      ),
    );
  }
}
