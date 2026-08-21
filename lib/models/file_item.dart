class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final bool isLink;
  final int size;
  final String permissions;
  final String owner;
  final String group;
  final DateTime modified;
  final int? linkCount;

  FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.isLink = false,
    this.size = 0,
    this.permissions = '',
    this.owner = '',
    this.group = '',
    required this.modified,
    this.linkCount,
  });

  String get sizeString {
    if (isDirectory) return '';
    if (size < 1024) return '$size B';
    if (size < 1048576) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1073741824) return '${(size / 1048576).toStringAsFixed(1)} MB';
    return '${(size / 1073741824).toStringAsFixed(2)} GB';
  }

  String get parentPath {
    final parts = path.split('/')..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '/';
    parts.removeLast();
    return '/${parts.join('/')}';
  }
}
