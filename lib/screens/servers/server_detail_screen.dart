import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/server_config.dart';
import '../../models/server_stats.dart';
import '../../providers/ssh_provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/glass_widgets.dart';
import '../firewall/firewall_screen.dart';

class ServerDetailScreen extends StatefulWidget {
  final ServerConfig server;
  const ServerDetailScreen({super.key, required this.server});

  @override
  State<ServerDetailScreen> createState() => _ServerDetailScreenState();
}

class _ServerDetailScreenState extends State<ServerDetailScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SSHProvider>(context, listen: false).refreshStats();
      _startAutoRefresh();
    });
  }

  void _startAutoRefresh() {
    final interval = Provider.of<AppProvider>(context, listen: false).refreshInterval;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: interval), (_) {
      if (mounted) Provider.of<SSHProvider>(context, listen: false).refreshStats();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SSHProvider>(
      builder: (context, provider, _) {
        final stats = provider.currentStats;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(widget.server.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => provider.refreshStats(),
              ),
              IconButton(
                icon: const Icon(Icons.security_outlined),
                tooltip: '端口/防火墙',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FirewallScreen())),
              ),
            ],
          ),
          body: stats == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSystemInfo(stats),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        StatCard(
                          icon: Icons.memory,
                          title: 'CPU使用率',
                          value: '${stats.cpuUsage.toStringAsFixed(1)}%',
                          subtitle: '${stats.cpuCores} 核心',
                          color: Colors.blue,
                          progress: stats.cpuUsage,
                        ),
                        StatCard(
                          icon: Icons.sd_storage,
                          title: '内存使用率',
                          value: '${stats.memoryUsage.toStringAsFixed(1)}%',
                          subtitle: '${_formatBytes(stats.memoryUsed)}/${_formatBytes(stats.memoryTotal)}',
                          color: Colors.pink,
                          progress: stats.memoryUsage,
                        ),
                        StatCard(
                          icon: Icons.swap_horiz,
                          title: 'Swap使用率',
                          value: '${stats.swapUsage.toStringAsFixed(1)}%',
                          subtitle: '${_formatBytes(stats.swapUsed)}/${_formatBytes(stats.swapTotal)}',
                          color: Colors.orange,
                          progress: stats.swapUsage,
                        ),
                        StatCard(
                          icon: Icons.speed,
                          title: '系统负载',
                          value: stats.load1.toStringAsFixed(2),
                          subtitle: '${stats.load5.toStringAsFixed(2)} / ${stats.load15.toStringAsFixed(2)}',
                          color: Colors.teal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildNetworkCard(stats),
                    const SizedBox(height: 16),
                    _buildDiskCard(stats),
                    const SizedBox(height: 16),
                    _buildProcessCard(stats),
                    const SizedBox(height: 24),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSystemInfo(ServerStats stats) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('系统信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.computer, '主机名', stats.hostname),
          _buildInfoRow(Icons.system_update_alt, '操作系统', '${stats.osName} ${stats.osVersion}'),
          _buildInfoRow(Icons.developer_board, '内核版本', stats.kernel),
          _buildInfoRow(Icons.schedule, '运行时间', stats.uptimeString),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildNetworkCard(ServerStats stats) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.network_cell, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('网络流量', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(stats.network.interface, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildNetworkItem(Icons.arrow_downward, '下载', _formatBytes(stats.network.rxBytes), Colors.green),
              ),
              Expanded(
                child: _buildNetworkItem(Icons.arrow_upward, '上传', _formatBytes(stats.network.txBytes), Colors.blue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildDiskCard(ServerStats stats) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage, size: 20, color: Colors.purple),
              const SizedBox(width: 8),
              const Text('磁盘使用', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...stats.disks.map((disk) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${disk.filesystem} (${disk.mountPoint})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        Text('${disk.usagePercent.toStringAsFixed(0)}%', style: TextStyle(fontSize: 13, color: disk.usagePercent > 80 ? Colors.red : Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: disk.usagePercent / 100,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(disk.usagePercent > 80 ? Colors.red : Colors.blue),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${_formatBytes(disk.used)} / ${_formatBytes(disk.total)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildProcessCard(ServerStats stats) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, size: 20, color: Colors.teal),
              const SizedBox(width: 8),
              const Text('进程列表 (Top CPU)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...stats.processes.take(8).map((proc) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(width: 50, child: Text('${proc.pid}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                    SizedBox(width: 70, child: Text(proc.user, style: TextStyle(fontSize: 12, color: Colors.grey[600], overflow: TextOverflow.ellipsis))),
                    SizedBox(width: 50, child: Text('${proc.cpuPercent.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: Colors.orange))),
                    SizedBox(width: 50, child: Text('${proc.memPercent.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: Colors.blue))),
                    Expanded(child: Text(proc.command, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
  }
}
