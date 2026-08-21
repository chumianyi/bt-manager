import '../models/firewall_rule.dart';
import 'ssh_service.dart';

class FirewallService {
  final SSHService sshService;
  FirewallType? _detectedType;

  FirewallService(this.sshService);

  Future<FirewallType> detectFirewall() async {
    if (_detectedType != null) return _detectedType!;

    try {
      final result = await sshService.execute(
        'which firewall-cmd 2>/dev/null && echo "FIREWALLD" || '
        'which ufw 2>/dev/null && echo "UFW" || '
        'which iptables 2>/dev/null && echo "IPTABLES" || echo "UNKNOWN"',
      );
      if (result.contains('FIREWALLD')) {
        _detectedType = FirewallType.firewalld;
      } else if (result.contains('UFW')) {
        _detectedType = FirewallType.ufw;
      } else if (result.contains('IPTABLES')) {
        _detectedType = FirewallType.iptables;
      } else {
        _detectedType = FirewallType.unknown;
      }
    } catch (_) {
      _detectedType = FirewallType.unknown;
    }
    return _detectedType!;
  }

  Future<FirewallStatus> getStatus() async {
    final type = await detectFirewall();
    bool isActive = false;
    String version = '';
    List<FirewallRule> rules = [];

    try {
      switch (type) {
        case FirewallType.firewalld:
          final statusResult = await sshService.execute('firewall-cmd --state 2>/dev/null', useSudo: true);
          isActive = statusResult.trim() == 'running';
          final versionResult = await sshService.execute('firewall-cmd --version 2>/dev/null', useSudo: true);
          version = versionResult.trim();
          rules = await _getFirewalldRules();
          break;
        case FirewallType.ufw:
          final statusResult = await sshService.execute('ufw status verbose 2>/dev/null', useSudo: true);
          isActive = statusResult.contains('Status: active');
          version = 'UFW';
          rules = _parseUfwRules(statusResult);
          break;
        case FirewallType.iptables:
          isActive = true;
          version = 'iptables';
          rules = await _getIptablesRules();
          break;
        case FirewallType.unknown:
          isActive = false;
          version = '未知';
          break;
      }
    } catch (e) {
      // 忽略错误，返回已获取的信息
    }

    return FirewallStatus(
      type: type,
      isActive: isActive,
      version: version,
      rules: rules,
    );
  }

  Future<List<FirewallRule>> _getFirewalldRules() async {
    final result = await sshService.execute('firewall-cmd --list-ports 2>/dev/null', useSudo: true);
    final List<FirewallRule> rules = [];
    final ports = result.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    for (final port in ports) {
      final parts = port.split('/');
      if (parts.length == 2) {
        final portNum = int.tryParse(parts[0]);
        if (portNum != null) {
          rules.add(FirewallRule(
            port: portNum,
            protocol: parts[1] == 'udp' ? Protocol.udp : Protocol.tcp,
            isOpen: true,
            rawOutput: port,
          ));
        }
      }
    }
    return rules;
  }

  List<FirewallRule> _parseUfwRules(String output) {
    final List<FirewallRule> rules = [];
    final lines = output.split('\n');
    bool inRules = false;
    for (final line in lines) {
      if (line.contains('--')) {
        inRules = true;
        continue;
      }
      if (!inRules || line.trim().isEmpty) continue;
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        final action = parts[0];
        final portMatch = RegExp(r'(\d+)(?:/(tcp|udp))?').firstMatch(parts[1]);
        if (portMatch != null) {
          final portNum = int.tryParse(portMatch.group(1) ?? '');
          if (portNum != null) {
            final proto = portMatch.group(2);
            rules.add(FirewallRule(
              port: portNum,
              protocol: proto == 'udp' ? Protocol.udp : Protocol.tcp,
              isOpen: action == 'ALLOW',
              rawOutput: line,
            ));
          }
        }
      }
    }
    return rules;
  }

  Future<List<FirewallRule>> _getIptablesRules() async {
    final result = await sshService.execute('iptables -L INPUT -n --line-numbers 2>/dev/null', useSudo: true);
    final List<FirewallRule> rules = [];
    final lines = result.split('\n');
    for (final line in lines) {
      if (line.contains('ACCEPT') && (line.contains('dpt:') || line.contains('dpt:'))) {
        final portMatch = RegExp(r'dpt:(\d+)').firstMatch(line);
        final protoMatch = RegExp(r'^(tcp|udp)', caseSensitive: false).firstMatch(line.trim());
        if (portMatch != null) {
          final portNum = int.tryParse(portMatch.group(1) ?? '');
          if (portNum != null) {
            rules.add(FirewallRule(
              port: portNum,
              protocol: (protoMatch?.group(1)?.toLowerCase() == 'udp') ? Protocol.udp : Protocol.tcp,
              isOpen: true,
              rawOutput: line,
            ));
          }
        }
      }
    }
    return rules;
  }

  Future<String> openPort(int port, Protocol protocol, {String? comment}) async {
    final type = await detectFirewall();
    String command = '';
    String protoStr = protocol == Protocol.udp ? 'udp' : 'tcp';

    switch (type) {
      case FirewallType.firewalld:
        if (protocol == Protocol.both) {
          command = 'firewall-cmd --permanent --add-port=$port/tcp && firewall-cmd --permanent --add-port=$port/udp && firewall-cmd --reload';
        } else {
          command = 'firewall-cmd --permanent --add-port=$port/$protoStr && firewall-cmd --reload';
        }
        break;
      case FirewallType.ufw:
        if (protocol == Protocol.both) {
          command = 'ufw allow $port/tcp && ufw allow $port/udp';
        } else {
          command = 'ufw allow $port/$protoStr';
        }
        break;
      case FirewallType.iptables:
        if (protocol == Protocol.both) {
          command = 'iptables -A INPUT -p tcp --dport $port -j ACCEPT && iptables -A INPUT -p udp --dport $port -j ACCEPT';
        } else {
          command = 'iptables -A INPUT -p $protoStr --dport $port -j ACCEPT';
        }
        command += ' && iptables-save > /etc/iptables/rules.v4 2>/dev/null || service iptables save 2>/dev/null || true';
        break;
      case FirewallType.unknown:
        throw Exception('未检测到防火墙类型');
    }

    final result = await sshService.execute(command, useSudo: true);
    _detectedType = null; // 重置缓存以便重新获取
    return result;
  }

  Future<String> closePort(int port, Protocol protocol) async {
    final type = await detectFirewall();
    String command = '';
    String protoStr = protocol == Protocol.udp ? 'udp' : 'tcp';

    switch (type) {
      case FirewallType.firewalld:
        command = 'firewall-cmd --permanent --remove-port=$port/$protoStr && firewall-cmd --reload';
        break;
      case FirewallType.ufw:
        command = 'ufw delete allow $port/$protoStr';
        break;
      case FirewallType.iptables:
        command = 'iptables -D INPUT -p $protoStr --dport $port -j ACCEPT';
        command += ' && iptables-save > /etc/iptables/rules.v4 2>/dev/null || service iptables save 2>/dev/null || true';
        break;
      case FirewallType.unknown:
        throw Exception('未检测到防火墙类型');
    }

    final result = await sshService.execute(command, useSudo: true);
    _detectedType = null;
    return result;
  }

  void resetCache() {
    _detectedType = null;
  }
}
