import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ssh_provider.dart';
import '../providers/app_provider.dart';
import 'servers/servers_screen.dart';
import 'terminal/terminal_screen.dart';
import 'baota/baota_screen.dart';
import 'files/files_screen.dart';
import 'firewall/firewall_screen.dart';
import 'profile/profile_screen.dart';
import '../widgets/glass_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _initialized = false;

  final List<Widget> _screens = [
    const ServersScreen(),
    const TerminalScreen(),
    const BaotaScreen(),
    const FilesScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Provider.of<AppProvider>(context, listen: false).init();
    await Provider.of<SSHProvider>(context, listen: false).init();
    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final sshProvider = Provider.of<SSHProvider>(context);
    final isConnected = sshProvider.isConnected;

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: GlassContainer(
          margin: const EdgeInsets.all(12),
          borderRadius: 24,
          opacity: 0.2,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              if ((index == 1 || index == 2 || index == 3) && !isConnected) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请先连接服务器')),
                );
                return;
              }
              setState(() => _currentIndex = index);
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dns_outlined),
                activeIcon: Icon(Icons.dns),
                label: '服务器',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.terminal_outlined),
                activeIcon: Icon(Icons.terminal),
                label: '终端',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.web_outlined),
                activeIcon: Icon(Icons.web),
                label: '宝塔',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.folder_outlined),
                activeIcon: Icon(Icons.folder),
                label: '文件',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: '我的',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
