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
  final FocusNode _focusNode = FocusNode();

  // キーボード表示等で画面サイズが変わっても、UIのscale計算を変えないためのキャッシュ
  Size? _frozenSize;

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
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    // ✅ 初回の画面サイズを固定（ここがUIサイズが変わらないための肝）
    _frozenSize ??= media.size;
    final screenSize = _frozenSize!;

    final hasTitle = _controller.text.trim().isNotEmpty;

    const double designWidth = 393.0;
    const double designHeight = 852.0;

    final double scale = math.min(
      screenSize.width / designWidth,
      screenSize.height / designHeight,
    );
    double s(double v) => v * scale;

    final double safeTop = media.padding.top;
    final double safeBottom = media.padding.bottom; // 下部のセーフエリアも考慮

    final double extraTop =
        (screenSize.height - s(designHeight)).clamp(0.0, double.infinity) / 2;

    final double correctedTop = (s(216) - safeTop + extraTop).clamp(
      0.0,
      double.infinity,
    );

    return Scaffold(
      // 変更点1: true にして、キーボードが出たときに画面領域（ViewInsets）を調整可能にする
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,

      // 変更点2: viewInsetsを無視する MediaQuery の上書きを削除
      // これを削除しないと、Flutterがキーボードの高さを認識できず、スクロール計算ができません。
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            // 変更点3: 固定解除。キーボードが出たときだけスクロールできるようにする
            // コンテンツが画面より小さい時はスクロールしない設定
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              // 変更点4: コンテンツの高さを「画面全体の高さ」に強制固定する
              // これにより、キーボードが出ていない時はデザイン通りの配置になり、
              // キーボードが出た時だけ「溢れた分」としてスクロール可能になる。
              height: screenSize.height - safeTop - safeBottom,
              child: Column(
                children: [
                  SizedBox(height: correctedTop),
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
                  Center(
                    child: SizedBox(
                      width: s(286),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                              focusNode: _focusNode,

                              // 変更点5: scrollPadding を適度な値またはデフォルトに戻す
                              // これにより、キーボードが出た時に入力欄が隠れないよう自動で押し上げられる
                              scrollPadding: EdgeInsets.only(
                                bottom: media.viewInsets.bottom + 20,
                              ),

                              style: const TextStyle(
                                fontSize: 16,
                                fontFamily: 'Roboto',
                                color: Colors.black,
                              ),
                              cursorColor: Colors.black,
                              maxLines: 1,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _next(),
                              textAlign: TextAlign.left,
                              onChanged: (_) => setState(() {}),
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
                            ),
                          ),
                          SizedBox(height: s(3)),
                          if (!hasTitle)
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: s(14)),
                              child: const Text(
                                'タイトルを入力してください',
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  color: Color(0xFFB00020),
                                  fontSize: 12,
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.w400,
                                  height: 1.66,
                                  letterSpacing: 0.40,
                                ),
                              ),
                            ),
                          SizedBox(height: s(47)),
                          GestureDetector(
                            onTap: hasTitle ? _next : null,
                            child: Container(
                              height: s(36),
                              alignment: Alignment.center,
                              decoration: ShapeDecoration(
                                color: hasTitle
                                    ? const Color(0xFF212121)
                                    : const Color(0xFFBDBDBD),
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
        ),
      ),
    );
  }
}
