import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'error_code_page.dart';
import 'scan_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.api});

  final ApiClient api;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HealthInfo? _health;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    try {
      final health = await widget.api.health();
      if (!mounted) return;
      setState(() {
        _health = health;
        _offline = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _health = null;
        _offline = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'SnapFix 随手修',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_health?.mock ?? false) const _DemoBadge(),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '先搞懂,再决定',
                style: TextStyle(color: AppColors.secondary, fontSize: 15),
              ),
              const SizedBox(height: 12),
              if (_offline) _OfflineBanner(onRetry: _checkHealth),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ScanPage(api: widget.api)),
                ),
                icon: const Icon(Icons.photo_camera_outlined, size: 24),
                label: const Text('拍照诊断'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ErrorCodePage(api: widget.api),
                  ),
                ),
                icon: const Icon(Icons.tag, size: 22),
                label: const Text('错误码速查'),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  '拍张照片或输入错误码,获取分步维修指引',
                  style: TextStyle(color: AppColors.secondary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x26F5A623),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.amber),
      ),
      child: const Text(
        '演示数据',
        style: TextStyle(
          color: AppColors.amber,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x33F5A623),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.amber),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '未连接后端',
              style: TextStyle(color: AppColors.amber, fontSize: 15),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
