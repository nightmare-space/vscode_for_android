class Config {
  Config._();

  /// 包名
  static const String packageName = 'com.nightmare.code';

  static const String versionName = String.fromEnvironment('VERSION');

  static int port = 20000;

  static const String defaultCodeServerVersion = String.fromEnvironment('CSVERSION');
}
