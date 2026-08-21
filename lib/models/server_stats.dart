class ServerStats {
  final double cpuUsage;
  final int cpuCores;
  final double memoryUsage;
  final int memoryTotal;
  final int memoryUsed;
  final double swapUsage;
  final int swapTotal;
  final int swapUsed;
  final List<DiskInfo> disks;
  final double load1;
  final double load5;
  final double load15;
  final int uptimeSeconds;
  final String osName;
  final String osVersion;
  final String kernel;
  final String hostname;
  final List<ProcessInfo> processes;
  final NetworkStats network;
  final DateTime timestamp;

  ServerStats({
    required this.cpuUsage,
    required this.cpuCores,
    required this.memoryUsage,
    required this.memoryTotal,
    required this.memoryUsed,
    required this.swapUsage,
    required this.swapTotal,
    required this.swapUsed,
    required this.disks,
    required this.load1,
    required this.load5,
    required this.load15,
    required this.uptimeSeconds,
    required this.osName,
    required this.osVersion,
    required this.kernel,
    required this.hostname,
    required this.processes,
    required this.network,
    required this.timestamp,
  });

  String get uptimeString {
    final days = uptimeSeconds ~/ 86400;
    final hours = (uptimeSeconds % 86400) ~/ 3600;
    final minutes = (uptimeSeconds % 3600) ~/ 60;
    if (days > 0) return '$days天${hours}小时';
    if (hours > 0) return '$hours小时${minutes}分钟';
    return '$minutes分钟';
  }
}

class DiskInfo {
  final String filesystem;
  final String mountPoint;
  final int total;
  final int used;
  final int available;
  final double usagePercent;

  DiskInfo({
    required this.filesystem,
    required this.mountPoint,
    required this.total,
    required this.used,
    required this.available,
    required this.usagePercent,
  });
}

class ProcessInfo {
  final int pid;
  final String user;
  final double cpuPercent;
  final double memPercent;
  final String command;
  final String status;

  ProcessInfo({
    required this.pid,
    required this.user,
    required this.cpuPercent,
    required this.memPercent,
    required this.command,
    required this.status,
  });
}

class NetworkStats {
  final int rxBytes;
  final int txBytes;
  final int rxPackets;
  final int txPackets;
  final String interface;

  NetworkStats({
    required this.rxBytes,
    required this.txBytes,
    required this.rxPackets,
    required this.txPackets,
    required this.interface,
  });
}
