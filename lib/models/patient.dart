class Patient {
  final String id;
  final String name;
  final int age;
  final String gender;
  final String phone;

  /// Measured once by Reception at registration — not part of the
  /// Doctor's per-visit vitals. Nullable: patients registered without
  /// them (or before this field existed) have no recorded value.
  final double? height;
  final double? weight;
  final double? bmi;

  final String medicalHistory;
  final String lifestyle;

  /// staff_id of the Receptionist who registered this patient — a
  /// Receptionist's own patient list is scoped to this (backend-enforced
  /// via GET /patients); other roles see every patient regardless.
  final String? registeredBy;

  /// When this patient was registered — null for patients registered
  /// before this field existed (not backfilled; that date was never
  /// actually recorded for them).
  final DateTime? registeredAt;

  const Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.phone,
    this.height,
    this.weight,
    this.bmi,
    this.medicalHistory = '',
    this.lifestyle = '',
    this.registeredBy,
    this.registeredAt,
  });

  Patient copyWith({
    String? name,
    int? age,
    String? gender,
    String? phone,
    double? height,
    double? weight,
    String? medicalHistory,
    String? lifestyle,
  }) =>
      Patient(
        id: id,
        name: name ?? this.name,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        phone: phone ?? this.phone,
        height: height ?? this.height,
        weight: weight ?? this.weight,
        bmi: bmi,
        medicalHistory: medicalHistory ?? this.medicalHistory,
        lifestyle: lifestyle ?? this.lifestyle,
      );

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
        id: json['patient_id'] as String,
        name: json['name'] as String,
        age: json['age'] as int,
        gender: json['gender'] as String,
        phone: json['phone'] as String,
        height: (json['height'] as num?)?.toDouble(),
        weight: (json['weight'] as num?)?.toDouble(),
        bmi: (json['bmi'] as num?)?.toDouble(),
        medicalHistory: json['medical_history'] as String? ?? '',
        lifestyle: json['lifestyle'] as String? ?? '',
        registeredBy: json['registered_by'] as String?,
        registeredAt: json['registered_at'] == null
            ? null
            : DateTime.parse(json['registered_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'patient_id': id,
        'name': name,
        'age': age,
        'gender': gender,
        'phone': phone,
        'height': height,
        'weight': weight,
        'medical_history': medicalHistory,
        'lifestyle': lifestyle,
      };
}
