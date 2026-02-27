namespace Echonova.Api.DTOs;

public record UserMeResponse(Guid Id, string Username, string Email, List<string> Preference, bool ReceiveRecommendationEmails, string? ProfileImageUrl);

public record UpdateMeRequest(string? Username, List<string>? Preference, bool? ReceiveRecommendationEmails);
