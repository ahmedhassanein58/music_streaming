namespace Echonova.Api.DTOs;

public record UserMeResponse(Guid Id, string Username, string Email, List<string> Preference, bool ReceiveRecommendationEmails);

public record UpdateMeRequest(string? Username, List<string>? Preference, bool? ReceiveRecommendationEmails);
