import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import '../models/server_config.dart';

class SSHService {
  SSHClient? _client;
  SSHClient? _jumpClient;
  ServerConfig? _currentConfig;
  bool _isConnected = false;
  final StreamController<String> _terminalOutput = StreamController<String>.broadcast();
  Stream<String> get terminalOutput => _terminalOutput.stream;

  bool get isConnected => _isConnected;
  ServerConfig? get currentConfig => _currentConfig;

  Future<void> connect(ServerConfig config) async {
    try {
      if (config.useJumpServer && config.jumpHost != null) {
        await _connectWithJump(config);
      } else {
        await _connectDirect(config);
      }
      _currentConfig = config;
      _isConnected = true;
    } catch (e) {
      _isConnected = false;
      throw Exception('SSH连接失败: $e');
    }
  }

  Future<void> _connectDirect(ServerConfig config) async {
    final socket = await SSHSocket.connect(config.host, config.port, timeout: const Duration(seconds: 15));
    _client = SSHClient(
      socket,
      username: config.username,
      onPasswordRequest: () => config.password,
      onAuthenticated: () {},
    );
    await _client!.authenticated;
  }

  Future<void> _connectWithJump(ServerConfig config) async {
    final jumpSocket = await SSHSocket.connect(config.jumpHost!, config.jumpPort ?? 22, timeout: const Duration(seconds: 15));
    _jumpClient = SSHClient(
      jumpSocket,
      username: config.jumpUsername ?? config.username,
      onPasswordRequest: () => config.jumpPassword ?? config.password,
    );
    await _jumpClient!.authenticated;

    final forward = await _jumpClient!.forwardLocal(config.host, config.port);
    _client = SSHClient(
      forward,
      username: config.username,
      onPasswordRequest: () => config.password,
    );
    await _client!.authenticated;
  }

  Future<String> execute(String command, {bool useSudo = false}) async {
    if (_client == null || !_isConnected) {
      throw Exception('未连接到服务器');
    }
    try {
      final cmd = useSudo ? 'echo "${_currentConfig?.password ?? ''}" | sudo -S $command 2>&1' : command;
      final result = await _client!.run(cmd);
      return utf8.decode(result);
    } catch (e) {
      throw Exception('命令执行失败: $e');
    }
  }

  Future<SSHSession> openShell() async {
    if (_client == null || !_isConnected) {
      throw Exception('未连接到服务器');
    }
    final session = await _client!.shell(
      pty: const SSHPtyConfig(
        width: 80,
        height: 24,
        terminal: 'xterm-256color',
      ),
    );
    return session;
  }

  Future<SSHSftp> openSftp() async {
    if (_client == null || !_isConnected) {
      throw Exception('未连接到服务器');
    }
    return await _client!.sftp();
  }

  void writeToTerminal(String data) {
    _terminalOutput.add(data);
  }

  Future<void> disconnect() async {
    _client?.close();
    _jumpClient?.close();
    _client = null;
    _jumpClient = null;
    _isConnected = false;
    _currentConfig = null;
  }

  Future<bool> testConnection(ServerConfig config) async {
    try {
      await connect(config);
      await disconnect();
      return true;
    } catch (e) {
      return false;
    }
  }
}
