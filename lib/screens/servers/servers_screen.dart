import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ssh_provider.dart';
import '../../models/server_config.dart';
import '../../widgets/glass_widgets.dart';
import 'add_server_screen.dart';
import 'server_detail_screen.dart';

class ServersScreen extends StatelessWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SSHProvider>(
      builder: (context, sshProvider, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('服务器管理', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _navigateToAddServer(context),
              ),
            ],
          ),
          body: sshProvider.servers.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sshProvider.servers.length,
                  itemBuilder: (context, index) {
                    final server = sshProvider.servers[index];
                    final isCurrent = sshProvider.currentServer?.id == server.id;
                    return _buildServerCard(context, server, isCurrent, sshProvider);
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _navigateToAddServer(context),
            icon: const Icon(Icons.add),
            label: const Text('添加服务器'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dns_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('暂无服务器', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('点击下方按钮添加你的第一台服务器', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildServerCard(BuildContext context, ServerConfig server, bool isCurrent, SSHProvider provider) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => _connectOrShowDetail(context, server, provider),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.storage,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${server.username}@${server.host}:${server.port}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                _buildStatusIndicator(isCurrent && provider.isConnected),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (server.useJumpServer)
                  _buildTag('跳板机', Colors.orange),
                if (server.useJumpServer) const SizedBox(width: 8),
                _buildTag('宝塔:${server.baotaPort}', Colors.blue),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _navigateToEditServer(context, server),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () => _confirmDelete(context, server, provider),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(bool connected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: connected ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            connected ? '已连接' : '未连接',
            style: TextStyle(fontSize: 11, color: connected ? Colors.green : Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Future<void> _connectOrShowDetail(BuildContext context, ServerConfig server, SSHProvider provider) async {
    if (provider.currentServer?.id == server.id && provider.isConnected) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ServerDetailScreen(server: server)));
      return;
    }
    final success = await provider.connect(server);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已连接到 ${server.name}')),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('连接失败: ${provider.connectionError ?? "未知错误"}'), backgroundColor: Colors.red),
      );
    }
  }

  void _navigateToAddServer(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddServerScreen()));
  }

  void _navigateToEditServer(BuildContext context, ServerConfig server) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AddServerScreen(editServer: server)));
  }

  void _confirmDelete(BuildContext context, ServerConfig server, SSHProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除服务器'),
        content: Text('确定要删除服务器「${server.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              provider.deleteServer(server.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
