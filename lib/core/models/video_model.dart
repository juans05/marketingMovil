class VideoModel {
  final String id;
  final String artistId;
  final String? title;
  final String? cloudinaryUrl;
  final String? thumbnailUrl;
  final String status; // 'processing' | 'ready' | 'published' | 'scheduled'
  final double? viralScore;
  final String? hookSuggestion;
  final String? aiCopy;
  final List<String> hashtags;
  final List<String> platforms;
  final DateTime? scheduledAt;
  final DateTime createdAt;

  const VideoModel({
    required this.id,
    required this.artistId,
    this.title,
    this.cloudinaryUrl,
    this.thumbnailUrl,
    this.status = 'processing',
    this.viralScore,
    this.hookSuggestion,
    this.aiCopy,
    this.hashtags = const [],
    this.platforms = const [],
    this.scheduledAt,
    required this.createdAt,
  });

  bool get isProcessing => status == 'processing';
  bool get isReady => status == 'ready';
  bool get isPublished => status == 'published';
  bool get isScheduled => status == 'scheduled';

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id']?.toString() ?? '',
      artistId: json['artist_id']?.toString() ?? '',
      title: json['title']?.toString(),
      cloudinaryUrl: json['cloudinary_url']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      status: json['status']?.toString() ?? 'processing',
      viralScore: json['viral_score'] != null
          ? (json['viral_score'] as num).toDouble()
          : null,
      hookSuggestion: json['hook_suggestion']?.toString(),
      aiCopy: json['ai_copy']?.toString(),
      hashtags: _parseList(json['hashtags']),
      platforms: _parseList(json['platforms']),
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.tryParse(json['scheduled_at'].toString())
          : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static List<String> _parseList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String && value.isNotEmpty) {
      return value.split(',').map((e) => e.trim()).toList();
    }
    return [];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'artist_id': artistId,
        'title': title,
        'cloudinary_url': cloudinaryUrl,
        'thumbnail_url': thumbnailUrl,
        'status': status,
        'viral_score': viralScore,
        'hook_suggestion': hookSuggestion,
        'ai_copy': aiCopy,
        'hashtags': hashtags,
        'platforms': platforms,
        'scheduled_at': scheduledAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  VideoModel copyWith({
    String? title,
    String? aiCopy,
    List<String>? hashtags,
    List<String>? platforms,
    DateTime? scheduledAt,
    String? status,
  }) {
    return VideoModel(
      id: id,
      artistId: artistId,
      title: title ?? this.title,
      cloudinaryUrl: cloudinaryUrl,
      thumbnailUrl: thumbnailUrl,
      status: status ?? this.status,
      viralScore: viralScore,
      hookSuggestion: hookSuggestion,
      aiCopy: aiCopy ?? this.aiCopy,
      hashtags: hashtags ?? this.hashtags,
      platforms: platforms ?? this.platforms,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt,
    );
  }
}

class GrowthPoint {
  final String date;
  final int followers;
  final int views;

  const GrowthPoint({
    required this.date,
    required this.followers,
    required this.views,
  });

  factory GrowthPoint.fromJson(Map<String, dynamic> json) => GrowthPoint(
        date: json['date']?.toString() ?? '',
        followers: (json['followers'] as num?)?.toInt() ?? 0,
        views: (json['views'] as num?)?.toInt() ?? 0,
      );
}

class StatsModel {
  final int totalFollowers;
  final double followersGrowth;
  final int totalViews;
  final double viewsGrowth;
  final int publishedVideos;
  final double avgViralScore;
  final List<GrowthPoint> growthData;

  const StatsModel({
    this.totalFollowers = 0,
    this.followersGrowth = 0,
    this.totalViews = 0,
    this.viewsGrowth = 0,
    this.publishedVideos = 0,
    this.avgViralScore = 0,
    this.growthData = const [],
  });

  factory StatsModel.fromJson(Map<String, dynamic> json) {
    final rawGrowth = json['growth_data'];
    final growthData = rawGrowth is List
        ? rawGrowth
            .map((e) => GrowthPoint.fromJson(e as Map<String, dynamic>))
            .toList()
        : <GrowthPoint>[];

    return StatsModel(
      totalFollowers: (json['total_followers'] as num?)?.toInt() ?? 0,
      followersGrowth: (json['followers_growth'] as num?)?.toDouble() ?? 0,
      totalViews: (json['total_views'] as num?)?.toInt() ?? 0,
      viewsGrowth: (json['views_growth'] as num?)?.toDouble() ?? 0,
      publishedVideos: (json['published_videos'] as num?)?.toInt() ?? 0,
      avgViralScore: (json['avg_viral_score'] as num?)?.toDouble() ?? 0,
      growthData: growthData,
    );
  }
}

class AnalyticsModel {
  final String videoId;
  final int views;
  final int likes;
  final int comments;
  final int shares;
  final Map<String, int> platformBreakdown;

  const AnalyticsModel({
    required this.videoId,
    this.views = 0,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.platformBreakdown = const {},
  });

  factory AnalyticsModel.fromJson(Map<String, dynamic> json) {
    final breakdown = json['platform_breakdown'];
    final Map<String, int> platforms = {};
    if (breakdown is Map) {
      breakdown.forEach((k, v) {
        platforms[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }
    return AnalyticsModel(
      videoId: json['video_id']?.toString() ?? '',
      views: (json['views'] as num?)?.toInt() ?? 0,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      comments: (json['comments'] as num?)?.toInt() ?? 0,
      shares: (json['shares'] as num?)?.toInt() ?? 0,
      platformBreakdown: platforms,
    );
  }
}
