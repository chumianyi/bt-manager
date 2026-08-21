import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/server_config.dart';
import '../../providers/ssh_provider.dart';
import '../../widgets/glass_widgets.dart';

class AddServerScreen extends StatefulWidget {
  final ServerConfig? editServer;
  const AddServerScreen({super.key, this.editServer});

  @override
  State<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends State<AddServerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _baotaPortCtrl;
  late TextEditingController _jumpHostCtrl;
  late TextEditingController _jumpPortCtrl;
  late TextEditingController _jumpUsernameCtrl;
  late TextEditingController _jumpPasswordCtrl;

  bool _useJumpServer = false;
  bool _useHttps = false;
  bool _isTesting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final s = widget.editServer;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _hostCtrl = TextEditingController(text: s?.host ?? '');
    _portCtrl = TextEditingController(text: (s?.port ?? 22).toString());
    _usernameCtrl = TextEditingController(text: s?.username ?? 'root');
    _passwordCtrl = TextEditingController(text: s?.password ?? '');
    _baotaPortCtrl = TextEditingController(text: (s?.baotaPort ?? 8888).toString());
    _jumpHostCtrl = TextEditingController(text: s?.jumpHost ?? '');
    _jumpPortCtrl = TextEditingController(text: (s?.jumpPort ?? 22).toString());
    _jumpUsernameCtrl = TextEditingController(text: s?.jumpUsername ?? '');
    _jumpPasswordCtrl = TextEditingController(text: s?.jumpPassword ?? '');
    _useJumpServer = s?.useJumpServer ?? false;
    _useHttps = s?.useHttps ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _baotaPortCtrl.dispose();
    _jumpHostCtrl.dispose();
    _jumpPortCtrl.dispose();
    _jumpUsernameCtrl.dispose();
    _jumpPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.editServer == null ? '添加服务器' : '编辑服务器'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('基本信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildTextField(_nameCtrl, '服务器名称', Icons.label_outline, '例如：生产服务器'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(flex: 3, child: _buildTextField(_hostCtrl, 'IP地址', Icons.public, '192.168.1.1')),
                      const SizedBox(width: 12),
                      Expanded(flex: 1, child: _buildTextField(_portCtrl, '端口', Icons.settings_ethernet, '22', isNumber: true)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(_usernameCtrl, '用户名', Icons.person_outline, 'root'),
                  const SizedBox(height: 12),
                  _buildPasswordField(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildJumpServerSection(),
            const SizedBox(height: 16),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('宝塔面板', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_baotaPortCtrl, '宝塔端口', Icons.web, '8888', isNumber: true)),
                      const SizedBox(width: 12),
                      Column(
                        children: [
                          const Text('HTTPS', style: TextStyle(fontSize: 12)),
                          Switch(value: _useHttps, onChanged: (v) => setState(() => _useHttps = v)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.network_check),
                    label: Text(_isTesting ? '测试中...' : '测试连接'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveServer,
                    icon: const Icon(Icons.save),
                    label: const Text('保存'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, String hint, {bool isNumber = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return '请输入$label';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordCtrl,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: '密码',
        prefixIcon: const Icon(Icons.lock_outline, size: 20),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return '请输入密码';
        return null;
      },
    );
  }

  Widget _buildJumpServerSection() {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('跳板服务器', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Switch(value: _useJumpServer, onChanged: (v) => setState(() => _useJumpServer = v)),
            ],
          ),
          if (_useJumpServer) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(flex: 3, child: _buildTextField(_jumpHostCtrl, '跳板机IP', Icons.router, '10.0.0.1')),
                const SizedBox(width: 12),
                Expanded(flex: 1, child: _buildTextField(_jumpPortCtrl, '端口', Icons.settings_ethernet, '22', isNumber: true)),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(_jumpUsernameCtrl, '跳板机用户名', Icons.person_outline, 'root'),
            const SizedBox(height: 12),
            _buildTextField(_jumpPasswordCtrl, '跳板机密码', Icons.lock_outline, ''),
          ],
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isTesting = true);
    final config = _buildConfig();
    final provider = Provider.of<SSHProvider>(context, listen: false);
    final result = await provider.sshService.testConnection(config);
    setState(() => _isTesting = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result ? '连接成功！' : '连接失败，请检查配置'),
        backgroundColor: result ? Colors.green : Colors.red,
      ),
    );
  }

  ServerConfig _buildConfig() {
    final id = widget.editServer?.id ?? Provider.of<SSHProvider>(context, listen: false).generateId();
    return ServerConfig(
      id: id,
      name: _nameCtrl.text.trim(),
      host: _hostCtrl.text.trim(),
      port: int.tryParse(_portCtrl.text) ?? 22,
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
      useJumpServer: _useJumpServer,
      jumpHost: _useJumpServer ? _jumpHostCtrl.text.trim() : null,
      jumpPort: _useJumpServer ? (int.tryParse(_jumpPortCtrl.text) ?? 22) : null,
      jumpUsername: _useJumpServer ? _jumpUsernameCtrl.text.trim() : null,
      jumpPassword: _useJumpServer ? _jumpPasswordCtrl.text : null,
      baotaPort: int.tryParse(_baotaPortCtrl.text) ?? 8888,
      useHttps: _useHttps,
      createdAt: widget.editServer?.createdAt,
      lastConnected: widget.editServer?.lastConnected,
    );
  }

  void _saveServer() {
    if (!_formKey.currentState!.validate()) return;
    final config = _buildConfig();
    final provider = Provider.of<SSHProvider>(context, listen: false);
    if (widget.editServer == null) {
      provider.addServer(config);
    } else {
      provider.updateServer(config);
    }
    Navigator.pop(context);
  }
}
