import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../theme.dart';
import '../util/toast.dart';
import 'analyzing_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _picker = ImagePicker();
  XFile? _photo;
  bool _picking = false;

  Future<void> _pick(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final photo = await _picker.pickImage(source: source, maxWidth: 1600);
      if (photo != null) setState(() => _photo = photo);
    } catch (_) {
      if (mounted) showAppToast(context, '无法打开相机或相册,请检查权限');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _startDiagnosis() async {
    final photo = _photo;
    if (photo == null) return;
    final error = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AnalyzingPage(
          api: widget.api,
          start: () => widget.api.analyzeImage(photo.path),
        ),
      ),
    );
    if (error != null && mounted) {
      showAppToast(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('拍照诊断')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _photo == null ? _buildPickers() : _buildPreview(),
        ),
      ),
    );
  }

  Widget _buildPickers() {
    return Column(
      children: [
        const SizedBox(height: 12),
        const Text(
          '对准设备铭牌、错误码或故障部位',
          style: TextStyle(color: AppColors.secondary, fontSize: 15),
        ),
        const SizedBox(height: 24),
        _PickCard(
          icon: Icons.photo_camera_outlined,
          title: '拍照',
          subtitle: '使用相机拍摄设备',
          loading: _picking,
          onTap: () => _pick(ImageSource.camera),
        ),
        const SizedBox(height: 14),
        _PickCard(
          icon: Icons.photo_library_outlined,
          title: '从相册选择',
          subtitle: '选择已有的设备照片',
          loading: _picking,
          onTap: () => _pick(ImageSource.gallery),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Image.file(File(_photo!.path), fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _startDiagnosis,
          icon: const Icon(Icons.bolt_outlined, size: 22),
          label: const Text('开始诊断'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() => _photo = null),
          child: const Text('重新选择'),
        ),
      ],
    );
  }
}

class _PickCard extends StatelessWidget {
  const _PickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: loading ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0x26F5A623),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.amber, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.secondary),
            ],
          ),
        ),
      ),
    );
  }
}
