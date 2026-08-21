import 'package:flutter/material.dart';
import '../models/server_config.dart';
import '../models/server_stats.dart';
import '../services/ssh_service.dart';
import '../services/monitor_service.dart';
import '../services/file_service.dart';
import '../services/firewall_service.dart';
import '../utils/storage_service.dart';
import 'package:uuid/uuid.dart';

class SSHProvider extends ChangeNotifier {
  final SSHService sshService = SSHService();
  late final MonitorService monitorService = MonitorService(sshService);
  late final FileService fileService = FileService(sshService);
  late final FirewallService firewallService = FirewallService(sshService);

  List<ServerConfig> _servers = [];
  ServerConfig? _currentServer;
  ServerStats? _currentStats;
  bool _isConnecting = false;
  String? _connectionError;
  bool _isLoadingStats = false;

  List<ServerConfig> get servers => List.unmodifiable(_servers);
  ServerConfig? get currentServer => _currentServer;
  ServerStats? get currentStats => _currentStats;
  bool get isConnecting => _isConnecting;
  String? get connectionError => _connectionError;
  bool get isConnected => sshService.isConnected;
  bool get isLoadingStats => _isLoadingStats;

  final _uuid = const Uuid();

  Future<void> init() async {
    _servers = await StorageService.loadServers();
    notifyListeners();
  }

  Future<void> addServer(ServerConfig config) async {
    _servers.add(config);
    await StorageService.saveServers(_servers);
    notifyListeners();
  }

  Future<void> updateServer(ServerConfig config) async {
    final index = _servers.indexWhere((s) => s.id == config.id);
    if (index != -1) {
      _servers[index] = config;
      await StorageService.saveServers(_servers);
      notifyListeners();
    }
  }

  Future<void> deleteServer(String id) async {
    _servers.removeWhere((s) => s.id == id);
    if (_currentServer?.id == id) {
      await disconnect();
    }
    await StorageService.saveServers(_servers);
    notifyListeners();
  }

  String generateId() => _uuid.v4();

  Future<bool> connect(ServerConfig config) async {
    _isConnecting = true;
    _connectionError = null;
    notifyListeners();

    try {
      await sshService.connect(config);
      _currentServer = config.copyWith(lastConnected: DateTime.now());
      final idx = _servers.indexWhere((s) => s.id == config.id);
      if (idx != -1) {
        _servers[idx] = _currentServer!;
        await StorageService.saveServers(_servers);
      }
      _isConnecting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _connectionError = e.toString();
      _isConnecting = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    await sshService.disconnect();
    await fileService.close();
    firewallService.resetCache();
    _currentServer = null;
    _currentStats = null;
    notifyListeners();
  }

  Future<void> refreshStats() async {
    if (!isConnected) return;
    _isLoadingStats = true;
    notifyListeners();
    try {
      _currentStats = await monitorService.fetchStats();
    } catch (e) {
      // 静默处理错误
    }
    _isLoadingStats = false;
    notifyListeners();
  }

  Future<String> executeCommand(String command, {bool useSudo = false}) {
    return sshService.execute(command, useSudo: useSudo);
  }
}
