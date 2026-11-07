import 'package:flutter/material.dart';

import '../api.dart';
import '../auth.dart';
import '../l10n.dart';
import '../models.dart';
import '../settings.dart';
import '../theme.dart';
import '../ui.dart';
import '../util/toast.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.api, required this.auth});

  final ApiClient api;
  final AuthController auth;

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  HealthInfo? _health;
  int? _sessionCount;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final results = await Future.wait([
        widget.api.health(),
        widget.api.listSessions(),
      ]);
      if (!mounted) return;
      setState(() {
        _health = results[0] as HealthInfo;
        _sessionCount = (results[1] as List<Session>).length;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '部分账号信息暂时无法更新');
    }
  }

  Future<void> _editName() async {
    final user = widget.auth.user;
    if (user == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _EditNameDialog(auth: widget.auth, initialName: user.name),
    );
  }

  void _showPrivacy() => showPrivacyDialog(context);

  void _selectLanguage() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  sheetContext.tr('选择应用语言'),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            for (final language in AppLanguage.values)
              ListTile(
                title: Text(language.label),
                trailing: AppSettingsScope.of(sheetContext).language == language
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () async {
                  final saved = await AppSettingsScope.of(sheetContext)
                      .setLanguage(language);
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  if (!saved && mounted) {
                    showAppToast(context, context.tr('语言偏好保存失败'));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('退出当前账号？')),
        content: Text(context.tr('诊断记录仍会保留在账号中，下次登录可以继续查看。')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('取消')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              context.tr('退出登录'),
              style: const TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.auth.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user;
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: reload,
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceRaised,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
              children: [
                Text(
                  context.tr('我的'),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 24),
                SurfaceCard(
                  radius: 26,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(21),
                        ),
                        child: Text(
                          user.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              user.email ?? context.tr('第三方账号登录'),
                              style: const TextStyle(
                                color: AppColors.secondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              context.tr('加入于 {year} 年 {month} 月', {
                                'year': user.createdAt.year,
                                'month': user.createdAt.month,
                              }),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _editName,
                        tooltip: context.tr('编辑昵称'),
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SurfaceCard(
                  radius: 22,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          context.tr('个人诊断档案'),
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _sessionCount == null
                            ? '—'
                            : context.tr('{count} 条', {'count': _sessionCount}),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: reload,
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: Text(context.tr(_error!)),
                  ),
                ],
                const SizedBox(height: 28),
                const _SectionLabel('账号与数据'),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.person_outline_rounded,
                        title: '编辑昵称',
                        subtitle: user.name,
                        onTap: _editName,
                      ),
                      const Divider(height: 1, indent: 60),
                      _SettingsTile(
                        icon: Icons.language_rounded,
                        title: '语言',
                        subtitle: AppSettingsScope.of(context).language.label,
                        onTap: _selectLanguage,
                      ),
                      const Divider(height: 1, indent: 60),
                      _SettingsTile(
                        icon: Icons.privacy_tip_outlined,
                        title: '隐私与数据',
                        subtitle: '照片、诊断记录与登录令牌',
                        onTap: _showPrivacy,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const _SectionLabel('诊断服务'),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: _SettingsTile(
                    icon: Icons.cloud_outlined,
                    title: _health == null ? '服务状态未知' : '诊断服务已连接',
                    subtitle: _health == null
                        ? '下拉可重新检查'
                        : _health!.mock
                        ? '本地演示数据源'
                        : 'Gemini 在线诊断',
                    trailing: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _health == null
                            ? AppColors.muted
                            : AppColors.green,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const _SectionLabel('关于'),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'SnapFix 随手修',
                    subtitle: '版本 1.0.0 · Solo',
                  ),
                ),
                const SizedBox(height: 30),
                OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: BorderSide(
                      color: AppColors.red.withValues(alpha: 0.28),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: Text(context.tr('退出登录')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 9),
      child: Text(
        context.tr(label),
        style: const TextStyle(
          color: AppColors.secondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(title),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(subtitle),
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.auth, required this.initialName});

  final AuthController auth;
  final String initialName;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty || name.length > 30) {
      setState(() => _error = '昵称需为 1–30 个字符');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.updateName(name);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('编辑昵称')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 30,
            style: const TextStyle(color: AppColors.text),
            decoration: InputDecoration(
              labelText: context.tr('你的称呼'),
              counterStyle: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
              ),
            ),
            onSubmitted: (_) => _save(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.tr(_error!),
                style: const TextStyle(color: AppColors.red, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(context.tr('取消')),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr('保存')),
        ),
      ],
    );
  }
}
