class Config {
  Config._();

  /// The package name of the app
  static const String packageName = 'com.nightmare.code';

  static const String versionName = String.fromEnvironment('VERSION');

  static int port = 20000;

  static const String defaultCodeServerVersion = String.fromEnvironment('CSVERSION');

  static String ubuntu = 'ubuntu-jammy-aarch64-pd-v4.7.0.tar.xz';
}
