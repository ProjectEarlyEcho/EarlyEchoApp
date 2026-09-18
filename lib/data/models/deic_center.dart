/// A District Early Intervention Center — referral destination for
/// RED-flagged screenings. Loaded from `assets/data/deic_data.json`.
class DeicCenter {
  const DeicCenter({
    required this.name,
    required this.state,
    required this.district,
    this.contact,
  });

  final String name;
  final String state;
  final String district;
  final String? contact;

  factory DeicCenter.fromJson(Map<String, dynamic> json) {
    return DeicCenter(
      name: json['name'] as String,
      state: json['state'] as String,
      district: json['district'] as String,
      contact: json['contact'] as String?,
    );
  }

  /// Finds the nearest center for a screening location — same district
  /// first, then any center in the same state.
  static DeicCenter? nearest(
    List<DeicCenter> centers, {
    required String state,
    required String district,
  }) {
    for (final c in centers) {
      if (c.state == state && c.district == district) return c;
    }
    for (final c in centers) {
      if (c.state == state) return c;
    }
    return null;
  }
}
