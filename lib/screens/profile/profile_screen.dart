import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/ssh_provider.dart';
import '../../widgets/glass_widgets.dart';
import '../firewall/firewall_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppProvider, SSHProvider>(
      builder: (context, appProvider, sshProvider, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text('我的')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildConnectionCard(sshProvider),
              const SizedBox(height: 16),
              _buildSettingsSection(context, appProvider),
              const SizedBox(height: 16),
              _buildToolsSection(context),
              const SizedBox(height: 16),
              _buildAboutSection(),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionCard(SSHProvider provider) {
    final server = provider.currentServer;
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.blue, Colors.pinkAccent]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.dns, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server?.name ?? '未连接',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  server != null ? '${server.username}@${server.host}:${server.port}' : '请在服务器页面选择并连接',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (provider.isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: Colors.green),
                  SizedBox(width: 4),
                  Text('在线', style: TextStyle(fontSize: 11, color: Colors.green)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, AppProvider appProvider) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.settings),
            title: Text('设置', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: Icon(appProvider.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
            title: const Text('深色模式'),
            value: appProvider.themeMode == ThemeMode.dark,
            onChanged: (_) => appProvider.toggleTheme(),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('监控刷新间隔'),
            trailing: DropdownButton<int>(
              value: appProvider.refreshInterval,
              items: const [
                DropdownMenuItem(value: 3, child: Text('3秒')),
                DropdownMenuItem(value: 5, child: Text('5秒')),
                DropdownMenuItem(value: 10, child: Text('10秒')),
                DropdownMenuItem(value: 30, child: Text('30秒')),
              ],
              onChanged: (v) => appProvider.setRefreshInterval(v ?? 5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsSection(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.handyman),
            title: Text('工具', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.security, color: Colors.blue),
            title: const Text('端口/防火墙管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FirewallScreen())),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.terminal, color: Colors.green),
            title: const Text('SSH终端'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => DefaultTabController.of(context).animateTo(1),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.folder, color: Colors.orange),
            title: const Text('文件管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => DefaultTabController.of(context).animateTo(3),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: const Column(
        children: [
          Icon(Icons.info_outline, size: 40, color: Colors.blue),
          SizedBox(height: 12),
          Text('服务器宝塔管理器', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('版本 1.0.0', style: TextStyle(fontSize: 12, color: Colors.grey)),
          SizedBox(height: 8),
          Text(
            '集成SSH终端、服务器监控、宝塔面板、文件管理、防火墙管理于一体的服务器运维工具',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
