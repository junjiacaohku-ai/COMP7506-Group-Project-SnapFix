import 'package:flutter/material.dart';

import '../api.dart';
import '../auth.dart';
import '../l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../ui.dart';
import '../util/toast.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.api, required this.auth});

  final ApiClient api;
  final AuthController auth;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  List<LoginIdentity>? _identities;
  String? _busyProvider;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final identities = await widget.api.listIdentities();
      if (!mounted) return;
      setState(() {
        _identities = identities;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '账号信息暂时无法加载');
    }
  }

  bool _linked(String provider) =>
      _identities?.any((item) => item.provider == provider) ?? false;

  Future<void> _link(String provider) async {
    if (_busyProvider != null) return;
    setState(() => _busyProvider = provider);
    try {
      if (provider == 'google') {
        await widget.auth.social.linkGoogle();
      } else {
        await widget.auth.social.linkApple();
      }
      await widget.auth.refreshUser();
      await _load();
      if (mounted) showAppToast(context, context.tr('登录方式已绑定'));
    } on ApiException catch (error) {
      if (mounted) showAppToast(context, context.tr(error.message));
    } catch (_) {
      if (mounted) showAppToast(context, context.tr('绑定未完成，请稍后重试'));
    } finally {
      if (mounted) setState(() => _busyProvider = null);
    }
  }

  Future<void> _unlink(String provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('解绑此登录方式？')),
        content: Text(dialogContext.tr('解绑后将无法使用它登录当前账号。')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('取消')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('解绑')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyProvider = provider);
    try {
      await widget.api.unlinkIdentity(provider);
      await _load();
      if (mounted) showAppToast(context, context.tr('登录方式已解绑'));
    } on ApiException catch (error) {
      if (mounted) showAppToast(context, context.tr(error.message));
    } finally {
      if (mounted) setState(() => _busyProvider = null);
    }
  }

  Future<void> _editPassword() async {
    final user = widget.auth.user;
    if (user == null) return;
    final revoked = await showDialog<int>(
      context: context,
      builder: (_) =>
          _PasswordDialog(auth: widget.auth, hasPassword: user.hasPassword),
    );
    if (revoked != null && mounted) {
      await _load();
      if (mounted) {
        showAppToast(
          context,
          context.tr('密码已更新，已退出 {count} 台其他设备', {'count': revoked}),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _DeleteAccountDialog(auth: widget.auth),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user;
    if (user == null) return const SizedBox.shrink();
    final identities = _identities;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('账号与安全'))),
      body: AppBackground(
        glow: false,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(context.tr(_error!)),
                    ),
                  ),
                _SectionTitle('登录方式'),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _MethodTile(
                        icon: Icons.mail_outline_rounded,
                        title: user.email ?? context.tr('邮箱与密码'),
                        subtitle: user.hasPassword ? '已设置密码' : '设置邮箱密码作为备用登录方式',
                        actionLabel: user.hasPassword ? '修改' : '设置',
                        onTap: _editPassword,
                      ),
                      const Divider(height: 1, indent: 58),
                      _MethodTile(
                        icon: Icons.g_mobiledata_rounded,
                        title: 'Google',
                        subtitle: _linked('google') ? '已绑定' : '未绑定',
                        actionLabel: _linked('google') ? '解绑' : '绑定',
                        busy: _busyProvider == 'google',
                        onTap: () => _linked('google')
                            ? _unlink('google')
                            : _link('google'),
                      ),
                      const Divider(height: 1, indent: 58),
                      _MethodTile(
                        icon: Icons.apple,
                        title: 'Apple',
                        subtitle: _linked('apple') ? '已绑定' : '未绑定',
                        actionLabel: _linked('apple') ? '解绑' : '绑定',
                        busy: _busyProvider == 'apple',
                        onTap: () => _linked('apple')
                            ? _unlink('apple')
                            : _link('apple'),
                      ),
                    ],
                  ),
                ),
                if (identities == null && _error == null)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                const SizedBox(height: 28),
                _SectionTitle('账号操作'),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: _SettingsRow(
                    icon: Icons.delete_forever_outlined,
                    title: '删除账号',
                    subtitle: '永久删除账号、诊断档案与云端偏好',
                    titleColor: context.colors.red,
                    onTap: _deleteAccount,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

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

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: Icon(icon, color: context.colors.primary),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        context.tr(subtitle),
        style: TextStyle(color: context.colors.secondary, fontSize: 11),
      ),
      trailing: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(onPressed: onTap, child: Text(context.tr(actionLabel))),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: onTap,
      leading: Icon(icon, color: titleColor ?? context.colors.primary),
      title: Text(
        context.tr(title),
        style: TextStyle(color: titleColor, fontSize: 14),
      ),
      subtitle: Text(
        context.tr(subtitle),
        style: TextStyle(color: context.colors.secondary, fontSize: 11),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.auth, required this.hasPassword});

  final AuthController auth;
  final bool hasPassword;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final revoked = await widget.auth.changePassword(
        widget.hasPassword ? _current.text : null,
        _next.text,
      );
      if (mounted) Navigator.pop(context, revoked);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr(widget.hasPassword ? '修改密码' : '设置邮箱密码')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.hasPassword) _passwordField(_current, '当前密码', false),
            _passwordField(_next, '新密码', true),
            _passwordField(_confirm, '再次输入新密码', true),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  context.tr(_error!),
                  style: TextStyle(color: context.colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(context.tr('取消')),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr('保存')),
        ),
      ],
    );
  }

  Widget _passwordField(
    TextEditingController controller,
    String label,
    bool validateNew,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        obscureText: true,
        decoration: InputDecoration(labelText: context.tr(label)),
        validator: (value) {
          if ((value ?? '').isEmpty) return context.tr('请输入密码');
          if (validateNew && value!.length < 8) {
            return context.tr('密码至少需要 8 个字符');
          }
          if (validateNew && controller == _confirm && value != _next.text) {
            return context.tr('两次输入的密码不一致');
          }
          return null;
        },
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.auth});

  final AuthController auth;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_controller.text != 'DELETE') {
      setState(() => _error = '请输入 DELETE 以确认删除账号');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.auth.deleteAccount();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('永久删除账号？')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('此操作无法撤销。账号、全部诊断档案、登录方式和云端偏好将被永久删除。')),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'DELETE'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                context.tr(_error!),
                style: TextStyle(color: context.colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(context.tr('取消')),
        ),
        FilledButton(
          onPressed: _busy ? null : _delete,
          style: FilledButton.styleFrom(backgroundColor: context.colors.red),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr('永久删除')),
        ),
      ],
    );
  }
}
