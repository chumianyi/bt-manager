import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/firewall_rule.dart';
import '../../providers/ssh_provider.dart';
import '../../widgets/glass_widgets.dart';

class FirewallScreen extends StatefulWidget {
  const FirewallScreen({super.key});

  @override
  State<FirewallScreen> createState() => _FirewallScreenState();
}

class _FirewallScreenState extends State<FirewallScreen> {
  FirewallStatus? _status;
  bool _isLoading = false;
  final TextEditingController _portCtrl = TextEditingController();
  final TextEditingController _commentCtrl = TextEditingController();
  Protocol _selectedProtocol = Protocol.tcp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStatus());
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<SSHProvider>(context, listen: false);
      _status = await provider.firewallService.getStatus();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e')));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _openPort() async {
    final port = int.tryParse(_portCtrl.text.trim());
    if (port == null || port < 1 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效的端口号 (1-65535)')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<SSHProvider>(context, listen: false);
      await provider.firewallService.openPort(port, _selectedProtocol, comment: _commentCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('端口 $port 已开放'), backgroundColor: Colors.green));
        _portCtrl.clear();
        _commentCtrl.clear();
        _loadStatus();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('开放失败: $e'), backgroundColor: Colors.red));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _closePort(FirewallRule rule) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认关闭端口'),
        content: Text('确定要关闭端口 ${rule.port}/${rule.protocolString} 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('关闭', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<SSHProvider>(context, listen: false);
      await provider.firewallService.closePort(rule.port, rule.protocol);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('端口 ${rule.port} 已关闭'), backgroundColor: Colors.orange));
        _loadStatus();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('关闭失败: $e'), backgroundColor: Colors.red));
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _portCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SSHProvider>(
      builder: (context, provider, _) {
        if (!provider.isConnected) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: const Text('端口/防火墙')),
            body: const Center(child: Text('请先连接服务器')),
          );
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('端口/防火墙管理'),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStatus),
            ],
          ),
          body: _isLoading && _status == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildFirewallInfo(),
                    const SizedBox(height: 16),
                    _buildOpenPortForm(),
                    const SizedBox(height: 16),
                    _buildRulesList(),
                    const SizedBox(height: 24),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildFirewallInfo() {
    final status = _status;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: status?.isActive == true ? Colors.green : Colors.grey),
              const SizedBox(width: 8),
              const Text('防火墙状态', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (status?.isActive == true ? Colors.green : Colors.grey).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status?.isActive == true ? '运行中' : '未运行',
                  style: TextStyle(fontSize: 12, color: status?.isActive == true ? Colors.green : Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (status != null) ...[
            _infoRow('防火墙类型', status.typeName),
            _infoRow('版本', status.version),
            _infoRow('已开放端口', '${status.rules.length} 个'),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildOpenPortForm() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('开放新端口', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _portCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '端口号', hintText: '例如: 8080'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<Protocol>(
                  value: _selectedProtocol,
                  decoration: const InputDecoration(labelText: '协议'),
                  items: const [
                    DropdownMenuItem(value: Protocol.tcp, child: Text('TCP')),
                    DropdownMenuItem(value: Protocol.udp, child: Text('UDP')),
                    DropdownMenuItem(value: Protocol.both, child: Text('TCP/UDP')),
                  ],
                  onChanged: (v) => setState(() => _selectedProtocol = v ?? Protocol.tcp),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentCtrl,
            decoration: const InputDecoration(labelText: '备注名称 (可选)', hintText: '例如: Nginx Web'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _openPort,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('开放端口'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesList() {
    final rules = _status?.rules ?? [];
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt, size: 20),
              const SizedBox(width: 8),
              const Text('已开放端口列表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${rules.length} 项', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 12),
          if (rules.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('暂无开放端口', style: TextStyle(color: Colors.grey))),
            )
          else
            ...rules.map((rule) => _buildRuleItem(rule)),
        ],
      ),
    );
  }

  Widget _buildRuleItem(FirewallRule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Icon(Icons.router, color: Colors.blue, size: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${rule.port}/${rule.protocolString}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                if (rule.comment != null && rule.comment!.isNotEmpty)
                  Text(rule.comment!, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: const Text('已开放', style: TextStyle(fontSize: 10, color: Colors.green)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Colors.red),
            tooltip: '关闭端口',
            onPressed: () => _closePort(rule),
          ),
        ],
      ),
    );
  }
}
