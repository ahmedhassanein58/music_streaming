class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      "email": email,
      "password": password,
    };
  }
}

class SignupRequest {
  final String username;
  final String email;
  final String password;

  SignupRequest({
    required this.username,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      "username": username,
      "email": email,
      "password": password,
    };
  }
}

class AuthResponse {
  final String token;
  // Note: isAdmin is not always present in all auth responses in OpenAPI but often returned
  final bool? isAdmin;

  AuthResponse({
    required this.token,
    this.isAdmin,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json["token"] ?? "",
      isAdmin: json["isAdmin"],
    );
  }
}
