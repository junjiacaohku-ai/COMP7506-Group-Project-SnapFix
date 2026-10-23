import 'package:flutter/material.dart';

import 'api.dart';
import 'pages/archive_page.dart';
import 'pages/home_page.dart';
import 'theme.dart';

void main() {
  runApp(const SnapFixApp());
}

class SnapFixApp extends StatelessWidget {
  const SnapFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapFix 随手修',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  final _api = ApiClient();
  final _archiveKey = GlobalKey<ArchivePageState>();
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(api: _api),
          ArchivePage(key: _archiveKey, api: _api),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          setState(() => _index = index);
          if (index == 1) _archiveKey.currentState?.reload();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner),
            label: '扫描',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: '档案',
          ),
        ],
      ),
    );
  }
}
