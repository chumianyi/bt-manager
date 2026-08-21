import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/file_item.dart';
import '../../providers/ssh_provider.dart';
import '../../widgets/glass_widgets.dart';
import 'file_viewer_screen.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  String _currentPath = '/root';
  List<FileItem> _files = [];
  bool _isLoading = false;
  final TextEditingController _renameCtrl = TextEditingController();
  final TextEditingController _newDirCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFiles());
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<SSHProvider>(context, listen: false);
      final files = await provider.fileService.listDirectory(_currentPath);
      setState(() => _files = files);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    }
    setState(() => _isLoading = false);
  }

  void _navigateTo(FileItem item) {
    if (item.isDirectory) {
      setState(() => _currentPath = item.path);
      _loadFiles();
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => FileViewerScreen(filePath: item.path, fileName: item.name)));
    }
  }

  void _navigateUp() {
    if (_currentPath == '/') return;
    final parts = _currentPath.split('/')..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) {
      _currentPath = '/';
    } else {
      parts.removeLast();
      _currentPath = '/${parts.join('/')}';
      if (_currentPath == '/') _currentPath = '/';
    }
    _loadFiles();
  }

  Future<void> _deleteFile(FileItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${item.name}」吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final provider = Provider.of<SSHProvider>(context, listen: false);
      if (item.isDirectory) {
        await provider.fileService.deleteDirectory(item.path);
      } else {
        await provider.fileService.deleteFile(item.path);
      }
      _loadFiles();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  Future<void> _renameFile(FileItem item) async {
    _renameCtrl.text = item.name;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(controller: _renameCtrl, decoration: const InputDecoration(labelText: '新名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, _renameCtrl.text), child: const Text('确定')),
        ],
      ),
    );
    if (result == null || result.isEmpty || result == item.name) return;
    try {
      final provider = Provider.of<SSHProvider>(context, listen: false);
      final newPath = '${item.parentPath}/$result';
      await provider.fileService.rename(item.path, newPath);
      _loadFiles();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('重命名失败: $e')));
    }
  }

  Future<void> _createDirectory() async {
    _newDirCtrl.clear();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(controller: _newDirCtrl, decoration: const InputDecoration(labelText: '文件夹名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, _newDirCtrl.text), child: const Text('创建')),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    try {
      final provider = Provider.of<SSHProvider>(context, listen: false);
      await provider.fileService.createDirectory('$_currentPath/$result');
      _loadFiles();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SSHProvider>(
      builder: (context, provider, _) {
        if (!provider.isConnected) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: const Text('文件管理')),
            body: const Center(child: Text('请先连接服务器')),
          );
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('文件管理'),
            actions: [
              IconButton(icon: const Icon(Icons.create_new_folder), onPressed: _createDirectory),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFiles),
            ],
          ),
          body: Column(
            children: [
              _buildPathBar(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _files.isEmpty
                        ? const Center(child: Text('空目录'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _files.length,
                            itemBuilder: (context, index) => _buildFileItem(_files[index]),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPathBar() {
    return GlassContainer(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: 12,
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_upward, size: 20), onPressed: _navigateUp, tooltip: '上级目录'),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(_currentPath, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(FileItem item) {
    final isDir = item.isDirectory;
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: 12,
      child: InkWell(
        onTap: () => _navigateTo(item),
        child: Row(
          children: [
            Icon(
              isDir ? Icons.folder : _getFileIcon(item.name),
              color: isDir ? Colors.orange : Colors.blue,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${item.permissions}  ${item.owner}  ${item.sizeString}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value == 'rename') _renameFile(item);
                if (value == 'delete') _deleteFile(item);
                if (value == 'view') _navigateTo(item);
              },
              itemBuilder: (context) => [
                if (!isDir) const PopupMenuItem(value: 'view', child: Text('查看')),
                const PopupMenuItem(value: 'rename', child: Text('重命名')),
                const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['png', 'jpg', 'jpeg', 'gif', 'svg', 'webp'].contains(ext)) return Icons.image;
    if (['mp4', 'mkv', 'avi', 'mov'].contains(ext)) return Icons.videocam;
    if (['mp3', 'wav', 'flac', 'ogg'].contains(ext)) return Icons.audiotrack;
    if (['zip', 'tar', 'gz', 'rar', '7z'].contains(ext)) return Icons.archive;
    if (['pdf', 'doc', 'docx', 'txt', 'md'].contains(ext)) return Icons.description;
    if (['sh', 'py', 'js', 'html', 'css', 'php', 'java', 'c', 'cpp'].contains(ext)) return Icons.code;
    if (['conf', 'cfg', 'ini', 'yaml', 'yml', 'json', 'xml'].contains(ext)) return Icons.settings;
    if (['log'].contains(ext)) return Icons.article;
    return Icons.insert_drive_file;
  }
}
