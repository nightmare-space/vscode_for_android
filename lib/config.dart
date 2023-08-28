import 'http_handler.dart';

class Config {
  Config._();

  /// 包名
  static const String packageName = 'com.nightmare.code';
  static String dioScript = '''
    touch $dioLockFile
            echo -n dart_dio "\$@"
            while [ -f $dioLockFile ]
            do {
              sleep 0.5
            }
            done
            exit''';

  static String versionName = '1.2.1';
}
