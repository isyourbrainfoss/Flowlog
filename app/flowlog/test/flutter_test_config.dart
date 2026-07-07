import 'dart:async';
import 'dart:io';

import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  late Directory testSupportDir;

  setUp(() async {
    await FlowlogStorage.resetForTesting();
    testSupportDir = await Directory.systemTemp.createTemp('flowlog_test_support_');
    FlowlogStorage.overrideForTesting(
      FlowlogStorage(
        directoryProvider: () async => testSupportDir,
        migrateLegacy: false,
      ),
    );
  });

  tearDown(() async {
    FlowlogStorage.overrideForTesting(null);
    await FlowlogStorage.resetForTesting();
    if (testSupportDir.existsSync()) {
      await testSupportDir.delete(recursive: true);
    }
  });

  await testMain();
}