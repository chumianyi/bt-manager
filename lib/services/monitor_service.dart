import 'dart:convert';
import '../models/server_stats.dart';
import 'ssh_service.dart';

class MonitorService {
  final SSHService sshService;

  MonitorService(this.sshService);

  Future<ServerStats> fetchStats() async {
    try {
      final cpuResult = await sshService.execute(_cpuScript());
      final memResult = await sshService.execute("cat /proc/meminfo");
      const diskCmd = "df -hP --output=source,target,size,used,avail,pcent 2>/dev/null || df -h";
      final diskResult = await sshService.execute(diskCmd);
      final loadResult = await sshService.execute("cat /proc/loadavg && uptime -p 2>/dev/null || uptime");
      final osResult = await sshService.execute("cat /etc/os-release 2>/dev/null; uname -r; hostname");
      final procResult = await sshService.execute("ps aux --sort=-%cpu | head -15");
      final netResult = await sshService.execute("cat /proc/net/dev | tail -n +3");

      return ServerStats(
        cpuUsage: _parseCpu(cpuResult),
        cpuCores: _parseCpuCores(cpuResult),
        memoryUsage: _parseMemory(memResult)['usage']!,
        memoryTotal: _parseMemory(memResult)['total']!,
        memoryUsed: _parseMemory(memResult)['used']!,
        swapUsage: _parseSwap(memResult)['usage']!,
        swapTotal: _parseSwap(memResult)['total']!,
        swapUsed: _parseSwap(memResult)['used']!,
        disks: _parseDisks(diskResult),
        load1: _parseLoad(loadResult)[0],
        load5: _parseLoad(loadResult)[1],
        load15: _parseLoad(loadResult)[2],
        uptimeSeconds: _parseUptime(loadResult),
        osName: _parseOsName(osResult),
        osVersion: _parseOsVersion(osResult),
        kernel: _parseKernel(osResult),
        hostname: _parseHostname(osResult),
        processes: _parseProcesses(procResult),
        network: _parseNetwork(netResult),
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw Exception('获取服务器数据失败: $e');
    }
  }

  String _cpuScript() {
    return '''
CPU1=(`cat /proc/stat | grep '^cpu '`)
sleep 1
CPU2=(`cat /proc/stat | grep '^cpu '`)
IDLE1=\${CPU1[4]}
IDLE2=\${CPU2[4]}
TOTAL1=0
TOTAL2=0
for VALUE in "\${CPU1[@]:1}"; do TOTAL1=\$((TOTAL1+VALUE)); done
for VALUE in "\${CPU2[@]:1}"; do TOTAL2=\$((TOTAL2+VALUE)); done
DIFF_IDLE=\$((IDLE2-IDLE1))
DIFF_TOTAL=\$((TOTAL2-TOTAL1))
if [ \$DIFF_TOTAL -gt 0 ]; then
  CPU_USAGE=\$(echo "scale=2; (1000*(\$DIFF_TOTAL-\$DIFF_IDLE)/\$DIFF_TOTAL+5)/10" | bc)
else
  CPU_USAGE=0
fi
CORES=\$(nproc)
echo "CPU_USAGE=\$CPU_USAGE"
echo "CPU_CORES=\$CORES"
''';
  }

  double _parseCpu(String output) {
    final match = RegExp(r'CPU_USAGE=([\d.]+)').firstMatch(output);
    return double.tryParse(match?.group(1) ?? '0') ?? 0;
  }

  int _parseCpuCores(String output) {
    final match = RegExp(r'CPU_CORES=(\d+)').firstMatch(output);
    return int.tryParse(match?.group(1) ?? '1') ?? 1;
  }

  Map<String, num> _parseMemory(String output) {
    final lines = output.split('\n');
    int total = 0, available = 0, buffers = 0, cached = 0;
    for (final line in lines) {
      if (line.startsWith('MemTotal:')) {
        total = int.tryParse(RegExp(r'\d+').firstMatch(line)?.group(0) ?? '0') ?? 0;
      } else if (line.startsWith('MemAvailable:')) {
        available = int.tryParse(RegExp(r'\d+').firstMatch(line)?.group(0) ?? '0') ?? 0;
      } else if (line.startsWith('Buffers:')) {
        buffers = int.tryParse(RegExp(r'\d+').firstMatch(line)?.group(0) ?? '0') ?? 0;
      } else if (line.startsWith('Cached:')) {
        cached = int.tryParse(RegExp(r'\d+').firstMatch(line)?.group(0) ?? '0') ?? 0;
      }
    }
    final used = total - available;
    final usage = total > 0 ? (used / total * 100) : 0.0;
    return {
      'total': total * 1024,
      'used': used * 1024,
      'usage': usage,
    };
  }

  Map<String, num> _parseSwap(String output) {
    final lines = output.split('\n');
    int total = 0, free = 0;
    for (final line in lines) {
      if (line.startsWith('SwapTotal:')) {
        total = int.tryParse(RegExp(r'\d+').firstMatch(line)?.group(0) ?? '0') ?? 0;
      } else if (line.startsWith('SwapFree:')) {
        free = int.tryParse(RegExp(r'\d+').firstMatch(line)?.group(0) ?? '0') ?? 0;
      }
    }
    final used = total - free;
    final usage = total > 0 ? (used / total * 100) : 0.0;
    return {
      'total': total * 1024,
      'used': used * 1024,
      'usage': usage,
    };
  }

  List<DiskInfo> _parseDisks(String output) {
    final lines = output.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final List<DiskInfo> disks = [];
    for (int i = 1; i < lines.length; i++) {
      final parts = lines[i].split(RegExp(r'\s+'));
      if (parts.length >= 6) {
        final total = _parseSize(parts[2]);
        final used = _parseSize(parts[3]);
        final avail = _parseSize(parts[4]);
        final usage = double.tryParse(parts[5].replaceAll('%', '')) ?? 0;
        disks.add(DiskInfo(
          filesystem: parts[0],
          mountPoint: parts[1],
          total: total,
          used: used,
          available: avail,
          usagePercent: usage,
        ));
      }
    }
    return disks;
  }

  int _parseSize(String size) {
    size = size.trim();
    if (size.endsWith('G')) return (double.parse(size.replaceAll('G', '')) * 1073741824).round();
    if (size.endsWith('M')) return (double.parse(size.replaceAll('M', '')) * 1048576).round();
    if (size.endsWith('K')) return (double.parse(size.replaceAll('K', '')) * 1024).round();
    return int.tryParse(size) ?? 0;
  }

  List<double> _parseLoad(String output) {
    final match = RegExp(r'([\d.]+)\s+([\d.]+)\s+([\d.]+)').firstMatch(output);
    return [
      double.tryParse(match?.group(1) ?? '0') ?? 0,
      double.tryParse(match?.group(2) ?? '0') ?? 0,
      double.tryParse(match?.group(3) ?? '0') ?? 0,
    ];
  }

  int _parseUptime(String output) {
    try {
      final result = output.contains('up ') ? output : '';
      final match = RegExp(r'up\s+(\d+)\s+(\w+)').firstMatch(result);
      if (match != null) {
        final value = int.parse(match.group(1)!);
        final unit = match.group(2)!;
        if (unit.startsWith('day')) return value * 86400;
        if (unit.startsWith('hour') || unit.startsWith('hr')) return value * 3600;
        if (unit.startsWith('min')) return value * 60;
      }
    } catch (_) {}
    return 0;
  }

  String _parseOsName(String output) {
    final match = RegExp(r'PRETTY_NAME="([^"]+)"').firstMatch(output);
    return match?.group(1) ?? 'Linux';
  }

  String _parseOsVersion(String output) {
    final match = RegExp(r'VERSION="([^"]+)"').firstMatch(output);
    return match?.group(1) ?? '';
  }

  String _parseKernel(String output) {
    final lines = output.split('\n');
    for (final line in lines) {
      if (RegExp(r'^\d+\.\d+').hasMatch(line.trim())) {
        return line.trim();
      }
    }
    return '';
  }

  String _parseHostname(String output) {
    final lines = output.split('\n');
    return lines.isNotEmpty ? lines.last.trim() : '';
  }

  List<ProcessInfo> _parseProcesses(String output) {
    final lines = output.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final List<ProcessInfo> processes = [];
    for (int i = 1; i < lines.length; i++) {
      final parts = lines[i].split(RegExp(r'\s+'));
      if (parts.length >= 11) {
        processes.add(ProcessInfo(
          pid: int.tryParse(parts[1]) ?? 0,
          user: parts[0],
          cpuPercent: double.tryParse(parts[2]) ?? 0,
          memPercent: double.tryParse(parts[3]) ?? 0,
          command: parts.sublist(10).join(' '),
          status: parts[7],
        ));
      }
    }
    return processes;
  }

  NetworkStats _parseNetwork(String output) {
    final lines = output.split('\n').where((l) => l.contains(':')).toList();
    int rx = 0, tx = 0, rxp = 0, txp = 0;
    String iface = 'eth0';
    for (final line in lines) {
      final parts = line.trim().split(RegExp(r'[:\s]+'));
      if (parts.length >= 10 && !parts[0].startsWith('lo')) {
        iface = parts[0];
        rx += int.tryParse(parts[1]) ?? 0;
        rxp += int.tryParse(parts[2]) ?? 0;
        tx += int.tryParse(parts[9]) ?? 0;
        txp += int.tryParse(parts[10]) ?? 0;
        break;
      }
    }
    return NetworkStats(
      rxBytes: rx,
      txBytes: tx,
      rxPackets: rxp,
      txPackets: txp,
      interface: iface,
    );
  }
}
