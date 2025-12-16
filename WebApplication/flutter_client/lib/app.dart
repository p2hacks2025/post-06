import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/api.dart';
import 'pages/title_input_page.dart';
import 'pages/camera_page.dart';
import 'pages/lock_page.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  Future<String?> _loadTitle() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString("page_title");
    if (t == null || t.trim().isEmpty) return null;
    return t;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _loadTitle(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final title = snap.data;
        if (title == null) return const TitleInputPage();

        return FutureBuilder<int>(
          future: Api.fetchRemaining(title),
          builder: (context, snap2) {
            if (snap2.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final remaining = snap2.data ?? 999;
            return (remaining <= 0)
                ? LockPage(pageTitle: title)
                : CameraPage(pageTitle: title);
          },
        );
      },
    );
  }
}
