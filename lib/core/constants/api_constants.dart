class ApiConstants {
  ApiConstants._();

  static const String defaultBaseUrl =
      'https://backend-vidalis-production.up.railway.app';

  // Auth
  static const String login = '/api/vidalis/login';
  static const String createAgency = '/api/vidalis/agencies';

  // Artists
  static String artists(String agencyId) => '/api/vidalis/artists/$agencyId';
  static const String createArtist = '/api/vidalis/artists';
  static String deleteArtist(String artistId) =>
      '/api/vidalis/artists/$artistId';

  // Content
  static const String upload = '/api/vidalis/upload';
  static String gallery(String artistId) => '/api/vidalis/gallery/$artistId';
  static String video(String videoId) => '/api/vidalis/video/$videoId';
  static String publishNow(String videoId) =>
      '/api/vidalis/publish-now/$videoId';
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
}
