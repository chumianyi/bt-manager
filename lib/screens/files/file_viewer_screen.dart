import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ssh_provider.dart';
import '../../widgets/glass_widgets.dart';

class FileViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  const FileViewerScreen({super.key, required this.filePath, required this.fileName});

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  String _content = '';
  bool _isLoading = true;
  bool _isEditing = false;
  final TextEditingController _editCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<SSHProvider>(context, listen: false);
      _content = await provider.fileService.readFile(widget.filePath);
      _editCtrl.text = _content;
    } catch (e) {
      _content = '加载失败: $e';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveFile() async {
    try {
      final provider = Provider.of<SSHProvider>(context, listen: false);
      await provider.fileService.writeFile(widget.filePath, _editCtrl.text);
      setState(() {
        _content = _editCtrl.text;
        _isEditing = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存成功')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.fileName, overflow: TextOverflow.ellipsis),
        actions: [
          if (!_isEditing)
            IconButton(icon: const Icon(Icons.edit), onPressed: () => setState(() => _isEditing = true))
          else ...[
            IconButton(icon: const Icon(Icons.close), onPressed: () {
              _editCtrl.text = _content;
              setState(() => _isEditing = false);
            }),
            IconButton(icon: const Icon(Icons.save), onPressed: _saveFile),
          ],
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFile),
        ],
      ),
      body: GlassContainer(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        borderRadius: 12,
        opacity: 0.2,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _isEditing
                ? TextField(
                    controller: _editCtrl,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: const InputDecoration(border: InputBorder.none),
                  )
                : SingleChildScrollView(
                    child: SelectableText(
                      _content,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
                    ),
                  ),
      ),
    );
  }
}
