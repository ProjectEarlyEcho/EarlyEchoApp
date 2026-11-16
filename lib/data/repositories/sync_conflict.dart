/// An immutable record identity was reused with different content. The stored
/// record is retained; retrying must never silently overwrite either version.
class SyncConflictException implements Exception {
  const SyncConflictException(this.recordType, this.recordId);

  final String recordType;
  final String recordId;

  @override
  String toString() => 'Conflicting $recordType record: $recordId';
}
