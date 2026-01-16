// Platform stub for web - provides Platform and File interface for web compilation
class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isLinux => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isFuchsia => false;
}

// Stub File class for web - allows compilation but should never be used on web
// (code using File should be guarded with kIsWeb check)
class File {
  final String path;
  File(this.path);

  Future<bool> exists() async => false;
  Future<int> length() async => 0;
}
