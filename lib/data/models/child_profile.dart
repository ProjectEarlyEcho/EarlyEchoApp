import '../../domain/scoring_engine.dart';

/// Worker + child details captured on the enrollment screen.
class ChildProfile {
  const ChildProfile({
    this.childName,
    this.cloudChildId,
    required this.childAgeMonths,
    required this.anganwadiId,
    required this.stateCode,
    required this.districtCode,
    this.workerName,
  });

  /// Optional — never transmitted unless explicitly enabled.
  final String? childName;
  final String? cloudChildId;

  /// Required, valid range 12–60 months.
  final int childAgeMonths;

  final String anganwadiId;
  final String stateCode;
  final String districtCode;
  final String? workerName;

  bool get isAgeValid =>
      childAgeMonths >= ScoringEngine.childMinAgeMonths &&
      childAgeMonths <= ScoringEngine.childMaxAgeMonths;

  Map<String, dynamic> toJson() => {
    'child_name': childName,
    'cloud_child_id': cloudChildId,
    'child_age_months': childAgeMonths,
    'anganwadi_id': anganwadiId,
    'state_code': stateCode,
    'district_code': districtCode,
    'worker_name': workerName,
  };

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    return ChildProfile(
      childName: json['child_name'] as String?,
      cloudChildId: json['cloud_child_id'] as String?,
      childAgeMonths: (json['child_age_months'] as num).toInt(),
      anganwadiId: json['anganwadi_id'] as String,
      stateCode: json['state_code'] as String,
      districtCode: json['district_code'] as String,
      workerName: json['worker_name'] as String?,
    );
  }
}
