import 'package:meta/meta.dart';

/// Local preferences for optional cloud sync.
///
/// Cloud account linkage is **disabled by default** until real E2E sync ships.
@immutable
class SyncConfig {
  const SyncConfig({
    this.accountEnabled = false,
  });

  /// Whether a cloud account is linked for encrypted sync.
  ///
  /// Defaults to [false] so sync remains opt-in.
  final bool accountEnabled;

  factory SyncConfig.fromJson(Map<String, dynamic> json) {
    return SyncConfig(
      accountEnabled: json['accountEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accountEnabled': accountEnabled,
    };
  }

  SyncConfig copyWith({
    bool? accountEnabled,
  }) {
    return SyncConfig(
      accountEnabled: accountEnabled ?? this.accountEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SyncConfig && accountEnabled == other.accountEnabled;
  }

  @override
  int get hashCode => accountEnabled.hashCode;

  @override
  String toString() => 'SyncConfig(accountEnabled: $accountEnabled)';
}