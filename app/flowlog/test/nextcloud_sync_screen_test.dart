import 'dart:io';

import 'package:flowlog/screens/more/nextcloud_sync.dart';
import 'package:flowlog/sync/flowlog_sync_coordinator.dart';
import 'package:flowlog/sync/nextcloud_settings_store.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class InMemoryNextcloudSettingsStore extends NextcloudSettingsStore {
  InMemoryNextcloudSettingsStore()
      : super(
          settingsPath: _settingsPath,
          credentialsPath: _credentialsPath,
        );

  static final String _settingsPath =
      '${Directory.systemTemp.path}/flowlog_nextcloud_test_settings.json';
  static final String _credentialsPath =
      '${Directory.systemTemp.path}/flowlog_nextcloud_test_credentials.json';

  NextcloudSettings? stagedSettings;
  String? stagedPassword;

  @override
  Future<NextcloudSettings> loadSettings() async {
    return stagedSettings ?? const NextcloudSettings();
  }

  @override
  Future<void> saveSettings(NextcloudSettings settings) async {
    stagedSettings = settings;
  }

  @override
  Future<String?> loadPassword() async {
    return stagedPassword;
  }

  @override
  Future<void> savePassword(String password) async {
    stagedPassword = password;
  }

  @override
  Future<void> clearAll() async {
    stagedSettings = null;
    stagedPassword = null;
  }
}

void main() {
  group('NextcloudSyncScreen', () {
    late FlowlogDatabase db;
    late InMemoryNextcloudSettingsStore store;
    var syncCalls = 0;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      store = InMemoryNextcloudSettingsStore();
      syncCalls = 0;
      FlowlogSyncCoordinator.debugReset();
      FlowlogSyncCoordinator.debugOverride(
        settingsStore: store,
        syncRunner: ({
          required WebDavCredentials credentials,
          required FlowlogDatabase database,
        }) async {
          syncCalls++;
          return NextcloudSyncResult(
            success: true,
            message: 'Synced for ${credentials.username}',
          );
        },
      );
    });

    tearDown(() async {
      FlowlogSyncCoordinator.debugReset();
      await db.close();
      await store.clearAll();
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NextcloudSyncScreen(
              database: db,
              settingsStore: store,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows form fields and test keys', (tester) async {
      await pumpScreen(tester);

      expect(find.byKey(const Key('nextcloud_server_field')), findsOneWidget);
      expect(find.byKey(const Key('nextcloud_username_field')), findsOneWidget);
      expect(find.byKey(const Key('nextcloud_password_field')), findsOneWidget);
      expect(find.byKey(const Key('nextcloud_save_button')), findsOneWidget);
      expect(find.byKey(const Key('nextcloud_sync_now_button')), findsOneWidget);
      expect(find.text('Auto-sync with Nextcloud'), findsOneWidget);
    });

    testWidgets('save settings persists values through store', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(
        find.byKey(const Key('nextcloud_server_field')),
        'https://cloud.example.com',
      );
      await tester.enterText(
        find.byKey(const Key('nextcloud_username_field')),
        'barista',
      );
      await tester.enterText(
        find.byKey(const Key('nextcloud_password_field')),
        'secret-app-password',
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('nextcloud_save_button')));
      await tester.tap(find.byKey(const Key('nextcloud_save_button')));
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (store.stagedSettings != null) {
          break;
        }
      }

      expect(store.stagedSettings?.enabled, isTrue);
      expect(store.stagedSettings?.serverUrl, 'https://cloud.example.com');
      expect(store.stagedSettings?.username, 'barista');
      expect(store.stagedPassword, 'secret-app-password');
    });

    testWidgets('sync now runs coordinator and shows status', (tester) async {
      store.stagedSettings = const NextcloudSettings(
        enabled: true,
        serverUrl: 'https://cloud.example.com',
        username: 'barista',
      );
      store.stagedPassword = 'secret-app-password';

      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('nextcloud_sync_now_button')));
      await tester.pump();
      for (var i = 0; i < 20 && syncCalls == 0; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      expect(syncCalls, 1);
      expect(find.textContaining('Synced for barista'), findsOneWidget);
      expect(store.stagedSettings?.lastSyncMessage, 'Synced for barista');
      expect(store.stagedSettings?.lastSyncedAt, isNotNull);
    });

    testWidgets('shows last sync info from store', (tester) async {
      final syncedAt = DateTime.utc(2026, 7, 4, 12, 30);
      store.stagedSettings = NextcloudSettings(
        serverUrl: 'https://cloud.example.com',
        username: 'barista',
        lastSyncedAt: syncedAt,
        lastSyncMessage: 'All caught up',
      );

      await pumpScreen(tester);

      expect(find.textContaining('All caught up'), findsOneWidget);
      expect(find.textContaining('2026-07-04'), findsOneWidget);
    });
  });
}