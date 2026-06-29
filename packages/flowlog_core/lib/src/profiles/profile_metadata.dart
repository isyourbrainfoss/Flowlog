import '../models/saved_profile.dart';
import '../models/shot.dart';

/// Metadata fields derived from a [SavedProfile] for repeat-shot prefill.
class ProfileMetadata {
  const ProfileMetadata({
    this.doseG,
    this.yieldG,
    this.grindSetting,
    this.beanId,
    this.waterTempC,
  });

  final double? doseG;
  final double? yieldG;
  final double? grindSetting;
  final String? beanId;
  final double? waterTempC;

  factory ProfileMetadata.fromProfile(SavedProfile profile) {
    return ProfileMetadata(
      doseG: profile.doseG,
      yieldG: profile.yieldG,
      grindSetting: profile.grindSetting,
      beanId: profile.beanId,
      waterTempC: profile.waterTempC,
    );
  }

  factory ProfileMetadata.fromShot(Shot shot) {
    return ProfileMetadata(
      doseG: shot.doseG,
      yieldG: shot.yieldG,
      grindSetting: shot.grindSetting,
      beanId: shot.beanId,
      waterTempC: shot.waterTempC,
    );
  }
}