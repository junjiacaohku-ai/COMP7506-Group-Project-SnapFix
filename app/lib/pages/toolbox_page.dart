import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../ui.dart';
import 'error_code_page.dart';
import 'scan_page.dart';

class ToolboxPage extends StatefulWidget {
  const ToolboxPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ToolboxPage> createState() => ToolboxPageState();
}

class ToolboxPageState extends State<ToolboxPage> {
  List<ManualInfo>? _manuals;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final manuals = await widget.api.manuals();
      if (!mounted) return;
      setState(() {
        _manuals = manuals;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '手册库暂时无法加载');
    }
  }

  void _openScan() {
    Navigator.of(context).push(AppPageRoute(child: ScanPage(api: widget.api)));
  }

  void _openErrorCode() {
    Navigator.of(context)
        .push(AppPageRoute(child: ErrorCodePage(api: widget.api)));
  }

  void _showSafetyGuide() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.health_and_safety_outlined,
          color: dialogContext.colors.primary,
          size: 32,
        ),
        title: Text(dialogContext.tr('维修前安全检查')),
        content: Text(
          '${dialogContext.tr('• 先断电，再拆面板或接触设备内部。')}\n\n'
          '${dialogContext.tr('• 微波炉高压电容、燃气设备和带电维修应交由专业人员。')}\n\n'
          '${dialogContext.tr('• 出现焦味、冒烟、火花或异常发热时立即停止操作。')}\n\n'
          '${dialogContext.tr('• 保留设备型号和错误码，便于房东或维修师傅核对。')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('知道了')),
          ),
        ],
      ),
    );
  }

  void _openManual(ManualInfo manual) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.menu_book_outlined,
                color: sheetContext.colors.primary,
                size: 30,
              ),
              const SizedBox(height: 16),
              Text(
                manual.title,
                style: TextStyle(
                  color: sheetContext.colors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${manual.brand ?? ''} · ${sheetContext.tr(deviceCategoryLabel(manual.category))}',
                style: TextStyle(
                  color: sheetContext.colors.secondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                sheetContext.tr('输入品牌和错误码，即可检索这本手册中的相关章节与安全提示。'),
                style: TextStyle(
                  color: sheetContext.colors.secondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              GradientButton(
                label: '查询相关维修指引',
                icon: Icons.manage_search_rounded,
                height: 50,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _openErrorCode();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
            children: [
              Text(
                context.tr('工具箱'),
                style: TextStyle(
                  color: context.colors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('从识别故障到核对维修方案'),
                style: TextStyle(color: context.colors.secondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.document_scanner_outlined,
                      title: '拍照诊断',
                      subtitle: '识别设备与可见故障',
                      onTap: _openScan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.tag_rounded,
                      title: '错误码速查',
                      subtitle: '直接检索官方手册',
                      onTap: _openErrorCode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  onTap: _showSafetyGuide,
                  leading: Icon(
                    Icons.health_and_safety_outlined,
                    color: context.colors.primary,
                  ),
                  title: Text(context.tr('维修前安全检查')),
                  subtitle: Text(context.tr('断电、高危场景与停止操作信号')),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.muted,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('手册资料库'),
                      style: TextStyle(
                        color: context.colors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_manuals != null)
                    AppPill(
                      label: context.tr('{count} 条记录', {
                        'count': _manuals!.length,
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                context.tr('诊断引用的资料都可以在这里核对'),
                style: TextStyle(color: context.colors.secondary, fontSize: 12),
              ),
              const SizedBox(height: 14),
              if (_error != null)
                SurfaceCard(
                  child: Column(
                    children: [
                      Text(context.tr(_error!)),
                      TextButton(
                        onPressed: reload,
                        child: Text(context.tr('重试')),
                      ),
                    ],
                  ),
                )
              else if (_manuals == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                for (final manual in _manuals!) ...[
                  SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      onTap: () => _openManual(manual),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          deviceCategoryIcon(manual.category),
                          color: context.colors.primary,
                          size: 21,
                        ),
                      ),
                      title: Text(
                        manual.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${manual.brand ?? ''} · ${context.tr(deviceCategoryLabel(manual.category))}',
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: context.colors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 154),
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: context.colors.primary, size: 22),
              ),
              Text(
                context.tr(title),
                style: TextStyle(
                  color: context.colors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(subtitle),
                style: TextStyle(
                  color: context.colors.secondary,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
