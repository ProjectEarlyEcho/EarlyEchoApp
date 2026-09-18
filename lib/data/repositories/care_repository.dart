import 'package:supabase_flutter/supabase_flutter.dart';

class CareChild {
  const CareChild({
    required this.id,
    required this.displayName,
    this.birthDate,
  });

  final String id;
  final String displayName;
  final DateTime? birthDate;

  factory CareChild.fromMap(Map<String, dynamic> map) => CareChild(
    id: map['id'] as String,
    displayName: map['display_name'] as String,
    birthDate: map['birth_date'] == null
        ? null
        : DateTime.tryParse(map['birth_date'] as String),
  );
}

class CareScreeningSession {
  const CareScreeningSession({
    required this.id,
    required this.createdAt,
    required this.analysisStatus,
    this.riskLevel,
  });

  final String id;
  final DateTime createdAt;
  final String analysisStatus;
  final String? riskLevel;

  factory CareScreeningSession.fromMap(Map<String, dynamic> map) =>
      CareScreeningSession(
        id: map['id'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        analysisStatus: map['analysis_status'] as String,
        riskLevel: map['risk_level'] as String?,
      );
}

class CareAppointment {
  const CareAppointment({
    required this.id,
    required this.clinicianId,
    required this.status,
    required this.createdAt,
    this.requestedFor,
    this.startsAt,
    this.reason,
  });

  final String id;
  final String clinicianId;
  final String status;
  final DateTime createdAt;
  final DateTime? requestedFor;
  final DateTime? startsAt;
  final String? reason;

  factory CareAppointment.fromMap(Map<String, dynamic> map) => CareAppointment(
    id: map['id'] as String,
    clinicianId: map['clinician_id'] as String,
    status: map['status'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
    requestedFor: _dateTime(map['requested_for']),
    startsAt: _dateTime(map['starts_at']),
    reason: map['reason'] as String?,
  );
}

class CareConversation {
  const CareConversation({
    required this.id,
    required this.parentId,
    required this.clinicianId,
    required this.updatedAt,
  });

  final String id;
  final String parentId;
  final String clinicianId;
  final DateTime updatedAt;

  factory CareConversation.fromMap(Map<String, dynamic> map) =>
      CareConversation(
        id: map['id'] as String,
        parentId: map['parent_id'] as String,
        clinicianId: map['clinician_id'] as String,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

class CareMessage {
  const CareMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;

  factory CareMessage.fromMap(Map<String, dynamic> map) => CareMessage(
    id: map['id'] as String,
    senderId: map['sender_id'] as String,
    body: map['body'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

class CareClinicalNote {
  const CareClinicalNote({
    required this.id,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String body;
  final DateTime createdAt;

  factory CareClinicalNote.fromMap(Map<String, dynamic> map) =>
      CareClinicalNote(
        id: map['id'] as String,
        body: map['body'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

DateTime? _dateTime(dynamic value) =>
    value == null ? null : DateTime.tryParse(value as String);

class CareRepository {
  const CareRepository(this._client);

  final SupabaseClient _client;

  Future<List<CareChild>> getAccessibleChildren() async {
    final response = await _client
        .from('children')
        .select('id, display_name, birth_date')
        .order('display_name');
    return (response as List)
        .map((row) => CareChild.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<CareScreeningSession>> getScreenings(String childId) async {
    final response = await _client
        .from('screening_sessions')
        .select('id, created_at, analysis_status, risk_level')
        .eq('child_id', childId)
        .order('created_at', ascending: false);
    return (response as List)
        .map(
          (row) => CareScreeningSession.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<CareAppointment>> getAppointments(String childId) async {
    final response = await _client
        .from('appointments')
        .select(
          'id, clinician_id, status, created_at, requested_for, starts_at, reason',
        )
        .eq('child_id', childId)
        .order('created_at', ascending: false);
    return (response as List)
        .map(
          (row) =>
              CareAppointment.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<String>> getClinicianIds(String childId) async {
    final response = await _client
        .from('care_team')
        .select('clinician_id')
        .eq('child_id', childId);
    return (response as List)
        .map((row) => (row as Map)['clinician_id'] as String)
        .toList();
  }

  Future<void> requestAppointment({
    required String childId,
    required String clinicianId,
    required DateTime requestedFor,
    required String reason,
  }) => _client.from('appointments').insert({
    'child_id': childId,
    'clinician_id': clinicianId,
    'requested_for': requestedFor.toUtc().toIso8601String(),
    'reason': reason.trim(),
  });

  Future<void> updateAppointmentStatus(String appointmentId, String status) =>
      _client
          .from('appointments')
          .update({'status': status})
          .eq('id', appointmentId);

  Future<List<CareConversation>> getConversations(String childId) async {
    final response = await _client
        .from('conversations')
        .select('id, parent_id, clinician_id, updated_at')
        .eq('child_id', childId)
        .order('updated_at', ascending: false);
    return (response as List)
        .map(
          (row) =>
              CareConversation.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<CareMessage>> getMessages(String conversationId) async {
    final response = await _client
        .from('messages')
        .select('id, sender_id, body, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at');
    return (response as List)
        .map(
          (row) => CareMessage.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<void> sendMessage(String conversationId, String body) => _client
      .from('messages')
      .insert({'conversation_id': conversationId, 'body': body.trim()});

  Future<List<CareClinicalNote>> getClinicalNotes(String childId) async {
    final response = await _client
        .from('clinical_notes')
        .select('id, body, created_at')
        .eq('child_id', childId)
        .order('created_at', ascending: false);
    return (response as List)
        .map(
          (row) =>
              CareClinicalNote.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<void> createClinicalNote(String childId, String body) => _client
      .from('clinical_notes')
      .insert({'child_id': childId, 'body': body.trim()});
}
