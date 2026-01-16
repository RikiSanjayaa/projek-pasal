// Platform utilities with conditional export based on platform
// Uses stub on web, real Platform on native
export 'platform_stub_native.dart'
    if (dart.library.html) 'platform_stub_web.dart';
