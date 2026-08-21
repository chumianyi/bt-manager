class ServerConfig {
  final String id;
  String name;
  String host;
  int port;
  String username;
  String password;
  String? privateKey;
  bool useJumpServer;
  String? jumpHost;
  int? jumpPort;
  String? jumpUsername;
  String? jumpPassword;
  int baotaPort;
  bool useHttps;
  DateTime createdAt;
  DateTime? lastConnected;

  ServerConfig({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    required this.password,
    this.privateKey,
    this.useJumpServer = false,
    this.jumpHost,
    this.jumpPort = 22,
    this.jumpUsername,
    this.jumpPassword,
    this.baotaPort = 8888,
    this.useHttps = false,
    DateTime? createdAt,
    this.lastConnected,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'privateKey': privateKey,
        'useJumpServer': useJumpServer,
        'jumpHost': jumpHost,
        'jumpPort': jumpPort,
        'jumpUsername': jumpUsername,
        'jumpPassword': jumpPassword,
        'baotaPort': baotaPort,
        'useHttps': useHttps,
        'createdAt': createdAt.toIso8601String(),
        'lastConnected': lastConnected?.toIso8601String(),
      };

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
        id: json['id'],
        name: json['name'],
        host: json['host'],
        port: json['port'] ?? 22,
        username: json['username'],
        password: json['password'],
        privateKey: json['privateKey'],
        useJumpServer: json['useJumpServer'] ?? false,
        jumpHost: json['jumpHost'],
        jumpPort: json['jumpPort'] ?? 22,
        jumpUsername: json['jumpUsername'],
        jumpPassword: json['jumpPassword'],
        baotaPort: json['baotaPort'] ?? 8888,
        useHttps: json['useHttps'] ?? false,
        createdAt: DateTime.parse(json['createdAt']),
        lastConnected: json['lastConnected'] != null
            ? DateTime.parse(json['lastConnected'])
            : null,
      );

  ServerConfig copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    String? privateKey,
    bool? useJumpServer,
    String? jumpHost,
    int? jumpPort,
    String? jumpUsername,
    String? jumpPassword,
    int? baotaPort,
    bool? useHttps,
    DateTime? lastConnected,
  }) {
    return ServerConfig(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
      useJumpServer: useJumpServer ?? this.useJumpServer,
      jumpHost: jumpHost ?? this.jumpHost,
      jumpPort: jumpPort ?? this.jumpPort,
      jumpUsername: jumpUsername ?? this.jumpUsername,
      jumpPassword: jumpPassword ?? this.jumpPassword,
      baotaPort: baotaPort ?? this.baotaPort,
      useHttps: useHttps ?? this.useHttps,
      createdAt: createdAt,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }
}
