class User {
  final String username;
  final String email;
  final List<String> preferences;
  final bool receiveRecommendationEmails;

  User({
    required this.username,
    required this.email,
    required this.preferences,
    required this.receiveRecommendationEmails,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json["username"] ?? "",
      email: json["email"] ?? "",
      preferences: (json["preference"] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      receiveRecommendationEmails: json["receiveRecommendationEmails"] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "username": username,
      "email": email,
      "preference": preferences,
      "receiveRecommendationEmails": receiveRecommendationEmails,
    };
  }

  User copyWith({
    String? username,
    String? email,
    List<String>? preferences,
    bool? receiveRecommendationEmails,
  }) {
    return User(
      username: username ?? this.username,
      email: email ?? this.email,
      preferences: preferences ?? this.preferences,
      receiveRecommendationEmails:
          receiveRecommendationEmails ?? this.receiveRecommendationEmails,
    );
  }
}

class UpdateMeRequest {
  final String? username;
  final List<String>? preference;
  final bool? receiveRecommendationEmails;

  UpdateMeRequest({
    this.username,
    this.preference,
    this.receiveRecommendationEmails,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (username != null) data["username"] = username;
    if (preference != null) data["preference"] = preference;
    if (receiveRecommendationEmails != null) {
      data["receiveRecommendationEmails"] = receiveRecommendationEmails;
    }
    return data;
  }
}
