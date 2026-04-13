class ArtistModel {
  final String id;
  final String name;
  final String? genre;
  final String? imageUrl;
  final String? tiktokUrl;
  final String? instagramUrl;
  final String? youtubeUrl;
  final String agencyId;
  // Campos para la IA
  final String? aiGenre;
  final String? aiAudience;
  final String? aiTone;

  const ArtistModel({
    required this.id,
    required this.name,
    this.genre,
    this.imageUrl,
    this.tiktokUrl,
    this.instagramUrl,
    this.youtubeUrl,
    required this.agencyId,
    this.aiGenre,
    this.aiAudience,
    this.aiTone,
  });

  bool get hasTiktok => tiktokUrl != null && tiktokUrl!.isNotEmpty;
  bool get hasInstagram => instagramUrl != null && instagramUrl!.isNotEmpty;
  bool get hasYoutube => youtubeUrl != null && youtubeUrl!.isNotEmpty;

  List<String> get activePlatforms {
    final list = <String>[];
    if (hasTiktok) list.add('tiktok');
    if (hasInstagram) list.add('instagram');
    if (hasYoutube) list.add('youtube');
    return list;
  }

  factory ArtistModel.fromJson(Map<String, dynamic> json) {
    return ArtistModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      genre: json['genre']?.toString(),
      imageUrl: json['image_url']?.toString(),
      tiktokUrl: json['tiktok_url']?.toString(),
      instagramUrl: json['instagram_url']?.toString(),
      youtubeUrl: json['youtube_url']?.toString(),
      agencyId: json['agency_id']?.toString() ?? '',
      aiGenre: json['ai_genre']?.toString(),
      aiAudience: json['ai_audience']?.toString(),
      aiTone: json['ai_tone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'genre': genre,
        'image_url': imageUrl,
        'tiktok_url': tiktokUrl,
        'instagram_url': instagramUrl,
        'youtube_url': youtubeUrl,
        'agency_id': agencyId,
        'ai_genre': aiGenre,
        'ai_audience': aiAudience,
        'ai_tone': aiTone,
      };
}
