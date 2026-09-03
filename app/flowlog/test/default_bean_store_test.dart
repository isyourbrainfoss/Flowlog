import 'dart:io';

import 'package:flowlog/settings/default_bean_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DefaultBeanStore', () {
    late Directory tempDir;
    late DefaultBeanStore store;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('default_bean_store_test');
      store = DefaultBeanStore(
        settingsPath: '${tempDir.path}/flowlog_default_bean.json',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('returns empty bean when file is missing', () async {
      final loaded = await store.load();
      expect(loaded.beanId, isNull);
      expect(loaded.name, isNull);
    });

    test('persists bean id and name', () async {
      await store.save(
        const DefaultBean(beanId: 'bean-eth', name: 'Ethiopia Yirgacheffe'),
      );

      final loaded = await store.load();
      expect(loaded.beanId, 'bean-eth');
      expect(loaded.name, 'Ethiopia Yirgacheffe');
    });

    test('persists name without id', () async {
      await store.save(const DefaultBean(name: 'House Blend'));

      final loaded = await store.load();
      expect(loaded.beanId, isNull);
      expect(loaded.name, 'House Blend');
    });

    test('treats empty strings as missing', () async {
      await store.save(const DefaultBean(beanId: '  ', name: ''));

      final loaded = await store.load();
      expect(loaded.beanId, isNull);
      expect(loaded.name, isNull);
    });

    test('returns empty bean when JSON is invalid', () async {
      File('${tempDir.path}/flowlog_default_bean.json').writeAsStringSync('{');

      final loaded = await store.load();
      expect(loaded.beanId, isNull);
      expect(loaded.name, isNull);
    });
  });
}
