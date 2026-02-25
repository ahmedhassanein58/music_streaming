using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Echonova.Api.Models;

public class Admin
{
    [BsonId]
    [BsonRepresentation(BsonType.String)]
    public Guid Id { get; set; }

    [BsonElement("email")]
    public string Email { get; set; } = string.Empty;
    [BsonElement("password_hash")]
    public string PasswordHash { get; set; } = string.Empty;
}
