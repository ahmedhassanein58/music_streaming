enum EmailFrequency {
  off,
  daily,
  weekly,
  monthly;

  static EmailFrequency fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'daily':
        return EmailFrequency.daily;
      case 'weekly':
        return EmailFrequency.weekly;
      case 'monthly':
        return EmailFrequency.monthly;
      default:
        return EmailFrequency.off;
    }
  }

  String get apiValue {
    switch (this) {
      case EmailFrequency.daily:
        return 'Daily';
      case EmailFrequency.weekly:
        return 'Weekly';
      case EmailFrequency.monthly:
        return 'Monthly';
      case EmailFrequency.off:
        return 'Off';
    }
  }

  String get label {
    switch (this) {
      case EmailFrequency.daily:
        return 'Daily';
      case EmailFrequency.weekly:
        return 'Weekly';
      case EmailFrequency.monthly:
        return 'Monthly';
      case EmailFrequency.off:
        return 'Off';
    }
  }
}

class User {
  final String id;
  final String username;
  final String email;
  final List<String> preferences;
  final bool receiveRecommendationEmails;
  final EmailFrequency emailFrequency;
  final String? lastDetectedEmotion;
  final String? profileImageUrl;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.preferences,
    required this.receiveRecommendationEmails,
    required this.emailFrequency,
    this.lastDetectedEmotion,
    this.profileImageUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json["id"]?.toString() ?? "",
      username: json["username"] ?? "",
      email: json["email"] ?? "",
      preferences: (json["preference"] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      receiveRecommendationEmails: json["receiveRecommendationEmails"] ?? false,
      emailFrequency: EmailFrequency.fromString(json["emailFrequency"]?.toString()),
      lastDetectedEmotion: json["lastDetectedEmotion"]?.toString(),
      profileImageUrl: json["profileImageUrl"]?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "username": username,
      "email": email,
      "preference": preferences,
      "receiveRecommendationEmails": receiveRecommendationEmails,
      "emailFrequency": emailFrequency.apiValue,
      if (lastDetectedEmotion != null) "lastDetectedEmotion": lastDetectedEmotion,
      if (profileImageUrl != null) "profileImageUrl": profileImageUrl,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    List<String>? preferences,
    bool? receiveRecommendationEmails,
    EmailFrequency? emailFrequency,
    String? lastDetectedEmotion,
    String? profileImageUrl,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      preferences: preferences ?? this.preferences,
      receiveRecommendationEmails:
          receiveRecommendationEmails ?? this.receiveRecommendationEmails,
      emailFrequency: emailFrequency ?? this.emailFrequency,
      lastDetectedEmotion: lastDetectedEmotion ?? this.lastDetectedEmotion,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}

class UpdateMeRequest {
  final String? username;
  final List<String>? preference;
  final bool? receiveRecommendationEmails;
  final EmailFrequency? emailFrequency;

  UpdateMeRequest({
    this.username,
    this.preference,
    this.receiveRecommendationEmails,
    this.emailFrequency,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (username != null) data["username"] = username;
    if (preference != null) data["preference"] = preference;
    if (receiveRecommendationEmails != null) {
      data["receiveRecommendationEmails"] = receiveRecommendationEmails;
    }
    if (emailFrequency != null) {
      data["emailFrequency"] = emailFrequency!.apiValue;
    }
    return data;
  }
}
