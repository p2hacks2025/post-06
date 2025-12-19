import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../constants.dart';
import '../models/photo_meta.dart';

class Api {
  static Future<int> fetchRemaining(String title) async {
    final uri = Uri.parse(
      "$baseUrl/photos/count?title=${Uri.encodeComponent(title)}",
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return 999;
    final data = jsonDecode(res.body);
    return (data["remaining"] as num).toInt();
  }

  static Future<Uint8List?> fetchFirstImage(String title) async {
    final uri = Uri.parse(
      "$baseUrl/photos/first?title=${Uri.encodeComponent(title)}",
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    return res.bodyBytes;
  }

  static Future<DateTime?> fetchFirstCreatedAt(String title) async {
    final uri = Uri.parse(
      "$baseUrl/photos/first_info?title=${Uri.encodeComponent(title)}",
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body);
    final createdAtStr = (data["created_at"] ?? "").toString();
    final normalized = createdAtStr.replaceFirst(" ", "T");
    return DateTime.tryParse(normalized);
  }

  static Future<List<PhotoMeta>> fetchAlbum(String title) async {
    final uri = Uri.parse(
      "$baseUrl/photos/list?title=${Uri.encodeComponent(title)}",
    );
    final res = await http.get(uri);
    if (res.statusCode != 200)
      throw Exception("album fetch failed: ${res.statusCode}");
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final List items = (data["photos"] as List? ?? const []);
    return items
        .map((e) => PhotoMeta.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveTitleToServer(String title) async {
    final uri = Uri.parse("$baseUrl/site/title");
    final req = http.MultipartRequest("POST", uri)..fields["title"] = title;
    await req.send();
  }

  static Future<String?> fetchSiteTitle() async {
    final uri = Uri.parse("$baseUrl/site/title");
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final exists = (data["exists"] as bool?) ?? false;
    if (!exists) return null;
    final title = (data["title"] ?? "").toString().trim();
    return title.isEmpty ? null : title;
  }

  static Future<Map<String, dynamic>> uploadPhoto({
    required String title,
    required String comment,
    required Uint8List imageBytes,
  }) async {
    final uri = Uri.parse("$baseUrl/upload");
    final req = http.MultipartRequest("POST", uri)
      ..fields["title"] = title
      ..fields["comment"] = comment
      ..files.add(
        http.MultipartFile.fromBytes(
          "file",
          imageBytes,
          filename: "capture.jpg",
        ),
      );

    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 200) {
      return {"ok": false, "status": res.statusCode, "body": res.body};
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
