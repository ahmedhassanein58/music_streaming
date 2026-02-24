class LoginResponse {
  final String token;
  final bool isAdmin;

  LoginResponse({
    required this.token,
    required this.isAdmin,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json["token"],
      isAdmin: json["isAdmin"],
    );
  }
}