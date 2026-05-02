class ApiConstants {
  ApiConstants._();

  static const String defaultBaseUrl =
      'https://backend-vidalis-production.up.railway.app';

  // Auth
  static const String login = '/api/vidalis/login';
  static const String loginGoogle = '/api/vidalis/google-login';
  static const String refineCopy = '/api/vidalis/refine-copy';
  static const String createAgency = '/api/vidalis/agencies';

  // Artists
  static String artists(String agencyId) => '/api/vidalis/artists/$agencyId';
  static const String createArtist = '/api/vidalis/artists';
  static String deleteArtist(String artistId) =>
      '/api/vidalis/artists/$artistId';
  static String socialSync(String artistId) =>
      '/api/vidalis/artists/$artistId/sync';

  // Content
  static const String upload = '/api/vidalis/upload';
  static String gallery(String artistId) => '/api/vidalis/gallery/$artistId';
  static String video(String videoId) => '/api/vidalis/video/$videoId';
  static String publishStatus(String videoId) =>
      '/api/vidalis/video/$videoId/publish-status';
  static String publishNow(String videoId) =>
      '/api/vidalis/publish-now/$videoId';
  static String schedule(String videoId) =>
      '/api/vidalis/schedule/$videoId';
  static String clips(String parentId) => '/api/vidalis/clips/$parentId';

  // Analytics
  static String stats(String agencyId) => '/api/vidalis/stats/$agencyId';
  static String analytics(String videoId) =>
      '/api/vidalis/analytics/$videoId';

  // Social
  static String socialStatus(String artistId) =>
      '/api/vidalis/social-status/$artistId';
  static String connectSocial(String artistId) =>
      '/api/vidalis/connect-social/$artistId';
  // Cloudinary
  static const String cloudinarySignature = '/api/vidalis/cloudinary-signature';

  // Config pública
  static String config(String key) => '/api/vidalis/config/$key';

  // Growth Pro
  static String growthInsights(String artistId) => '/api/vidalis/artists/$artistId/growth/insights';
  static String growthBestTime(String artistId) => '/api/vidalis/artists/$artistId/growth/best-time';
  static String growthStrategy(String artistId) => '/api/vidalis/artists/$artistId/growth/strategy';
  static String growthViralHistory(String artistId) => '/api/vidalis/artists/$artistId/growth/viral-history';
  static String abVariants(String videoId) => '/api/vidalis/videos/$videoId/ab-variants';
  static String abResult(String videoId) => '/api/vidalis/videos/$videoId/ab-result';
  static String adCopy(String videoId) => '/api/vidalis/videos/$videoId/ad-copy';
}
