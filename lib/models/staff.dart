import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

enum StaffRole { admin, receptionist, labScientist, doctor }

extension StaffRoleX on StaffRole {
  String get wireValue => switch (this) {
        StaffRole.admin => 'admin',
        StaffRole.receptionist => 'receptionist',
        StaffRole.labScientist => 'lab_scientist',
        StaffRole.doctor => 'doctor',
      };

  static StaffRole fromWire(String value) => switch (value) {
        'admin' => StaffRole.admin,
        'receptionist' => StaffRole.receptionist,
        'lab_scientist' => StaffRole.labScientist,
        'doctor' => StaffRole.doctor,
        _ => throw ArgumentError('Unknown staff role: $value'),
      };

  String get label => switch (this) {
        StaffRole.admin => 'Admin',
        StaffRole.receptionist => 'Receptionist',
        StaffRole.labScientist => 'Lab Scientist',
        StaffRole.doctor => 'Doctor',
      };

  IconData get icon => switch (this) {
        StaffRole.admin => Icons.admin_panel_settings_rounded,
        StaffRole.receptionist => Icons.contact_page_rounded,
        StaffRole.labScientist => Icons.science_rounded,
        StaffRole.doctor => Icons.medical_services_rounded,
      };

  /// Brand-token color for role badges — distinct shades from the
  /// risk palette (never reuse riskLow/Medium/High for role meaning).
  Color get color => switch (this) {
        StaffRole.admin => AppTheme.forest,
        StaffRole.receptionist => AppTheme.midGreen,
        StaffRole.labScientist => AppTheme.deepGreen,
        StaffRole.doctor => AppTheme.primaryGreen,
      };

  /// Landing route once authenticated, keyed by role.
  String get homePath => switch (this) {
        StaffRole.admin => '/admin',
        StaffRole.receptionist => '/patients',
        StaffRole.labScientist => '/lab',
        StaffRole.doctor => '/dashboard',
      };
}

class Staff {
  final String staffId;
  final String name;
  final String email;
  final StaffRole role;
  final String? hospital;
  final String? phone;
  final bool active;

  const Staff({
    required this.staffId,
    required this.name,
    required this.email,
    required this.role,
    this.hospital,
    this.phone,
    this.active = true,
  });

  factory Staff.fromJson(Map<String, dynamic> json) => Staff(
        staffId: json['staff_id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        role: StaffRoleX.fromWire(json['role'] as String),
        hospital: json['hospital'] as String?,
        phone: json['phone'] as String?,
        active: json['active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'staff_id': staffId,
        'name': name,
        'email': email,
        'role': role.wireValue,
        'hospital': hospital,
        'phone': phone,
        'active': active,
      };
}
