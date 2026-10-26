import 'dart:io';

import 'package:delivery_app/services/storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('driver_storage_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
    await GetStorage.init();
  });

  setUp(() async {
    await GetStorage().erase();
  });

  test('tokens saved by the old version move to secure storage', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await GetStorage().write('access_token', 'old-access');
    await GetStorage().write('refresh_token', 'old-refresh');

    final s = await StorageService().init();

    expect(s.isLoggedIn(), isTrue);
    expect(s.getAccessToken(), 'old-access');
    expect(s.getRefreshToken(), 'old-refresh');
    expect(GetStorage().read('access_token'), isNull);
    expect(GetStorage().read('refresh_token'), isNull);
    expect(await const FlutterSecureStorage().read(key: 'access_token'), 'old-access');

    // Next launch reads them from secure storage.
    final again = await StorageService().init();
    expect(again.getAccessToken(), 'old-access');
  });

  test('save and clear go through secure storage', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final s = await StorageService().init();
    expect(s.isLoggedIn(), isFalse);

    await s.saveAccessToken('a1');
    await s.saveRefreshToken('r1');
    expect(GetStorage().read('access_token'), isNull);
    expect(await const FlutterSecureStorage().read(key: 'access_token'), 'a1');

    await s.clearAuth();
    expect(s.isLoggedIn(), isFalse);
    expect(await const FlutterSecureStorage().read(key: 'access_token'), isNull);
  });
}
