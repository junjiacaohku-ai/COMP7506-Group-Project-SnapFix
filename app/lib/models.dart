import 'package:flutter/material.dart';

import 'theme.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
    required this.hasPassword,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String?,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    hasPassword: json['has_password'] as bool? ?? false,
  );

  final String id;
  final String name;
  final String? email;
  final DateTime createdAt;
  final bool hasPassword;

  String get initials {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'S' : trimmed.characters.first.toUpperCase();
  }
}

class AuthResult {
  const AuthResult({required this.token, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    token: json['token'] as String,
    user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
  );

  final String token;
  final AuthUser user;
}

class LoginIdentity {
  const LoginIdentity({required this.provider, required this.createdAt});

  factory LoginIdentity.fromJson(Map<String, dynamic> json) => LoginIdentity(
    provider: json['provider'] as String,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );

  final String provider;
  final DateTime createdAt;
}

class ManualSection {
  const ManualSection({required this.section, required this.text});

  factory ManualSection.fromJson(Map<String, dynamic> json) => ManualSection(
    section: json['section'] as String? ?? '',
    text: json['text'] as String? ?? '',
  );

  final String section;
  final String text;
}

class ManualInfo {
  const ManualInfo({
    required this.title,
    required this.category,
    required this.sections,
    this.brand,
  });

  factory ManualInfo.fromJson(Map<String, dynamic> json) => ManualInfo(
    title: json['title'] as String,
    category: json['category'] as String,
    brand: json['brand'] as String?,
    sections: [
      for (final section in json['sections'] as List? ?? const [])
        ManualSection.fromJson(section as Map<String, dynamic>),
    ],
  );

  final String title;
  final String category;
  final String? brand;
  final List<ManualSection> sections;
}

class HealthInfo {
  const HealthInfo({
    required this.status,
    required this.mock,
    required this.provider,
  });

  factory HealthInfo.fromJson(Map<String, dynamic> json) => HealthInfo(
    status: json['status'] as String? ?? '',
    mock: json['mock'] as bool? ?? false,
    provider: json['provider'] as String? ?? '',
  );

  final String status;
  final bool mock;
  final String provider;
}

class RepairStep {
  RepairStep({
    required this.id,
    required this.idx,
    required this.content,
    required this.citationManual,
    required this.citationSection,
    this.feedback,
  });

  factory RepairStep.fromJson(Map<String, dynamic> json) => RepairStep(
    id: json['id'] as String,
    idx: json['idx'] as int,
    content: json['content'] as String,
    citationManual: json['citation_manual'] as String? ?? '',
    citationSection: json['citation_section'] as String? ?? '',
    feedback: json['feedback'] as String?,
  );

  final String id;
  final int idx;
  final String content;
  final String citationManual;
  final String citationSection;
  String? feedback;
}

class Session {
  const Session({
    required this.id,
    required this.deviceCategory,
    this.brand,
    this.model,
    this.errorCode,
    required this.decision,
    required this.decisionReason,
    required this.safetyRefused,
    required this.diagnosisSource,
    required this.steps,
    required this.createdAt,
    this.confidence,
  });

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    id: json['id'] as String,
    deviceCategory: json['device_category'] as String? ?? '',
    brand: json['brand'] as String?,
    model: json['model'] as String?,
    errorCode: json['error_code'] as String?,
    decision: json['decision'] as String? ?? '',
    decisionReason: json['decision_reason'] as String? ?? '',
    safetyRefused: json['safety_refused'] as bool? ?? false,
    diagnosisSource: json['diagnosis_source'] as String? ?? 'mock',
    confidence: (json['confidence'] as num?)?.toDouble(),
    steps: [
      for (final s in json['steps'] as List? ?? const [])
        RepairStep.fromJson(s as Map<String, dynamic>),
    ],
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );

  final String id;
  final String deviceCategory;
  final String? brand;
  final String? model;
  final String? errorCode;
  final String decision;
  final String decisionReason;
  final bool safetyRefused;
  final String diagnosisSource;
  final double? confidence;
  final List<RepairStep> steps;
  final DateTime createdAt;

  bool get isDemo => diagnosisSource == 'mock';
}

String deviceCategoryLabel(String category) => switch (category) {
  'washing_machine' => '洗衣机',
  'router' => '路由器',
  'microwave' => '微波炉',
  'ikea_furniture' => 'IKEA 家具',
  'water_heater' => '热水器',
  _ => '其他',
};

IconData deviceCategoryIcon(String category) => switch (category) {
  'washing_machine' => Icons.local_laundry_service_outlined,
  'router' => Icons.router_outlined,
  'microwave' => Icons.microwave_outlined,
  'ikea_furniture' => Icons.handyman_outlined,
  'water_heater' => Icons.water_drop_outlined,
  _ => Icons.devices_other_outlined,
};

({String label, Color color, IconData icon}) decisionStyle(
  String decision,
  AppPalette colors,
) => switch (decision) {
  'diy' => (label: '适合自己修', color: colors.green, icon: Icons.handyman_outlined),
  'landlord' => (
    label: '建议找房东',
    color: colors.amber,
    icon: Icons.home_outlined,
  ),
  'professional' => (
    label: '必须找师傅',
    color: colors.red,
    icon: Icons.engineering_outlined,
  ),
  _ => (label: '安全拒答', color: colors.red, icon: Icons.gpp_maybe_outlined),
};

String formatDateTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

String formatRelativeDateTime(DateTime t, String languageCode) {
  final now = DateTime.now();
  final date = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  String two(int v) => v.toString().padLeft(2, '0');
  final time = '${two(t.hour)}:${two(t.minute)}';
  if (date == today) {
    return languageCode == 'zh' ? '今天 $time' : 'Today $time';
  }
  if (date == today.subtract(const Duration(days: 1))) {
    return languageCode == 'zh' ? '昨天 $time' : 'Yesterday $time';
  }
  return formatDateTime(t);
}
