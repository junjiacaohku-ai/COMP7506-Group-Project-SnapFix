import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../theme.dart';
import '../ui.dart';
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
      if (mounted) showAppToast(context, '无法打开相机或相册，请检查权限');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _startDiagnosis() async {
    final photo = _photo;
    if (photo == null) return;
    final error = await Navigator.of(context).push<String>(
      AppPageRoute(
        child: AnalyzingPage(
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
      appBar: AppBar(title: const Text('新建诊断')),
      body: AppBackground(
        glow: _photo == null,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: _photo == null ? _buildPickers() : _buildPreview(),
          ),
        ),
      ),
    );
  }

  Widget _buildPickers() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        const SizedBox(height: 10),
        const Align(
          alignment: Alignment.centerLeft,
          child: AppPill(label: 'AI 视觉识别', icon: Icons.auto_awesome_rounded),
        ),
        const SizedBox(height: 18),
        const Text(
          '让 AI 看清问题',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 29,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          '对准设备铭牌、错误码或故障部位，\n清晰的照片能让诊断更准确。',
          style: TextStyle(
            color: AppColors.secondary,
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          height: 286,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border),
          ),
          child: const Stack(
            children: [
              Center(child: ScanFrame(size: 172)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Text(
                  '一个镜头，读懂设备状态',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        GradientButton(
          label: '拍摄照片',
          icon: Icons.photo_camera_outlined,
          busy: _picking,
          onPressed: () => _pick(ImageSource.camera),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _picking ? null : () => _pick(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined, size: 21),
          label: const Text('从相册选择'),
        ),
        const SizedBox(height: 24),
        const Row(
          children: [
            Expanded(
              child: _CaptureTip(icon: Icons.wb_sunny_outlined, label: '光线充足'),
            ),
            Expanded(
              child: _CaptureTip(
                icon: Icons.center_focus_strong,
                label: '对焦清晰',
              ),
            ),
            Expanded(
              child: _CaptureTip(icon: Icons.crop_free_rounded, label: '完整入镜'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(_photo!.path), fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x33000000),
                        Colors.transparent,
                        Color(0xAA000000),
                      ],
                      stops: [0, 0.55, 1],
                    ),
                  ),
                ),
                const Positioned(
                  top: 18,
                  left: 18,
                  child: AppPill(
                    label: '照片已就绪',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.green,
                    backgroundColor: Color(0xCC12151D),
                  ),
                ),
                const Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '这张照片看起来不错',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'AI 将识别设备、错误码与可见故障',
                        style: TextStyle(
                          color: Color(0xFFD4D7E0),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        GradientButton(
          label: '开始智能诊断',
          icon: Icons.auto_awesome_rounded,
          onPressed: _startDiagnosis,
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: () => setState(() => _photo = null),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('重新选择'),
        ),
      ],
    );
  }
}

class _CaptureTip extends StatelessWidget {
  const _CaptureTip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.muted, size: 19),
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(color: AppColors.secondary, fontSize: 11),
        ),
      ],
    );
  }
}
