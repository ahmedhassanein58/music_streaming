using Echonova.Api.Models;

namespace Echonova.Api.DTOs;

public record UserMeResponse(
    Guid Id,
    string Username,
    string Email,
    List<string> Preference,
    bool ReceiveRecommendationEmails,
    EmailFrequency EmailFrequency,
    string? LastDetectedEmotion,
    string? ProfileImageUrl);

public record UpdateMeRequest(
    string? Username,
    List<string>? Preference,
    bool? ReceiveRecommendationEmails,
    EmailFrequency? EmailFrequency);
