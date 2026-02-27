using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Echonova.Api.Models;

public class User
{
    [BsonId]
    [BsonRepresentation(BsonType.String)]
    public Guid Id { get; set; }

    [BsonElement("username")]
    public string Username { get; set; } = string.Empty;
    [BsonElement("email")]
    public string Email { get; set; } = string.Empty;
    [BsonElement("password_hash")]
    public string PasswordHash { get; set; } = string.Empty;
    [BsonElement("preference")]
    public List<string> Preference { get; set; } = new();
    [BsonElement("email_otp")]
    public string? EmailOtp { get; set; }
    [BsonElement("otp_expire")]
    public DateTime? OtpExpire { get; set; }
    [BsonElement("receive_recommendation_emails")]
    public bool ReceiveRecommendationEmails { get; set; }
    [BsonElement("profile_image_url")]
    public string? ProfileImageUrl { get; set; }
}
