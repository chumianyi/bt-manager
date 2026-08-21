import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/ssh_provider.dart';
import '../../widgets/glass_widgets.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<String> _history = [];
  int _historyIndex = -1;
  SSHSession? _session;
  String _output = '';
  bool _isSessionReady = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSession());
  }

  Future<void> _initSession() async {
    final provider = Provider.of<SSHProvider>(context, listen: false);
    if (!provider.isConnected) return;
    try {
      _session = await provider.sshService.openShell();
      _session!.stdout.listen((data) {
        if (mounted) {
          setState(() => _output += utf8.decode(data, allowMalformed: true));
          _scrollToBottom();
        }
      });
      _session!.stderr.listen((data) {
        if (mounted) {
          setState(() => _output += utf8.decode(data, allowMalformed: true));
          _scrollToBottom();
        }
      });
      setState(() => _isSessionReady = true);
    } catch (e) {
      setState(() => _output = '终端初始化失败: $e\n');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendCommand(String cmd) {
    if (_session == null || !_isSessionReady) return;
    final data = Uint8List.fromList(utf8.encode('$cmd\n'));
    _session!.write(data);
    _history.add(cmd);
    _historyIndex = _history.length;
    _inputCtrl.clear();
  }

  void _sendSpecialKey(String key) {
    if (_session == null) return;
    String seq;
    switch (key) {
      case 'Ctrl+C':
        seq = '\x03';
        break;
      case 'Ctrl+D':
        seq = '\x04';
        break;
      case 'Ctrl+L':
        seq = '\x0c';
        break;
      case 'Tab':
        seq = '\t';
        break;
      case 'Esc':
        seq = '\x1b';
        break;
      case 'Up':
        seq = '\x1b[A';
        break;
      case 'Down':
        seq = '\x1b[B';
        break;
      case 'Left':
        seq = '\x1b[D';
        break;
      case 'Right':
        seq = '\x1b[C';
        break;
      default:
        seq = key;
    }
    _session!.write(Uint8List.fromList(utf8.encode(seq)));
  }

  void _historyNavigate(bool up) {
    if (_history.isEmpty) return;
    if (up) {
      if (_historyIndex > 0) {
        _historyIndex--;
        _inputCtrl.text = _history[_historyIndex];
      }
    } else {
      if (_historyIndex < _history.length - 1) {
        _historyIndex++;
        _inputCtrl.text = _history[_historyIndex];
      } else {
        _historyIndex = _history.length;
        _inputCtrl.clear();
      }
    }
  }

  @override
  void dispose() {
    _session?.close();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SSHProvider>(
      builder: (context, provider, _) {
        if (!provider.isConnected) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: const Text('终端')),
            body: const Center(child: Text('请先连接服务器')),
          );
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('终端 - ${provider.currentServer?.name ?? ''}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  _session?.close();
                  setState(() {
                    _output = '';
                    _isSessionReady = false;
                  });
                  _initSession();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: GlassContainer(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  borderRadius: 12,
                  opacity: 0.3,
                  child: Container(
                    color: Colors.black.withOpacity(0.7),
                    child: SingleChildScrollView(
                      controller: _scrollCtrl,
                      child: SelectableText(
                        _output.isEmpty ? '正在连接终端...\n' : _output,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Colors.greenAccent,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _buildSpecialKeys(),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: '输入命令...',
                          prefixIcon: const Icon(Icons.terminal, size: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send, size: 20),
                            onPressed: () {
                              if (_inputCtrl.text.isNotEmpty) _sendCommand(_inputCtrl.text);
                            },
                          ),
                        ),
                        onSubmitted: (v) {
                          if (v.isNotEmpty) _sendCommand(v);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpecialKeys() {
    final keys = ['Ctrl+C', 'Ctrl+D', 'Tab', 'Esc', 'Up', 'Down', 'Left', 'Right'];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: keys.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(keys[index], style: const TextStyle(fontSize: 11)),
              onPressed: () => _sendSpecialKey(keys[index]),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        },
      ),
    );
  }
}
