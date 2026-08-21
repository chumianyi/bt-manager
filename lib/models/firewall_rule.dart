enum FirewallType { firewalld, ufw, iptables, unknown }

enum Protocol { tcp, udp, both }

class FirewallRule {
  final int port;
  final Protocol protocol;
  final bool isOpen;
  final String? comment;
  final String? source;
  final String rawOutput;

  FirewallRule({
    required this.port,
    required this.protocol,
    required this.isOpen,
    this.comment,
    this.source,
    required this.rawOutput,
  });

  String get protocolString {
    switch (protocol) {
      case Protocol.tcp:
        return 'TCP';
      case Protocol.udp:
        return 'UDP';
      case Protocol.both:
        return 'TCP/UDP';
    }
  }
}

class FirewallStatus {
  final FirewallType type;
  final bool isActive;
  final String version;
  final List<FirewallRule> rules;

  FirewallStatus({
    required this.type,
    required this.isActive,
    required this.version,
    required this.rules,
  });

  String get typeName {
    switch (type) {
      case FirewallType.firewalld:
        return 'firewalld';
      case FirewallType.ufw:
        return 'UFW';
      case FirewallType.iptables:
        return 'iptables';
      case FirewallType.unknown:
        return '未知';
    }
  }
}
