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

class SignupResponse {
  final String email;
  final String username;
  final bool requiresVerification;

  SignupResponse({
    required this.email,
    required this.username,
    required this.requiresVerification,
  });

  factory SignupResponse.fromJson(Map<String, dynamic> json) {
    return SignupResponse(
      email: json["email"] ?? "",
      username: json["username"] ?? "",
      requiresVerification: json["requiresVerification"] ?? true,
    );
  }
}

class AuthResponse {
  final String token;
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

class EmailNotVerifiedException implements Exception {
  final String message;
  EmailNotVerifiedException([this.message = "Email not verified."]);
  @override
  String toString() => message;
}
