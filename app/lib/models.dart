import 'package:flutter/material.dart';

import 'theme.dart';

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
    required this.steps,
    required this.createdAt,
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
  final List<RepairStep> steps;
  final DateTime createdAt;
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

({String label, Color color, IconData icon}) decisionStyle(String decision) =>
    switch (decision) {
      'diy' => (
        label: '适合自己修',
        color: AppColors.green,
        icon: Icons.handyman_outlined,
      ),
      'landlord' => (
        label: '建议找房东',
        color: AppColors.amber,
        icon: Icons.home_outlined,
      ),
      'professional' => (
        label: '必须找师傅',
        color: AppColors.red,
        icon: Icons.engineering_outlined,
      ),
      _ => (
        label: '安全拒答',
        color: AppColors.red,
        icon: Icons.gpp_maybe_outlined,
      ),
    };

String formatDateTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}
