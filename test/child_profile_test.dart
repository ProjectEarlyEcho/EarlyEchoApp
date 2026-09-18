import 'package:earlyecho/data/models/child_profile.dart';
import 'package:flutter_test/flutter_test.dart';

ChildProfile buildProfile({int ageMonths = 28}) {
  return ChildProfile(
    childAgeMonths: ageMonths,
    anganwadiId: 'IN-MP-042',
    stateCode: 'Madhya Pradesh',
    districtCode: 'Indore',
    workerName: 'Asha',
  );
}

void main() {
  group('ChildProfile age validation', () {
    test('accepts the 12–60 month screening range', () {
      expect(buildProfile(ageMonths: 12).isAgeValid, isTrue);
      expect(buildProfile(ageMonths: 36).isAgeValid, isTrue);
      expect(buildProfile(ageMonths: 60).isAgeValid, isTrue);
    });

    test('rejects ages outside the screening range', () {
      expect(buildProfile(ageMonths: 11).isAgeValid, isFalse);
      expect(buildProfile(ageMonths: 61).isAgeValid, isFalse);
    });
  });

  group('ChildProfile JSON', () {
    test('round-trips with an optional child name', () {
      final profile = ChildProfile(
        childName: 'Aarav',
        childAgeMonths: 28,
        anganwadiId: 'IN-MP-042',
        stateCode: 'Madhya Pradesh',
        districtCode: 'Indore',
      );

      final restored = ChildProfile.fromJson(profile.toJson());
      expect(restored.childName, 'Aarav');
      expect(restored.childAgeMonths, 28);
      expect(restored.anganwadiId, 'IN-MP-042');
    });

    test('child name is optional', () {
      final profile = buildProfile();
      expect(profile.childName, isNull);

      final restored = ChildProfile.fromJson(profile.toJson());
      expect(restored.childName, isNull);
    });
  });
}
