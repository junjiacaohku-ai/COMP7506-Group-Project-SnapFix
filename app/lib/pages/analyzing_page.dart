import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
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
  static const _stages = [
    (icon: Icons.document_scanner_outlined, label: '识别设备', hint: '正在辨认设备与错误码'),
    (icon: Icons.menu_book_outlined, label: '检索手册', hint: '正在查找相关官方手册'),
    (icon: Icons.shield_outlined, label: '安全评估', hint: '正在排查触电、燃气等风险'),
    (icon: Icons.format_list_numbered, label: '整理方案', hint: '正在生成分步维修指引'),
  ];
  static const _stageDuration = Duration(milliseconds: 1000);

  late final AnimationController _spin;
  late final AnimationController _pulse;
  int _activeStage = 0;
  int _doneCount = 0;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      lowerBound: 0.9,
      upperBound: 1.0,
    )..repeat(reverse: true);
    _run();
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    Session? session;
    Object? error;
    final request = () async {
      try {
        session = await widget.start();
      } catch (e) {
        error = e;
      }
    }();

    for (var i = 0; i < _stages.length; i++) {
      if (!mounted) return;
      setState(() => _activeStage = i);
      await Future<void>.delayed(_stageDuration);
      if (!mounted) return;
      setState(() => _doneCount = i + 1);
    }

    await request;
    if (!mounted) return;

    final result = session;
    final failure = error;
    if (result != null) {
      await Navigator.of(context).pushReplacement(
        AppPageRoute(
          child: ResultPage(api: widget.api, session: result),
        ),
      );
    } else if (failure is ApiException && failure.isQualityError) {
      _showQualityDialog(failure.message);
    } else {
      Navigator.of(context)
          .pop(failure is ApiException ? failure.message : '网络异常，请稍后重试');
    }
  }

  void _showQualityDialog(String detail) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.no_photography_outlined,
          color: AppColors.primary,
          size: 38,
        ),
        title: const Text('照片还不够清晰'),
        content: Text(detail, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(minimumSize: const Size(150, 50)),
            child: const Text('重新选择照片'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stages[_activeStage.clamp(0, _stages.length - 1)];
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
              child: Column(
                children: [
                  const Row(
                    children: [
                      BrandMark(size: 34),
                      SizedBox(width: 10),
                      Text(
                        'SNAPFIX AI',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _buildOrb(stage.icon),
                  const SizedBox(height: 26),
                  const Text(
                    '正在分析故障',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    child: Text(
                      stage.hint,
                      key: ValueKey(_activeStage),
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildProgress(),
                  const SizedBox(height: 16),
                  _buildStageList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrb(IconData icon) {
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
                    AppColors.primary.withValues(alpha: 0.18),
                    AppColors.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          RotationTransition(
            turns: _spin,
            child: const SizedBox(
              width: 184,
              height: 184,
              child: CircularProgressIndicator(
                value: 0.78,
                strokeWidth: 2.8,
                strokeCap: StrokeCap.round,
                color: AppColors.primary,
                backgroundColor: Color(0x33A895FF),
              ),
            ),
          ),
          RotationTransition(
            turns: ReverseAnimation(_spin),
            child: const SizedBox(
              width: 148,
              height: 148,
              child: CircularProgressIndicator(
                value: 0.24,
                strokeWidth: 1.8,
                strokeCap: StrokeCap.round,
                color: AppColors.accent,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 36,
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: 42,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Column(
      children: [
        Row(
          children: [
            const Text(
              '诊断进度',
              style: TextStyle(color: AppColors.secondary, fontSize: 12),
            ),
            const Spacer(),
            Text(
              '$_doneCount / ${_stages.length}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            tween: Tween(end: _doneCount / _stages.length),
            builder: (_, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: AppColors.border,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStageList() {
    return SurfaceCard(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        children: [
          for (var i = 0; i < _stages.length; i++) ...[
            _StageRow(
              icon: _stages[i].icon,
              label: _stages[i].label,
              state: i < _doneCount
                  ? _StageState.done
                  : i == _activeStage
                  ? _StageState.active
                  : _StageState.pending,
            ),
            if (i < _stages.length - 1) const SizedBox(height: 13),
          ],
        ],
      ),
    );
  }
}

enum _StageState { pending, active, done }

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.icon,
    required this.label,
    required this.state,
  });

  final IconData icon;
  final String label;
  final _StageState state;

  @override
  Widget build(BuildContext context) {
    final active = state == _StageState.active;
    final done = state == _StageState.done;
    final color = done
        ? AppColors.green
        : active
        ? AppColors.primary
        : AppColors.muted;
    return Row(
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: done
                ? const _StageBadge(
                    key: ValueKey('done'),
                    color: AppColors.green,
                    child: Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: AppColors.background,
                    ),
                  )
                : active
                ? const _StageBadge(
                    key: ValueKey('active'),
                    color: AppColors.primary,
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.background,
                      ),
                    ),
                  )
                : _StageBadge(
                    key: const ValueKey('pending'),
                    color: AppColors.border,
                    child: Icon(icon, size: 16, color: AppColors.muted),
                  ),
          ),
        ),
        const SizedBox(width: 13),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: active || done ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        if (done)
          const Text(
            '完成',
            style: TextStyle(color: AppColors.green, fontSize: 11),
          )
        else if (active)
          const Text(
            '进行中',
            style: TextStyle(color: AppColors.primary, fontSize: 11),
          ),
      ],
    );
  }
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color == AppColors.border ? AppColors.surfaceRaised : color,
        border: Border.all(color: color, width: 1.2),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
