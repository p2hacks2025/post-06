class PhotoMeta {
  final int id;
  final String comment;

  const PhotoMeta({required this.id, required this.comment});

  factory PhotoMeta.fromJson(Map<String, dynamic> json) {
    return PhotoMeta(
      id: (json["id"] as num).toInt(),
      comment: (json["comment"] ?? "").toString(),
    );
  }
}
