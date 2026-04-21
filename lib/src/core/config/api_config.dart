class ApiConfig {
  ApiConfig._();

  static const String defaultBaseUrl = 'https://circulo-dorado.org:6007/api';

  static String get baseUrl => const String.fromEnvironment(
    'FCD_API_BASE_URL',
    defaultValue: defaultBaseUrl,
  );

  static const String googleViewerUrlPrefix =
      'https://docs.google.com/gview?embedded=true&url=';
}
