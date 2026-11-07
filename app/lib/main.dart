import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api.dart';
import 'auth.dart';
import 'l10n.dart';
import 'pages/archive_page.dart';
import 'pages/auth_page.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'settings.dart';
import 'theme.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  final auth = AuthController(api: api);
  final settings = AppSettings();
  await settings.load();
  runApp(SnapFixApp(api: api, auth: auth, settings: settings));
}

class SnapFixApp extends StatelessWidget {
  const SnapFixApp({
    super.key,
    required this.api,
    required this.auth,
    required this.settings,
  });

  final ApiClient api;
  final AuthController auth;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: settings,
      child: AnimatedBuilder(
        animation: settings,
        builder: (_, _) => MaterialApp(
          title: 'SnapFix',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: settings.appearance.themeMode,
          locale: settings.locale,
          supportedLocales: const [Locale('en'), Locale('zh')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: AuthGate(api: api, auth: auth),
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.api, required this.auth});

  final ApiClient api;
  final AuthController auth;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    widget.auth.restore();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.auth,
      builder: (_, _) {
        if (widget.auth.restoring) return const _RestoringView();
        if (widget.auth.restoreError != null) {
          return _RestoreErrorView(auth: widget.auth);
        }
        if (widget.auth.user == null) {
          return AuthPage(auth: widget.auth);
        }
        return MainScaffold(api: widget.api, auth: widget.auth);
      },
    );
  }
}

class _RestoringView extends StatelessWidget {
  const _RestoringView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 58),
              const SizedBox(height: 22),
              Text(
                context.tr('SnapFix 随手修'),
                style: TextStyle(
                  color: context.colors.text,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestoreErrorView extends StatelessWidget {
  const _RestoreErrorView({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  color: context.colors.primary,
                  size: 48,
                ),
                const SizedBox(height: 20),
                Text(
                  context.tr('暂时无法恢复账号'),
                  style: TextStyle(
                    color: context.colors.text,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr(auth.restoreError!),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.colors.secondary,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: context.tr('重新连接'),
                  icon: Icons.refresh_rounded,
                  onPressed: auth.restore,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: auth.logout,
                  child: Text(context.tr('退出此设备上的账号')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key, required this.api, required this.auth});

  final ApiClient api;
  final AuthController auth;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  final _archiveKey = GlobalKey<ArchivePageState>();
  final _profileKey = GlobalKey<ProfilePageState>();
  int _index = 0;

  void _selectTab(int index) {
    setState(() => _index = index);
    if (index == 1) _archiveKey.currentState?.reload();
    if (index == 2) _profileKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(
            api: widget.api,
            user: widget.auth.user!,
            onProfileTap: () => _selectTab(2),
          ),
          ArchivePage(key: _archiveKey, api: widget.api),
          ProfilePage(
            key: _profileKey,
            api: widget.api,
            auth: widget.auth,
            onHistoryTap: () => _selectTab(1),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 10),
        child: Container(
          height: 68,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: context.colors.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.colors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 30,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.document_scanner_outlined,
                selectedIcon: Icons.document_scanner_rounded,
                label: context.tr('诊断'),
                selected: _index == 0,
                onTap: () => setState(() => _index = 0),
              ),
              _NavItem(
                icon: Icons.inventory_2_outlined,
                selectedIcon: Icons.inventory_2_rounded,
                label: context.tr('档案'),
                selected: _index == 1,
                onTap: () {
                  setState(() => _index = 1);
                  _archiveKey.currentState?.reload();
                },
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: context.tr('我的'),
                selected: _index == 2,
                onTap: () {
                  setState(() => _index = 2);
                  _profileKey.currentState?.reload();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: context.reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: selected
                  ? context.colors.primary.withValues(alpha: 0.13)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 21,
                  color: selected
                      ? context.colors.primary
                      : context.colors.secondary,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? context.colors.primary
                        : context.colors.secondary,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
