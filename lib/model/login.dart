class Login{
  int id;
  String name;
  String role;
  String token;
  int? sessionId;

  Login({
    required this.id,
    required this.name,
    required this.role,
    required this.token,
    this.sessionId,
  });

  factory Login.fromJson(Map<String, dynamic> json) {
    return Login(
      id: json['data']['id'],
      name: json['data']['name'],
      role: json['data']['role'],
      token: json['token'],
      sessionId: json['data']['sessionId'],
    );
  }
}