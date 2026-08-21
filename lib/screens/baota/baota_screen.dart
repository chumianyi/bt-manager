import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/ssh_provider.dart';
import '../../widgets/glass_widgets.dart';

class BaotaScreen extends StatefulWidget {
  const BaotaScreen({super.key});

  @override
  State<BaotaScreen> createState() => _BaotaScreenState();
}

class _BaotaScreenState extends State<BaotaScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _error;
  final TextEditingController _urlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initWebView());
  }

  void _initWebView() {
    final provider = Provider.of<SSHProvider>(context, listen: false);
    final server = provider.currentServer;
    if (server == null) return;

    final scheme = server.useHttps ? 'https' : 'http';
    final url = '$scheme://${server.host}:${server.baotaPort}';
    _urlCtrl.text = url;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (error) {
            setState(() => _error = '${error.description} (${error.errorCode})');
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SSHProvider>(
      builder: (context, provider, _) {
        if (!provider.isConnected) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: const Text('宝塔面板')),
            body: const Center(child: Text('请先连接服务器')),
          );
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('宝塔面板'),
            actions: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => _controller?.goBack()),
              IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => _controller?.goForward()),
              IconButton(icon: const Icon(Icons.refresh), onPressed: () => _controller?.reload()),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlCtrl,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          prefixIcon: Icon(Icons.lock_outline, size: 16),
                        ),
                        onSubmitted: (url) {
                          if (url.isNotEmpty) _controller?.loadRequest(Uri.parse(url));
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.open_in_browser),
                      onPressed: () => _controller?.loadRequest(Uri.parse(_urlCtrl.text)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GlassContainer(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  borderRadius: 16,
                  opacity: 0.1,
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        if (_controller != null)
                          WebViewWidget(controller: _controller!)
                        else
                          const Center(child: CircularProgressIndicator()),
                        if (_isLoading)
                          const Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        if (_error != null && !_isLoading)
                          Positioned.fill(
                            child: Container(
                              color: Colors.white,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.warning_amber, size: 48, color: Colors.orange),
                                      const SizedBox(height: 16),
                                      const Text('无法加载宝塔面板', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                                      const SizedBox(height: 16),
                                      const Text('请确认：\n1. 宝塔面板已安装并运行\n2. 端口已开放\n3. 网络可访问', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
