import 'package:alluwalacademyadmin/core/services/version_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VersionPolicy.compareVersions', () {
    test('normalizes partial versions before comparing', () {
      expect(VersionPolicy.compareVersions('1.0', '1.0.0'), 0);
      expect(VersionPolicy.compareVersions('1.0.9', '1.0.10'), -1);
      expect(VersionPolicy.compareVersions('2.0.0+17', '1.9.9'), 1);
    });
  });

  group('VersionPolicy.evaluate', () {
    test('forces update when live store version is newer', () {
      final decision = VersionPolicy.evaluate(
        forceUpdateEnabled: true,
        enforceLatestStoreVersion: true,
        currentVersion: '1.0.6',
        minimumSupportedVersion: '1.0.0',
        storeUrl: 'https://example.com/store',
        storeVersion: '1.0.7',
        releaseNotes: 'Bug fixes',
        storeCheckAttempted: true,
        storeCheckSucceeded: true,
      );

      expect(decision.updateRequired, isTrue);
      expect(decision.source, VersionGateSource.store);
      expect(decision.displayTargetVersion, '1.0.7');
    });

    test('falls back to remote config minimum when store lookup fails', () {
      final decision = VersionPolicy.evaluate(
        forceUpdateEnabled: true,
        enforceLatestStoreVersion: true,
        currentVersion: '1.0.6',
        minimumSupportedVersion: '1.0.8',
        storeUrl: '',
        storeCheckAttempted: true,
        storeCheckSucceeded: false,
      );

      expect(decision.updateRequired, isTrue);
      expect(decision.source, VersionGateSource.remoteConfig);
      expect(decision.displayTargetVersion, '1.0.8');
    });

    test('does not force update when local build is newer than store', () {
      final decision = VersionPolicy.evaluate(
        forceUpdateEnabled: true,
        enforceLatestStoreVersion: true,
        currentVersion: '1.0.8',
        minimumSupportedVersion: '1.0.0',
        storeUrl: 'https://example.com/store',
        storeVersion: '1.0.7',
        storeCheckAttempted: true,
        storeCheckSucceeded: true,
      );

      expect(decision.updateRequired, isFalse);
      expect(decision.source, VersionGateSource.none);
    });
  });
}
