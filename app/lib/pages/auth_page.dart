import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../api.dart';
import '../auth.dart';
import '../l10n.dart';
import '../settings.dart';
import '../social_auth.dart';
import '../theme.dart';
import '../ui.dart';
import '../util/toast.dart';

enum _AuthMethod { email, apple, google }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.auth});

  final AuthController auth;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _register = false;
  bool _obscurePassword = true;
  _AuthMethod? _pending;
  String? _error;

  bool get _busy => _pending != null;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _selectLanguage(AppLanguage language) async {
    final saved = await AppSettingsScope.of(context).setLanguage(language);
    if (!saved && mounted) {
      showAppToast(context, context.tr('语言偏好保存失败'));
    }
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = _AuthMethod.email;
      _error = null;
    });
    try {
      if (_register) {
        await widget.auth.register(
          _nameController.text,
          _emailController.text,
          _passwordController.text,
        );
      } else {
        await widget.auth.login(
          _emailController.text,
          _passwordController.text,
        );
      }
      TextInput.finishAutofillContext();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法完成操作，请稍后重试');
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  Future<void> _socialLogin(
    _AuthMethod method,
    Future<void> Function() action,
  ) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = method;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code != AuthorizationErrorCode.canceled && mounted) {
        setState(() => _error = 'Apple 登录未完成，请稍后重试');
      }
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled && mounted) {
        setState(() => _error = error.description ?? 'Google 登录未完成，请重试');
      }
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法完成第三方登录，请稍后重试');
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  void _setMode(bool register) {
    if (_busy || _register == register) return;
    setState(() {
      _register = register;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showApple = Platform.isIOS || Platform.isMacOS;
    final showGoogle = SocialAuthService.googleConfigured;
    return Scaffold(
      body: AppBackground(
        glow: false,
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
              children: [
                Row(
                  children: [
                    const BrandMark(size: 34),
                    const SizedBox(width: 10),
                    const Text(
                      'SnapFix',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const Spacer(),
                    _LanguageMenu(
                      current: AppSettingsScope.of(context).language,
                      onSelected: _selectLanguage,
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                Semantics(
                  header: true,
                  child: Text(
                    context.tr(_register ? '创建账号' : '欢迎回来'),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  context.tr('用一张照片，找到家电故障的解决办法。'),
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 26),
                if (showApple || showGoogle) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showApple)
                        _SocialButton(
                          icon: const Icon(Icons.apple, size: 21),
                          label: context.tr('使用 Apple 继续'),
                          pendingLabel: context.tr('正在通过 Apple 登录'),
                          pending: _pending == _AuthMethod.apple,
                          busy: _busy,
                          onPressed: () => _socialLogin(
                            _AuthMethod.apple,
                            widget.auth.loginWithApple,
                          ),
                        ),
                      if (showApple && showGoogle) const SizedBox(height: 10),
                      if (showGoogle)
                        _SocialButton(
                          icon: Image.asset(
                            'assets/branding/google_logo.png',
                            width: 18,
                            height: 18,
                          ),
                          label: context.tr('使用 Google 继续'),
                          pendingLabel: context.tr('正在连接 Google'),
                          pending: _pending == _AuthMethod.google,
                          busy: _busy,
                          onPressed: () => _socialLogin(
                            _AuthMethod.google,
                            widget.auth.loginWithGoogle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          context.tr('或继续使用邮箱'),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                AutofillGroup(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      children: [
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: _register
                              ? Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _AuthField(
                                    controller: _nameController,
                                    hintText: context.tr('你的称呼'),
                                    icon: Icons.person_outline_rounded,
                                    enabled: !_busy,
                                    textInputAction: TextInputAction.next,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    autofillHints: const [AutofillHints.name],
                                    onChanged: (_) => _clearError(),
                                    validator: (value) {
                                      final length = value?.trim().length ?? 0;
                                      if (length == 0 || length > 30) {
                                        return context.tr('昵称需为 1–30 个字符');
                                      }
                                      return null;
                                    },
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                        _AuthField(
                          controller: _emailController,
                          hintText: context.tr('邮箱地址'),
                          icon: Icons.mail_outline_rounded,
                          enabled: !_busy,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          onChanged: (_) => _clearError(),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(email)) {
                              return context.tr('请输入有效的邮箱地址');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _AuthField(
                          controller: _passwordController,
                          hintText: context.tr(
                            _register ? '至少 8 个字符' : '输入账号密码',
                          ),
                          icon: Icons.lock_outline_rounded,
                          enabled: !_busy,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          enableSuggestions: false,
                          autofillHints: [
                            _register
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          onChanged: (_) => _clearError(),
                          suffixIcon: IconButton(
                            onPressed: _busy
                                ? null
                                : () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.secondary,
                              size: 19,
                            ),
                            tooltip: context.tr(
                              _obscurePassword ? '显示密码' : '隐藏密码',
                            ),
                          ),
                          validator: (value) {
                            final length = value?.length ?? 0;
                            if (!_register && length == 0) {
                              return context.tr('请输入密码');
                            }
                            if (_register && length < 8) {
                              return context.tr('密码至少需要 8 个字符');
                            }
                            if (length > 128) {
                              return context.tr('密码不能超过 128 个字符');
                            }
                            return null;
                          },
                          onSubmitted: (_) => _submit(),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: _error == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Semantics(
                            liveRegion: true,
                            child: _ErrorMessage(message: context.tr(_error!)),
                          ),
                        ),
                ),
                const SizedBox(height: 18),
                Semantics(
                  label: context.tr(
                    _pending == _AuthMethod.email
                        ? (_register ? '正在创建账号' : '正在登录')
                        : (_register ? '创建账号' : '继续'),
                  ),
                  button: true,
                  enabled: !_busy,
                  excludeSemantics: true,
                  onTap: _busy ? null : _submit,
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF171322),
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.45,
                        ),
                        disabledForegroundColor: const Color(0xFF171322),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _pending == _AuthMethod.email
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Color(0xFF171322),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(context.tr(_register ? '创建账号' : '继续')),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : () => _setMode(!_register),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 40),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: Text(
                      context.tr(_register ? '已有账号？登录' : '首次使用 SnapFix？创建账号'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () => showPrivacyDialog(context),
                    icon: const Icon(Icons.lock_outline_rounded, size: 14),
                    label: Text(context.tr('账号与数据说明')),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.muted,
                      textStyle: const TextStyle(fontSize: 11),
                      minimumSize: const Size(48, 36),
                    ),
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

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({required this.current, required this.onSelected});

  final AppLanguage current;
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppLanguage>(
      initialValue: current,
      onSelected: onSelected,
      tooltip: context.tr('语言'),
      color: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        for (final language in AppLanguage.values)
          PopupMenuItem(
            value: language,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    language.label,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (language == current)
                  const Icon(
                    Icons.check_rounded,
                    color: AppColors.primary,
                    size: 17,
                  ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.language_rounded,
              size: 15,
              color: AppColors.secondary,
            ),
            const SizedBox(width: 5),
            Text(
              current.label,
              style: const TextStyle(color: AppColors.secondary, fontSize: 11),
            ),
            const Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.enabled,
    required this.validator,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.obscureText = false,
    this.enableSuggestions = true,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool enabled;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<String>? autofillHints;
  final bool obscureText;
  final bool enableSuggestions;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      keyboardAppearance: Brightness.dark,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      autocorrect: false,
      enableSuggestions: enableSuggestions,
      obscureText: obscureText,
      style: const TextStyle(color: AppColors.text, fontSize: 14),
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
        prefixIcon: Icon(icon, size: 19),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 42,
          minHeight: 44,
        ),
        prefixIconColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.error)) return AppColors.red;
          if (states.contains(WidgetState.focused)) return AppColors.primary;
          return AppColors.secondary;
        }),
        suffixIcon: suffixIcon,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        disabledBorder: border(AppColors.border.withValues(alpha: 0.6)),
        focusedBorder: border(AppColors.primary, 1.2),
        errorBorder: border(AppColors.red.withValues(alpha: 0.7)),
        focusedErrorBorder: border(AppColors.red, 1.2),
        errorStyle: const TextStyle(
          color: AppColors.red,
          fontSize: 11,
          height: 1.35,
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.pendingLabel,
    required this.pending,
    required this.busy,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final String pendingLabel;
  final bool pending;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: pending ? pendingLabel : label,
      button: true,
      enabled: !busy,
      excludeSemantics: true,
      onTap: busy ? null : onPressed,
      child: SizedBox(
        height: 46,
        child: OutlinedButton(
          onPressed: busy ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.surfaceRaised,
            foregroundColor: AppColors.text,
            disabledForegroundColor: AppColors.secondary,
            disabledBackgroundColor: AppColors.surfaceRaised,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (pending)
                const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                icon,
              const SizedBox(width: 9),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              color: AppColors.red,
              size: 16,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.red,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
