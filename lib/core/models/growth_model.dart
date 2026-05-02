class GrowthInsight {
  final String type;
  final String title;
  final String description;
  final double impact;

  const GrowthInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.impact,
  });

  factory GrowthInsight.fromJson(Map<String, dynamic> json) => GrowthInsight(
        type: json['type']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        impact: (json['impact'] as num?)?.toDouble() ?? 0,
      );
}

class BestTimeData {
  final String dayOfWeek;
  final int hour;
  final double reachMultiplier;
  final String recommendation;

  const BestTimeData({
    required this.dayOfWeek,
    required this.hour,
    required this.reachMultiplier,
    required this.recommendation,
  });

  String get formattedHour {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12 ? 'AM' : 'PM';
    return '$h:00 $period';
  }

  factory BestTimeData.fromJson(Map<String, dynamic> json) => BestTimeData(
        dayOfWeek: json['day_of_week']?.toString() ?? '',
        hour: (json['hour'] as num?)?.toInt() ?? 20,
        reachMultiplier: (json['reach_multiplier'] as num?)?.toDouble() ?? 1.0,
        recommendation: json['recommendation']?.toString() ?? '',
      );
}

class ContentStrategyItem {
  final String contentType;
  final String emoji;
  final int recommendedCount;
  final String reason;
  final bool avoid;

  const ContentStrategyItem({
    required this.contentType,
    required this.emoji,
    required this.recommendedCount,
    required this.reason,
    this.avoid = false,
  });

  factory ContentStrategyItem.fromJson(Map<String, dynamic> json) =>
      ContentStrategyItem(
        contentType: json['content_type']?.toString() ?? '',
        emoji: json['emoji']?.toString() ?? '🎬',
        recommendedCount: (json['recommended_count'] as num?)?.toInt() ?? 1,
        reason: json['reason']?.toString() ?? '',
        avoid: json['avoid'] as bool? ?? false,
      );
}

class ABVariant {
  final String id;
  final String caption;
  final int likes;
  final int comments;
  final bool isWinner;

  const ABVariant({
    required this.id,
    required this.caption,
    this.likes = 0,
    this.comments = 0,
    this.isWinner = false,
  });

  factory ABVariant.fromJson(Map<String, dynamic> json) => ABVariant(
        id: json['id']?.toString() ?? '',
        caption: json['caption']?.toString() ?? '',
        likes: (json['likes'] as num?)?.toInt() ?? 0,
        comments: (json['comments'] as num?)?.toInt() ?? 0,
        isWinner: json['is_winner'] as bool? ?? false,
      );
}

class ABTestData {
  final String videoId;
  final List<ABVariant> variants;
  final String? winnerId;
  final bool isComplete;

  const ABTestData({
    required this.videoId,
    required this.variants,
    this.winnerId,
    this.isComplete = false,
  });

  factory ABTestData.fromJson(Map<String, dynamic> json) {
    final variants = (json['variants'] as List? ?? [])
        .map((v) => ABVariant.fromJson(v as Map<String, dynamic>))
        .toList();
    return ABTestData(
      videoId: json['video_id']?.toString() ?? '',
      variants: variants,
      winnerId: json['winner_id']?.toString(),
      isComplete: json['is_complete'] as bool? ?? false,
    );
  }
}

class AdCopyData {
  final String headline;
  final String primaryText;
  final String cta;
  final String platform;

  const AdCopyData({
    required this.headline,
    required this.primaryText,
    required this.cta,
    required this.platform,
  });

  factory AdCopyData.fromJson(Map<String, dynamic> json) => AdCopyData(
        headline: json['headline']?.toString() ?? '',
        primaryText: json['primary_text']?.toString() ?? '',
        cta: json['cta']?.toString() ?? '',
        platform: json['platform']?.toString() ?? 'meta',
      );
}

class ViralScorePoint {
  final DateTime date;
  final double score;
  final String? videoTitle;

  const ViralScorePoint({
    required this.date,
    required this.score,
    this.videoTitle,
  });

  factory ViralScorePoint.fromJson(Map<String, dynamic> json) => ViralScorePoint(
        date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
        score: (json['viral_score'] as num?)?.toDouble() ?? 0,
        videoTitle: json['title']?.toString(),
      );
}
