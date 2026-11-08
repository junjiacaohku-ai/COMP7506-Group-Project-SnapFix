import 'package:flutter/material.dart';

import '../api.dart';
import '../auth.dart';
import '../l10n.dart';
import '../models.dart';
import '../settings.dart';
import '../theme.dart';
import '../ui.dart';
import '../util/toast.dart';
import 'account_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.api,
    required this.auth,
    required this.onHistoryTap,
  });

  final ApiClient api;
  final AuthController auth;
  final VoidCallback onHistoryTap;

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

  void _selectLanguage() {
    final settings = AppSettingsScope.of(context);
    _showPreferenceSheet<AppLanguage>(
      title: '选择应用语言',
      options: AppLanguage.values,
      current: settings.language,
      label: (value) => value.label,
      onSelected: settings.setLanguage,
      errorMessage: '语言偏好保存失败',
    );
  }

  void _selectAppearance() {
    final settings = AppSettingsScope.of(context);
    _showPreferenceSheet<AppAppearance>(
      title: '选择外观',
      options: AppAppearance.values,
      current: settings.appearance,
      label: (value) => value.label,
      onSelected: settings.setAppearance,
      errorMessage: '外观偏好保存失败',
    );
  }

  Future<void> _setNotifications(bool value) async {
    final saved = await AppSettingsScope.of(context).setNotifications(value);
    if (!saved && mounted) {
      showAppToast(context, context.tr('通知未开启，请检查系统通知权限'));
    }
  }

  void _showPreferenceSheet<T>({
    required String title,
    required List<T> options,
    required T current,
    required String Function(T) label,
    required Future<bool> Function(T) onSelected,
    required String errorMessage,
  }) {
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
                  sheetContext.tr(title),
                  style: TextStyle(
                    color: sheetContext.colors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            for (final option in options)
              ListTile(
                title: Text(sheetContext.tr(label(option))),
                trailing: current == option
                    ? Icon(
                        Icons.check_rounded,
                        color: sheetContext.colors.primary,
                      )
                    : null,
                onTap: () async {
                  final saved = await onSelected(option);
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  if (!saved && mounted) {
                    showAppToast(context, context.tr(errorMessage));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _setReduceMotion(bool value) async {
    final saved = await AppSettingsScope.of(context).setReduceMotion(value);
    if (!saved && mounted) {
      showAppToast(context, context.tr('动态效果偏好保存失败'));
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('退出当前账号？')),
        content: Text(dialogContext.tr('诊断记录仍会保留在账号中，下次登录可以继续查看。')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.tr('取消')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              dialogContext.tr('退出登录'),
              style: TextStyle(color: dialogContext.colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user;
    if (user == null) return const SizedBox.shrink();
    final colors = context.colors;
    final settings = AppSettingsScope.of(context);
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: reload,
            color: colors.primary,
            backgroundColor: colors.surfaceRaised,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
              children: [
                Text(
                  context.tr('我的'),
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 22),
                SurfaceCard(
                  radius: 26,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: colors.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              user.email ?? context.tr('第三方账号登录'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.secondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              context.tr('加入于 {year} 年 {month} 月', {
                                'year': user.createdAt.year,
                                'month': user.createdAt.month,
                              }),
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _editName,
                        tooltip: context.tr('编辑昵称'),
                        icon: Icon(
                          Icons.edit_outlined,
                          color: colors.primary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _SectionLabel('账号'),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.shield_outlined,
                        title: '账号与安全',
                        subtitle: '登录方式、密码与账号操作',
                        onTap: () => Navigator.of(context).push(
                          AppPageRoute(
                            child: AccountPage(
                              api: widget.api,
                              auth: widget.auth,
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 60),
                      _SettingsTile(
                        icon: Icons.inventory_2_outlined,
                        title: '个人诊断档案',
                        subtitle: _sessionCount == null
                            ? '查看全部诊断与维修进度'
                            : context.tr('{count} 条记录', {
                                'count': _sessionCount,
                              }),
                        onTap: widget.onHistoryTap,
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: reload,
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: Text(context.tr(_error!)),
                  ),
                ],
                const SizedBox(height: 22),
                _SectionLabel('偏好设置'),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.brightness_6_outlined,
                        title: '外观',
                        subtitle: settings.appearance.label,
                        onTap: _selectAppearance,
                      ),
                      const Divider(height: 1, indent: 60),
                      _SettingsTile(
                        icon: Icons.language_rounded,
                        title: '语言',
                        subtitle: settings.language.label,
                        onTap: _selectLanguage,
                      ),
                      const Divider(height: 1, indent: 60),
                      _SettingsTile(
                        icon: Icons.motion_photos_off_outlined,
                        title: '减少动态效果',
                        subtitle: '减少装饰动画和页面过渡',
                        trailing: Switch.adaptive(
                          value: settings.reduceMotion,
                          onChanged: _setReduceMotion,
                        ),
                      ),
                      const Divider(height: 1, indent: 60),
                      _SettingsTile(
                        icon: Icons.notifications_outlined,
                        title: '诊断完成通知',
                        subtitle: '诊断完成后显示本地提醒',
                        trailing: Switch.adaptive(
                          value: settings.notifications,
                          onChanged: _setNotifications,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _SectionLabel('数据与隐私'),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.privacy_tip_outlined,
                        title: '隐私与数据',
                        subtitle: '照片、诊断记录与登录令牌',
                        onTap: () => showPrivacyDialog(context),
                      ),
                      const Divider(height: 1, indent: 60),
                      _SettingsTile(
                        icon: Icons.cloud_sync_outlined,
                        title: '跨设备设置同步',
                        subtitle: '语言、外观与通知偏好随账号同步',
                        trailing: Icon(
                          Icons.check_circle_outline_rounded,
                          color: colors.green,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _SectionLabel('关于'),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SettingsTile(
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
                                ? colors.muted
                                : colors.green,
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 60),
                      _SettingsTile(
                        icon: Icons.info_outline_rounded,
                        title: 'SnapFix 随手修',
                        subtitle: '版本 1.0.0 · Solo',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.red,
                    side: BorderSide(color: colors.red.withValues(alpha: 0.28)),
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
        style: TextStyle(
          color: context.colors.secondary,
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
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: colors.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(title),
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(subtitle),
                    style: TextStyle(color: colors.secondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: colors.muted, size: 20),
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
            style: TextStyle(color: context.colors.text),
            decoration: InputDecoration(
              labelText: context.tr('你的称呼'),
              counterStyle: TextStyle(
                color: context.colors.muted,
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
                style: TextStyle(color: context.colors.red, fontSize: 12),
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
