import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';
import '../models.dart';
import '../settings.dart';
import '../theme.dart';
import '../ui.dart';
import 'result_page.dart';

class AnalyzingPage extends StatefulWidget {
  const AnalyzingPage({super.key, required this.api, required this.start});

  final ApiClient api;
  final Future<Session> Function() start;

  @override
  State<AnalyzingPage> createState() => _AnalyzingPageState();
}

class _AnalyzingPageState extends State<AnalyzingPage>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _pulse;
  bool? _animationsReduced;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      lowerBound: 0.9,
      upperBound: 1.0,
      value: 1,
    );
    _run();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = context.reduceMotion;
    if (_animationsReduced == reduced) return;
    _animationsReduced = reduced;
    if (reduced) {
      _spin.stop();
      _pulse.stop();
      _pulse.value = 1;
    } else {
      _spin.repeat();
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      final result = await widget.start();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        AppPageRoute(
          child: ResultPage(api: widget.api, session: result),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.isQualityError) {
        _showQualityDialog(error.message);
      } else {
        Navigator.of(context).pop(error.message);
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop('网络异常，请稍后重试');
    }
  }

  void _showQualityDialog(String detail) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.no_photography_outlined,
          color: context.colors.primary,
          size: 38,
        ),
        title: Text(context.tr('照片还不够清晰')),
        content: Text(context.tr(detail), textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(minimumSize: const Size(150, 50)),
            child: Text(context.tr('重新选择照片')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
              child: Column(
                children: [
                  Row(
                    children: [
                      BrandMark(size: 34),
                      SizedBox(width: 10),
                      Text(
                        'SNAPFIX',
                        style: TextStyle(
                          color: context.colors.secondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _buildOrb(),
                  const SizedBox(height: 28),
                  Text(
                    context.tr('正在生成诊断'),
                    style: TextStyle(
                      color: context.colors.text,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 11),
                  Text(
                    context.tr('设备识别、手册检索与安全评估正在处理中'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.secondary,
                      fontSize: 13,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    context.tr('耗时取决于照片与网络状况'),
                    style: TextStyle(color: context.colors.muted, fontSize: 11),
                  ),
                  const Spacer(),
                  const SurfaceCard(
                    radius: 24,
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                    child: Column(
                      children: [
                        _ProcessRow(
                          icon: Icons.document_scanner_outlined,
                          label: '设备与故障识别',
                          description: '辨认设备、铭牌和可见错误码',
                        ),
                        SizedBox(height: 18),
                        _ProcessRow(
                          icon: Icons.menu_book_outlined,
                          label: '手册与安全核验',
                          description: '检索相关资料并检查高风险场景',
                        ),
                        SizedBox(height: 18),
                        _ProcessRow(
                          icon: Icons.format_list_numbered_rounded,
                          label: '生成维修建议',
                          description: '整理是否适合自己修与分步指引',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrb() {
    return SizedBox(
      width: 198,
      height: 198,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ScaleTransition(
            scale: _pulse,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.colors.primary.withValues(alpha: 0.18),
                    context.colors.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          RotationTransition(
            turns: _spin,
            child: SizedBox(
              width: 184,
              height: 184,
              child: CircularProgressIndicator(
                value: 0.78,
                strokeWidth: 2.8,
                strokeCap: StrokeCap.round,
                color: context.colors.primary,
                backgroundColor: Color(0x33A895FF),
              ),
            ),
          ),
          RotationTransition(
            turns: ReverseAnimation(_spin),
            child: SizedBox(
              width: 148,
              height: 148,
              child: CircularProgressIndicator(
                value: 0.24,
                strokeWidth: 1.8,
                strokeCap: StrokeCap.round,
                color: context.colors.accent,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              gradient: context.colors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: context.colors.primary.withValues(alpha: 0.25),
                  blurRadius: 36,
                ),
              ],
            ),
            child: Icon(
              Icons.document_scanner_outlined,
              size: 42,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({
    required this.icon,
    required this.label,
    required this.description,
  });

  final IconData icon;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: context.colors.primary, size: 19),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(label),
                style: TextStyle(
                  color: context.colors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(description),
                style: TextStyle(color: context.colors.secondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
