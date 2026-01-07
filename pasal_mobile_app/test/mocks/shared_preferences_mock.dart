import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';

void setupMockSharedPreferences([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
}

void setupMockSharedPreferencesAsync([Map<String, Object> values = const {}]) {
  final store = InMemorySharedPreferencesAsync.withData(values);
  SharedPreferencesAsyncPlatform.instance = store;
}
