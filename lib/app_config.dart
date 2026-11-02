class AppConfig {
  static const bool isDev = bool.fromEnvironment('IS_DEV', defaultValue: true);
  static const String apiBaseUrl = String.fromEnvironment('API_URL', 
      defaultValue: 'https://world.openfoodfacts.org/api/v2/');
  static const String appUserAgent = 'SmartStoreLite/1.0 - Android - ASU';
}