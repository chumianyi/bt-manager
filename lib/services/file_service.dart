import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import '../models/file_item.dart';
import 'ssh_service.dart';

class FileService {
  final SSHService sshService;
  SftpClient? _sftp;

  FileService(this.sshService);

  Future<void> _ensureSftp() async {
    _sftp ??= await sshService.openSftp();
  }

  Future<List<FileItem>> listDirectory(String path) async {
    await _ensureSftp();
    try {
      final items = await _sftp!.listdir(path);
      final List<FileItem> result = [];
      for (final item in items) {
        if (item.filename == '.' || item.filename == '..') continue;
        final stat = await _sftp!.stat('$path/${item.filename}');
        result.add(FileItem(
          name: item.filename,
          path: '$path/${item.filename}',
          isDirectory: stat.isDirectory,
          isLink: stat.isLink,
          size: stat.size ?? 0,
          permissions: _formatPermissions(stat.mode ?? 0),
          owner: '',
          group: '',
          modified: DateTime.fromMillisecondsSinceEpoch((stat.modifyTime ?? 0) * 1000),
        ));
      }
      result.sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return result;
    } catch (e) {
      final lsResult = await sshService.execute('ls -la --time-style=full-iso "$path" 2>/dev/null || ls -la "$path"');
      return _parseLsOutput(lsResult, path);
    }
  }

  List<FileItem> _parseLsOutput(String output, String basePath) {
    final lines = output.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final List<FileItem> result = [];
    for (final line in lines) {
      if (line.startsWith('total')) continue;
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 9) continue;
      final name = parts.sublist(8).join(' ');
      if (name == '.' || name == '..') continue;
      final isDir = parts[0].startsWith('d');
      final isLink = parts[0].startsWith('l');
      result.add(FileItem(
        name: name,
        path: '$basePath/$name',
        isDirectory: isDir,
        isLink: isLink,
        size: int.tryParse(parts[4]) ?? 0,
        permissions: parts[0],
        owner: parts[2],
        group: parts[3],
        modified: DateTime.tryParse('${parts[5]} ${parts[6]} ${parts[7]}') ?? DateTime.now(),
      ));
    }
    return result;
  }

  String _formatPermissions(int mode) {
    String perms = '';
    perms += (mode & 0x4000) != 0 ? 'd' : '-';
    perms += (mode & 0x0100) != 0 ? 'r' : '-';
    perms += (mode & 0x0080) != 0 ? 'w' : '-';
    perms += (mode & 0x0040) != 0 ? 'x' : '-';
    perms += (mode & 0x0020) != 0 ? 'r' : '-';
    perms += (mode & 0x0010) != 0 ? 'w' : '-';
    perms += (mode & 0x0008) != 0 ? 'x' : '-';
    perms += (mode & 0x0004) != 0 ? 'r' : '-';
    perms += (mode & 0x0002) != 0 ? 'w' : '-';
    perms += (mode & 0x0001) != 0 ? 'x' : '-';
    return perms;
  }

  Future<String> readFile(String path) async {
    try {
      await _ensureSftp();
      final file = await _sftp!.open(path);
      final content = await file.readBytes();
      await file.close();
      return utf8.decode(content, allowMalformed: true);
    } catch (e) {
      return await sshService.execute('cat "$path"');
    }
  }

  Future<void> writeFile(String path, String content) async {
    try {
      await _ensureSftp();
      final file = await _sftp!.open(path, mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate);
      await file.writeBytes(utf8.encode(content));
      await file.close();
    } catch (e) {
      await sshService.execute('cat > "$path" << \'EOF\'\n$content\nEOF');
    }
  }

  Future<void> deleteFile(String path) async {
    try {
      await _ensureSftp();
      await _sftp!.remove(path);
    } catch (e) {
      await sshService.execute('rm -f "$path"', useSudo: true);
    }
  }

  Future<void> deleteDirectory(String path) async {
    await sshService.execute('rm -rf "$path"', useSudo: true);
  }

  Future<void> rename(String oldPath, String newPath) async {
    try {
      await _ensureSftp();
      await _sftp!.rename(oldPath, newPath);
    } catch (e) {
      await sshService.execute('mv "$oldPath" "$newPath"', useSudo: true);
    }
  }

  Future<void> createDirectory(String path) async {
    try {
      await _ensureSftp();
      await _sftp!.mkdir(path, mode: 0x1ED);
    } catch (e) {
      await sshService.execute('mkdir -p "$path"', useSudo: true);
    }
  }

  Future<Uint8List> downloadFile(String path) async {
    await _ensureSftp();
    final file = await _sftp!.open(path);
    final content = await file.readBytes();
    await file.close();
    return content;
  }

  Future<void> uploadFile(String remotePath, Uint8List data) async {
    await _ensureSftp();
    final file = await _sftp!.open(remotePath, mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate);
    await file.writeBytes(data);
    await file.close();
  }

  Future<void> close() async {
    _sftp = null;
  }
}
