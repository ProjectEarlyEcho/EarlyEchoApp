import 'dart:convert';

import 'biomarker_result.dart';

/// A completed screening session, persisted to SQLite locally and synced
/// to Supabase when connectivity is available.
///
/// Only numeric biomarker values are stored — never audio.
class SessionModel {
  const SessionModel({
    required this.id,
    required this.anganwadiId,
    required this.childAgeMonths,
    required this.sessionDate,
    required this.riskLevel,
    required this.vttlMs,
    required this.pfvStd,
    required this.cvrRatio,
    required this.vttlFlagged,
    required this.pfvFlagged,
    required this.cvrFlagged,
    required this.audioSourceUsed,
    required this.stateCode,
    required this.districtCode,
    this.workerName,
    this.childName,
    this.cloudChildId,
    this.syncedToCloud = false,
    this.decisionTrace = const {},
  });

  final String id;
  final String anganwadiId;
  final String? workerName;
  final String? childName;
  final String? cloudChildId;
  final int childAgeMonths;
  final DateTime sessionDate;
  final RiskLevel riskLevel;
  final double vttlMs;
  final double pfvStd;
  final double cvrRatio;
  final bool vttlFlagged;
  final bool pfvFlagged;
  final bool cvrFlagged;
  final String audioSourceUsed;
  final bool syncedToCloud;
  final String stateCode;
  final String districtCode;

  /// Debug metadata from the native pipeline (kept for quality review).
  final Map<String, dynamic> decisionTrace;

  /// Row representation for the local `sessions` SQLite table.
  Map<String, dynamic> toMap() => {
    'id': id,
    'anganwadi_id': anganwadiId,
    'state_code': stateCode,
    'worker_name': workerName,
    'child_name': childName,
    'cloud_child_id': cloudChildId,
    'child_age_months': childAgeMonths,
    'session_date': sessionDate.toIso8601String(),
    'risk_level': riskLevel.name,
    'vttl_ms': vttlMs,
    'pfv_std': pfvStd,
    'cvr_ratio': cvrRatio,
    'vttl_flagged': vttlFlagged ? 1 : 0,
    'pfv_flagged': pfvFlagged ? 1 : 0,
    'cvr_flagged': cvrFlagged ? 1 : 0,
    'audio_source': audioSourceUsed,
    'synced': syncedToCloud ? 1 : 0,
    'district_code': districtCode,
    'decision_trace': jsonEncode(decisionTrace),
  };

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    return SessionModel(
      id: map['id'] as String,
      anganwadiId: map['anganwadi_id'] as String,
      stateCode: map['state_code'] as String,
      workerName: map['worker_name'] as String?,
      childName: map['child_name'] as String?,
      cloudChildId: map['cloud_child_id'] as String?,
      childAgeMonths: (map['child_age_months'] as num).toInt(),
      sessionDate: DateTime.parse(map['session_date'] as String),
      riskLevel: RiskLevel.values.byName(map['risk_level'] as String),
      vttlMs: (map['vttl_ms'] as num).toDouble(),
      pfvStd: (map['pfv_std'] as num).toDouble(),
      cvrRatio: (map['cvr_ratio'] as num).toDouble(),
      vttlFlagged: (map['vttl_flagged'] as num) == 1,
      pfvFlagged: (map['pfv_flagged'] as num) == 1,
      cvrFlagged: (map['cvr_flagged'] as num) == 1,
      audioSourceUsed: map['audio_source'] as String? ?? '',
      syncedToCloud: (map['synced'] as num) == 1,
      districtCode: map['district_code'] as String,
      decisionTrace: _decodeTrace(map['decision_trace']),
    );
  }

  /// JSON representation for the Supabase `screenings` table.
  Map<String, dynamic> toJson() => {
    'id': id,
    'anganwadi_id': anganwadiId,
    'state_code': stateCode,
    'district_code': districtCode,
    'child_age_months': childAgeMonths,
    'risk_level': riskLevel.name,
    'vttl_ms': vttlMs,
    'pfv_std': pfvStd,
    'cvr_ratio': cvrRatio,
    'vttl_flagged': vttlFlagged,
    'pfv_flagged': pfvFlagged,
    'cvr_flagged': cvrFlagged,
    'audio_source': audioSourceUsed,
    'session_date': sessionDate.toIso8601String(),
  };

  Map<String, dynamic> toDashboardJson() {
    final childId = cloudChildId;
    if (childId == null) {
      throw StateError('Select an assigned child before syncing a screening.');
    }
    return {
      'id': id,
      'child_id': childId,
      'analysis_status': 'COMPLETE',
      'risk_level': riskLevel.name,
      'child_age_months': childAgeMonths,
      'vttl_ms': vttlMs,
      'pfv_std': pfvStd,
      'cvr_ratio': cvrRatio,
      'audio_source': audioSourceUsed,
      'decision_trace': decisionTrace,
      'quality_reasons': const <String>[],
    };
  }

  static Map<String, dynamic> _decodeTrace(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    return const {};
  }
}
