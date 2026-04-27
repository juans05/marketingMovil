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
  final String? ayrsharePostId;
  final String? processedUrl;
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
    this.ayrsharePostId,
    this.processedUrl,
    required this.createdAt,
  });

  bool get isProcessing => status == 'processing' || status == 'analyzing';
  bool get isError => status == 'error';
  bool get isReady => status == 'ready' || status == 'needs_review';
  bool get isPublished => status == 'published';
  bool get isScheduled => status == 'scheduled';

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    String? thumb = json['thumbnail_url']?.toString();
    final source = json['processed_url']?.toString() ?? json['source_url']?.toString() ?? json['cloudinary_url']?.toString();
    
    // Fallback: Si no hay thumbnail pero hay URL de Cloudinary, generarlo al vuelo
    if ((thumb == null || thumb.isEmpty) && source != null && source.contains('cloudinary.com')) {
      final parts = source.split('/upload/');
      if (parts.length == 2) {
        final basePath = parts[1].replaceAll(RegExp(r'\.[^/.]+$'), '.jpg');
        thumb = '${parts[0]}/upload/so_1.0,w_400,c_limit/$basePath';
      }
    }

    return VideoModel(
      id: json['id']?.toString() ?? '',
      artistId: json['artist_id']?.toString() ?? '',
      title: json['title']?.toString(),
      cloudinaryUrl: json['cloudinary_url']?.toString(),
      thumbnailUrl: thumb,
      processedUrl: json['processed_url']?.toString() ?? source,
      status: json['status']?.toString() ?? 'processing',
      viralScore: json['viral_score'] != null
          ? (json['viral_score'] as num).toDouble()
          : null,
      hookSuggestion: json['hook_suggestion']?.toString(),
      aiCopy: (json['ai_copy_short'] ?? json['ai_copy'])?.toString(),
      hashtags: _parseList(json['hashtags']),
      platforms: _parseList(json['platforms']),
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.tryParse(json['scheduled_at'].toString())
          : null,
      ayrsharePostId: json['ayrshare_post_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static List<String> _parseList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    if (value is String && value.isNotEmpty) {
      // Manejar string JSON tipo ["tag1","tag2"] o [tag1, tag2]
      final s = value.trim();
      if (s.startsWith('[') && s.endsWith(']')) {
        final inner = s.substring(1, s.length - 1);
        return inner
            .split(',')
            .map((e) => e.trim().replaceAll('"', '').replaceAll("'", ''))
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
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
  final int monthlyUsage;
  final int monthlyLimit;
  final String planName;
  final int totalLikes;
  final int totalComments;
  final int totalShares;
  final int totalSaves;
  final Map<String, int> platformBreakdown;

  const StatsModel({
    this.totalFollowers = 0,
    this.followersGrowth = 0,
    this.totalViews = 0,
    this.viewsGrowth = 0,
    this.totalLikes = 0,
    this.totalComments = 0,
    this.totalShares = 0,
    this.totalSaves = 0,
    this.publishedVideos = 0,
    this.avgViralScore = 0,
    this.growthData = const [],
    this.monthlyUsage = 0,
    this.monthlyLimit = 0,
    this.planName = 'Mini',
    this.platformBreakdown = const {},
  });

  factory StatsModel.fromJson(Map<String, dynamic> json) {
    final rawGrowth = json['growth_data'];
    final growthData = rawGrowth is List
        ? rawGrowth
            .map((e) => GrowthPoint.fromJson(e as Map<String, dynamic>))
            .toList()
        : <GrowthPoint>[];

    final breakdown = json['platform_breakdown'];
    final Map<String, int> platforms = {};
    if (breakdown is Map) {
      breakdown.forEach((k, v) {
        platforms[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }

    return StatsModel(
      totalFollowers: (json['total_followers'] as num?)?.toInt() ?? 0,
      followersGrowth: (json['followers_growth'] as num?)?.toDouble() ?? 0,
      totalViews: (json['total_views'] as num?)?.toInt() ?? 0,
      viewsGrowth: (json['views_growth'] as num?)?.toDouble() ?? 0,
      totalLikes: (json['total_likes'] as num?)?.toInt() ?? 0,
      totalComments: (json['total_comments'] as num?)?.toInt() ?? 0,
      totalShares: (json['total_shares'] as num?)?.toInt() ?? 0,
      totalSaves: (json['total_saves'] as num?)?.toInt() ?? 0,
      publishedVideos: (json['published_videos'] as num?)?.toInt() ?? 0,
      avgViralScore: (json['avg_viral_score'] as num?)?.toDouble() ?? 0,
      monthlyUsage: (json['monthly_usage'] as num?)?.toInt() ?? 0,
      monthlyLimit: (json['monthly_limit'] as num?)?.toInt() ?? 0,
      planName: json['plan_name']?.toString() ?? 'Mini',
      growthData: growthData,
      platformBreakdown: platforms,
    );
  }
}

class VideoSnapshot {
  final DateTime timestamp;
  final int views;
  final int likes;

  const VideoSnapshot({
    required this.timestamp,
    required this.views,
    required this.likes,
  });

  factory VideoSnapshot.fromJson(Map<String, dynamic> json) {
    return VideoSnapshot(
      timestamp: DateTime.tryParse(json['snapshot_at']?.toString() ?? '') ?? DateTime.now(),
      views: (json['views'] as num?)?.toInt() ?? 0,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
    );
  }
}

class AnalyticsModel {
  final String videoId;
  final int views;
  final int likes;
  final int comments;
  final int shares;
  final int saves;
  final int reach;
  final int impressions;
  final double engagementRate;
  final List<VideoSnapshot> history;
  final Map<String, int> platformBreakdown;

  const AnalyticsModel({
    required this.videoId,
    this.views = 0,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.saves = 0,
    this.reach = 0,
    this.impressions = 0,
    this.engagementRate = 0,
    this.history = const [],
    this.platformBreakdown = const {},
  });

  factory AnalyticsModel.fromJson(Map<String, dynamic> json) {
    final real = (json['real_metrics'] as Map<String, dynamic>?) ?? json;
    final breakdown = json['platform_breakdown'];
    final Map<String, int> platforms = {};
    if (breakdown is Map) {
      breakdown.forEach((k, v) {
        platforms[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }

    final rawHistory = json['history'] as List?;
    final historyData = rawHistory != null 
      ? rawHistory.map((e) => VideoSnapshot.fromJson(e as Map<String, dynamic>)).toList()
      : <VideoSnapshot>[];

    return AnalyticsModel(
      videoId: json['id']?.toString() ?? json['video_id']?.toString() ?? '',
      views: (real['views'] as num?)?.toInt() ?? 0,
      likes: (real['likes'] as num?)?.toInt() ?? 0,
      comments: (real['comments'] as num?)?.toInt() ?? 0,
      shares: (real['shares'] as num?)?.toInt() ?? 0,
      saves: (real['saves'] as num?)?.toInt() ?? 0,
      reach: (real['reach'] as num?)?.toInt() ?? 0,
      impressions: (real['impressions'] as num?)?.toInt() ?? 0,
      engagementRate: (real['engagement_rate'] as num?)?.toDouble() ?? 0,
      history: historyData,
      platformBreakdown: platforms,
    );
  }
}

